package dev.wads.phone2mac.signalsync

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.telephony.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class SignalMonitorService : Service() {
    private var server: LocalSignalServer? = null
    private var manager: TelephonyManager? = null
    private var callback: TelephonyCallback? = null
    private var displayOverride = 0
    private var legacyListener: PhoneStateListener? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (SignalState.running) return START_NOT_STICKY
        val notifications = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(NotificationChannel(
                CHANNEL, "Monitoramento de sinal", NotificationManager.IMPORTANCE_LOW
            ))
        }
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification())
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            SignalState.message = "Permissão de telefone necessária"
            stopSelf()
            return START_NOT_STICKY
        }
        SignalState.clear()
        SignalState.running = true
        SignalState.message = "Aguardando leitura do Android"
        try {
            server = LocalSignalServer(this).also { it.start() }
            val base = getSystemService(TelephonyManager::class.java)
            val subscription = SubscriptionManager.getDefaultDataSubscriptionId()
            manager = if (subscription >= 0) {
                base.createForSubscriptionId(subscription)
            } else base
            if (Build.VERSION.SDK_INT >= 31) {
                val listener = object : TelephonyCallback(), TelephonyCallback.SignalStrengthsListener, TelephonyCallback.DisplayInfoListener {
                    override fun onSignalStrengthsChanged(signalStrength: SignalStrength) = update(signalStrength)
                    override fun onDisplayInfoChanged(info: TelephonyDisplayInfo) {
                        displayOverride = info.overrideNetworkType
                        updateNetwork()
                    }
                }
                callback = listener
                manager!!.registerTelephonyCallback(mainExecutor, listener)
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    override fun onSignalStrengthsChanged(signalStrength: SignalStrength) = update(signalStrength)
                }
                legacyListener = listener
                @Suppress("DEPRECATION")
                manager!!.listen(listener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
            }
        } catch (error: java.io.IOException) {
            SignalState.message = "Não foi possível abrir o servidor local"
            stopSelf()
        } catch (error: SecurityException) {
            SignalState.message = "Acesso ao sinal negado pelo sistema"
            stopSelf()
        } catch (error: UnsupportedOperationException) {
            SignalState.message = "Telefonia não disponível neste aparelho"
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun update(signal: SignalStrength) {
        if (!SignalState.running) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            SignalState.message = "Permissão de telefone removida"
            stopSelf()
            return
        }
        SignalState.level = signal.level.takeIf { it in 0..4 }
        // Keep dBm unknown when multiple radio readings exist rather than guessing the serving radio.
        SignalState.dbm = if (Build.VERSION.SDK_INT >= 29) {
            signal.cellSignalStrengths.singleOrNull()?.dbm?.takeIf { it != CellInfo.UNAVAILABLE }
        } else null
        SignalState.operator = manager?.networkOperatorName?.takeIf { it.isNotBlank() } ?: "—"
        updateNetwork()
        SignalState.updatedAt = SystemClock.elapsedRealtime()
        SignalState.message = "Monitoramento ativo"
        getSystemService(NotificationManager::class.java).notify(1, notification())
    }

    private fun updateNetwork() {
        SignalState.network = try {
            if (Build.VERSION.SDK_INT >= 31 && displayOverride == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_ADVANCED) "5G+"
            else if (Build.VERSION.SDK_INT >= 30 && displayOverride == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_NSA) "5G"
            else if (Build.VERSION.SDK_INT >= 30 && (displayOverride == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_LTE_CA || displayOverride == TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_LTE_ADVANCED_PRO)) "4G+"
            else
            when (manager?.dataNetworkType) {
                TelephonyManager.NETWORK_TYPE_NR -> "5G"
                TelephonyManager.NETWORK_TYPE_LTE -> "4G / LTE"
                TelephonyManager.NETWORK_TYPE_HSPAP, TelephonyManager.NETWORK_TYPE_HSPA,
                TelephonyManager.NETWORK_TYPE_HSDPA, TelephonyManager.NETWORK_TYPE_HSUPA,
                TelephonyManager.NETWORK_TYPE_UMTS -> "3G"
                TelephonyManager.NETWORK_TYPE_EDGE, TelephonyManager.NETWORK_TYPE_GPRS,
                TelephonyManager.NETWORK_TYPE_GSM -> "2G"
                else -> "Indisponível"
            }
        } catch (_: SecurityException) { "Indisponível" }
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, javaClass).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_signal_notification)
            .setContentTitle("Android 2 Mac Sinal Sync")
            .setContentText(SignalState.level?.let { "Sinal: $it/4 • ${SignalState.network}" } ?: "Aguardando sinal celular")
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(0, "Parar", stop)
            .build()
    }

    override fun onDestroy() {
        server?.stop()
        try {
            if (Build.VERSION.SDK_INT >= 31) callback?.let { manager?.unregisterTelephonyCallback(it) }
            @Suppress("DEPRECATION")
            legacyListener?.let { manager?.listen(it, PhoneStateListener.LISTEN_NONE) }
        } catch (_: SecurityException) { /* Permission may have been revoked. */ }
        SignalState.running = false
        SignalState.clear()
        if (SignalState.message == "Monitoramento ativo" || SignalState.message == "Aguardando leitura do Android") {
            SignalState.message = "Monitoramento parado"
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "dev.wads.phone2mac.signalsync.STOP"
        private const val CHANNEL = "signal_monitor"
    }
}
