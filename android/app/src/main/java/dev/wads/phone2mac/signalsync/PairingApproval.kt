package dev.wads.phone2mac.signalsync

import android.content.Context
import android.os.SystemClock
import org.json.JSONObject
import java.security.MessageDigest

object PairingApproval {
    data class Request(val client: String, val name: String, val token: String, val code: String, val expires: Long)
    private var pending: Request? = null
    private var lastRequestAt = -10000L

    @Synchronized fun current(): Request? {
        if (pending?.expires?.let { it <= SystemClock.elapsedRealtime() } == true) pending = null
        return pending
    }

    @Synchronized fun request(context: Context, client: String, name: String, token: String): Pair<Int, String> {
        if (!client.matches(Regex("[a-f0-9-]{36}")) || !token.matches(Regex("[a-f0-9]{32}"))) return 400 to "{}"
        val saved = context.getSharedPreferences("approved_macs", Context.MODE_PRIVATE).getString(client, null)
        if (saved != null && JSONObject(saved).optString("token") == token) return 200 to "{}"
        val old = current()
        if (old != null) return if (old.client == client && old.token == token) 202 to JSONObject().put("code", old.code).toString() else 409 to "{}"
        val now = SystemClock.elapsedRealtime()
        if (now - lastRequestAt < 5000) return 429 to "{}"
        lastRequestAt = now
        val digest = MessageDigest.getInstance("SHA-256").digest(token.toByteArray())
        val number = ((digest[0].toInt() and 255) shl 16) or ((digest[1].toInt() and 255) shl 8) or (digest[2].toInt() and 255)
        val code = (number % 1000000).toString().padStart(6, '0')
        pending = Request(client, name.take(80), token, code, now + 60000)
        return 202 to JSONObject().put("code", code).toString()
    }

    @Synchronized fun approve(context: Context) {
        val request = current() ?: return
        context.getSharedPreferences("approved_macs", Context.MODE_PRIVATE).edit().putString(request.client,
            JSONObject().put("name", request.name).put("token", request.token).toString()).apply()
        pending = null
    }
    @Synchronized fun clearPending() { pending = null; lastRequestAt = -10000L }
    @Synchronized fun reject() { pending = null; lastRequestAt = SystemClock.elapsedRealtime() + 60000 }
    fun authorized(context: Context, auth: String): Boolean {
        if (!auth.startsWith("Bearer ")) return false
        return context.getSharedPreferences("approved_macs", Context.MODE_PRIVATE).all.values.any {
            val value = it as? String ?: return@any false
            MessageDigest.isEqual(auth.toByteArray(), ("Bearer " + JSONObject(value).optString("token")).toByteArray())
        }
    }
    @Synchronized fun revokeAll(context: Context) {
        context.getSharedPreferences("approved_macs", Context.MODE_PRIVATE).edit().clear().apply()
        pending = null
    }
}
