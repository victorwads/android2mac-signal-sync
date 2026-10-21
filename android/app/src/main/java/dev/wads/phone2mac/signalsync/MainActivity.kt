package dev.wads.phone2mac.signalsync

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.*
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class MainActivity : AppCompatActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var status: TextView
    private lateinit var details: TextView
    private lateinit var start: Button
    private lateinit var stop: Button
    private lateinit var approval: Button
    private lateinit var refusal: Button
    private val refresh = object : Runnable {
        override fun run() {
            render()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (24 * resources.displayMetrics.density).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
        }
        ViewCompat.setOnApplyWindowInsetsListener(layout) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(padding + bars.left, padding + bars.top, padding + bars.right, padding + bars.bottom)
            insets
        }
        status = TextView(this).apply { textSize = 22f }
        details = TextView(this).apply { textSize = 18f; setPadding(0, padding, 0, padding) }
        start = Button(this).apply {
            text = "Iniciar monitoramento"
            setOnClickListener { requestStart() }
        }
        stop = Button(this).apply {
            text = "Parar"
            setOnClickListener { stopService(Intent(this@MainActivity, SignalMonitorService::class.java)); render() }
        }
        approval = Button(this).apply { text = "Permitir conexão"; setOnClickListener { PairingApproval.approve(this@MainActivity); render() } }
        refusal = Button(this).apply { text = "Recusar"; setOnClickListener { PairingApproval.reject(); render() } }
        layout.addView(approval)
        layout.addView(refusal)
        layout.addView(Button(this).apply {
            text = "Revogar todos os Macs autorizados"
            setOnClickListener {
                android.app.AlertDialog.Builder(this@MainActivity).setMessage("Revogar todos os acessos?")
                    .setPositiveButton("Revogar") { _, _ -> PairingApproval.revokeAll(this@MainActivity) }.setNegativeButton("Cancelar", null).show()
            }
        })
        layout.addView(status)
        layout.addView(details)
        layout.addView(start)
        layout.addView(stop)
        layout.addView(TextView(this).apply {
            text = "O serviço continua com o app em segundo plano. O Android determina quando o sinal é atualizado; esta tela consulta a última leitura a cada segundo.\n\nNo Mac, selecione Conectar. Confira o código de seis dígitos nas duas telas e toque em Permitir neste celular. Abra esta tela para aprovar pedidos; eles expiram em 60 segundos. Se não aparecer, adicione IP e porta manualmente. Use apenas redes confiáveis: a conexão local não é criptografada. Em aparelhos dual SIM, usa o SIM de dados selecionado ao iniciar. Reinicie o monitoramento após trocar o SIM de dados.\n\n5G NSA pode ser informado como LTE. Sem leitura válida, o sinal aparece como indisponível."
            setPadding(0, padding, 0, 0)
        })
        setContentView(ScrollView(this).apply { addView(layout) })
        if (savedInstanceState == null && !SignalState.running) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) startMonitoring()
            else requestStart()
        }
    }

    private fun requestStart() {
        val permissions = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (permissions.isNotEmpty()) ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 1)
        else startMonitoring()
    }

    private fun startMonitoring() {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
            Toast.makeText(this, "Este aparelho não oferece telefonia celular", Toast.LENGTH_LONG).show()
            return
        }
        ContextCompat.startForegroundService(this, Intent(this, SignalMonitorService::class.java))
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                startMonitoring()
            } else Toast.makeText(this, "Autorize o acesso ao estado do telefone para ler o sinal", Toast.LENGTH_LONG).show()
        }
    }

    private fun render() {
        val request = PairingApproval.current()
        approval.visibility = if (request != null) android.view.View.VISIBLE else android.view.View.GONE
        refusal.visibility = approval.visibility
        approval.text = request?.let { "Permitir ${it.name}? Código: ${it.code}" } ?: "Permitir conexão"
        status.text = SignalState.message
        val age = SignalState.updatedAt?.let { (SystemClock.elapsedRealtime() - it) / 1000 }
        details.text = listOf(
            "Sinal: " + (SignalState.level?.let { "$it/4" } ?: "Indisponível"),
            "Potência: " + (SignalState.dbm?.let { "$it dBm" } ?: "Indisponível"),
            "Bateria: ${SignalState.battery?.let { "$it%" } ?: "—"} (carregando: ${SignalState.charging})",
            SignalState.connection,
            "Rede: ${SignalState.network}",
            "Operadora: ${SignalState.operator}",
            "Última leitura: " + (age?.let { "há $it s" } ?: "—")
        ).joinToString("\n")
        start.isEnabled = !SignalState.running
        stop.isEnabled = SignalState.running
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresh)
    }

    override fun onPause() {
        handler.removeCallbacks(refresh)
        super.onPause()
    }
}
