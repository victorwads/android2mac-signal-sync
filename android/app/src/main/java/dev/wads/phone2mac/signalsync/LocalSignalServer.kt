package dev.wads.phone2mac.signalsync

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import org.json.JSONObject
import java.net.ServerSocket
import java.net.Inet4Address
import java.net.NetworkInterface
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors

/** Small bounded HTTP endpoint. Only use on trusted LANs: authentication is not encryption. */
class LocalSignalServer(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var socket: ServerSocket? = null
    val port: Int get() = socket?.localPort ?: 0
    private var registration: NsdManager.RegistrationListener? = null
    @Volatile private var active = false
    @Volatile private var snapshot = "{}"
    private val prefs = context.getSharedPreferences("connection", Context.MODE_PRIVATE)
    val id: String = prefs.getString("id", null) ?: UUID.randomUUID().toString().also { prefs.edit().putString("id", it).apply() }
    private val publish = object : Runnable {
        override fun run() {
            if (!active) return
            val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            SignalState.battery = if (level >= 0 && scale > 0) level * 100 / scale else null
            SignalState.charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
            snapshot = JSONObject().apply {
                put("version", 1); put("id", id); put("name", Build.MODEL)
                put("level", SignalState.level ?: JSONObject.NULL)
                put("dbm", SignalState.dbm ?: JSONObject.NULL)
                val connectivity = context.getSystemService(ConnectivityManager::class.java)
                val capabilities = connectivity.getNetworkCapabilities(connectivity.activeNetwork)
                val wifi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
                put("network", if (wifi) "WiFi" else SignalState.network)
                put("cellularNetwork", SignalState.network)
                put("operatorName", SignalState.operator)
                put("signalAgeSeconds", SignalState.updatedAt?.let { (SystemClock.elapsedRealtime() - it) / 1000 } ?: JSONObject.NULL)
                put("battery", SignalState.battery ?: JSONObject.NULL); put("charging", SignalState.charging)
            }.toString()
            main.postDelayed(this, 1000)
        }
    }

    fun start() {
        val previous = prefs.getInt("port", 0)
        val server = try { ServerSocket(previous) } catch (_: java.io.IOException) { ServerSocket(0) }
        socket = server
        prefs.edit().putInt("port", server.localPort).remove("token").apply()
        active = true
        SignalState.connection = "Porta: ${server.localPort}\nIPs: " + addresses().joinToString(", ") + "\nNo Mac: Conectar e aprovar neste celular."
        main.post(publish)
        val nsd = context.getSystemService(NsdManager::class.java)
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) {}
            override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
            override fun onServiceUnregistered(info: NsdServiceInfo) {}
            override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
        }
        registration = listener
        nsd.registerService(NsdServiceInfo().apply {
            serviceName = "Phone2Mac-" + id.take(8)
            serviceType = "_phone2mac._tcp."
            port = server.localPort
        }, NsdManager.PROTOCOL_DNS_SD, listener)
        executor.execute {
            while (active) {
                try {
                    server.accept().use { client ->
                        client.soTimeout = 2000
                        val input = client.getInputStream().bufferedReader()
                        // Bound header size and read time to avoid unbounded clients.
                        var total = 0
                        fun line(): String {
                            val text = StringBuilder()
                            while (true) {
                                val c = input.read()
                                if (c < 0 || c == 10) return text.toString().trimEnd('\r')
                                if (++total > 8192) throw java.io.IOException("Header too large")
                                text.append(c.toChar())
                            }
                        }
                        val request = line()
                        var auth = ""
                        var clientId = ""
                        var clientName = "Mac"
                        while (true) {
                            val header = line()
                            if (header.isEmpty()) break
                            if (header.startsWith("Authorization:", true)) auth = header.substringAfter(":").trim()
                            if (header.startsWith("X-Client-Id:", true)) clientId = header.substringAfter(":").trim()
                            if (header.startsWith("X-Client-Name:", true)) clientName = header.substringAfter(":").trim()
                        }
                        val allowed = PairingApproval.authorized(context, auth)
                        val validPath = request.startsWith("GET /v1/status HTTP/1.")
                        val pairing = if (request.startsWith("POST /v1/pair HTTP/1.")) PairingApproval.request(context, clientId, clientName, auth.removePrefix("Bearer ")) else null
                        val statusCode = pairing?.first ?: if (!allowed) 401 else if (!validPath) 404 else 200
                        val code = "$statusCode " + when (statusCode) { 200 -> "OK"; 202 -> "Accepted"; 401 -> "Unauthorized"; 409 -> "Conflict"; 429 -> "Too Many Requests"; else -> "Bad Request" }
                        val body = pairing?.second ?: if (allowed && validPath) snapshot else "{}"
                        val bytes = body.toByteArray(Charsets.UTF_8)
                        client.getOutputStream().apply {
                            write("HTTP/1.1 $code\r\nContent-Type: application/json\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n".toByteArray())
                            write(bytes); flush()
                        }
                    }
                } catch (_: java.io.IOException) { /* Timeout or shutdown; continue only while active. */ }
            }
        }
    }

    fun stop() {
        active = false
        PairingApproval.clearPending()
        main.removeCallbacks(publish)
        socket?.close()
        registration?.let { try { context.getSystemService(NsdManager::class.java).unregisterService(it) } catch (_: IllegalArgumentException) {} }
        executor.shutdownNow()
        SignalState.connection = "Servidor parado"
    }

    private fun addresses(): List<String> = try {
        NetworkInterface.getNetworkInterfaces().toList().flatMap { it.inetAddresses.toList() }
            .filterIsInstance<Inet4Address>().filter { !it.isLoopbackAddress }.mapNotNull { it.hostAddress }
    } catch (_: Exception) { emptyList() }
}
