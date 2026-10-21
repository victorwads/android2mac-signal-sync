package dev.wads.phone2mac.signalsync

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import java.net.Socket
import org.json.JSONObject

class LocalServerTest {
    @Test fun fullHttpApprovalBatteryAndRevocation() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        PairingApproval.revokeAll(context)
        PairingApproval.clearPending()
        val server = LocalSignalServer(context)
        instrumentation.runOnMainSync { server.start() }
        val token = java.util.UUID.randomUUID().toString().replace("-", "")
        val client = java.util.UUID.randomUUID().toString()
        fun call(path: String, method: String = "GET", authenticated: Boolean = true): Pair<Int, String> {
            return Socket("127.0.0.1", server.port).use { socket ->
                socket.soTimeout = 3000
                val headers = if (authenticated) "Authorization: Bearer $token\r\n" else ""
                socket.getOutputStream().write(("$method $path HTTP/1.1\r\nHost: localhost\r\n" + headers +
                    "X-Client-Id: $client\r\nX-Client-Name: Integration Mac\r\nConnection: close\r\n\r\n").toByteArray())
                val response = socket.getInputStream().bufferedReader().readText()
                response.substringBefore("\r\n").split(" ")[1].toInt() to response.substringAfter("\r\n\r\n")
            }
        }
        try {
            assertEquals(401, call("/v1/status", authenticated = false).first)
            assertEquals(401, call("/v1/status").first)
            val pairing = call("/v1/pair", "POST")
            assertEquals(202, pairing.first)
            assertEquals(PairingApproval.current()!!.code, JSONObject(pairing.second).getString("code"))
            assertEquals(401, call("/v1/status").first)
            instrumentation.runOnMainSync { PairingApproval.approve(context) }
            val status = call("/v1/status")
            assertEquals(200, status.first)
            val json = JSONObject(status.second)
            assertEquals(1, json.getInt("version"))
            assertTrue(json.getInt("battery") in 0..100)
            assertTrue(json.has("charging"))
            assertEquals(200, call("/v1/pair", "POST").first)
            PairingApproval.revokeAll(context)
            assertEquals(401, call("/v1/status").first)
        } finally {
            instrumentation.runOnMainSync { server.stop() }
            PairingApproval.revokeAll(context)
        }
    }
}
