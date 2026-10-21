package dev.wads.phone2mac.signalsync

import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test

class PairingApprovalTest {
    @Test fun approvalRequiredAndRevocationWorks() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        PairingApproval.revokeAll(context)
        val client = java.util.UUID.randomUUID().toString()
        val token = java.util.UUID.randomUUID().toString().replace("-", "")
        assertFalse(PairingApproval.authorized(context, "Bearer $token"))
        assertEquals(400, PairingApproval.request(context, "bad", "Mac", token).first)
        val response = PairingApproval.request(context, client, "Test Mac", token)
        assertEquals(202, response.first)
        assertEquals(6, PairingApproval.current()!!.code.length)
        assertFalse(PairingApproval.authorized(context, "Bearer $token"))
        assertEquals(202, PairingApproval.request(context, client, "Test Mac", token).first)
        assertEquals(409, PairingApproval.request(context, java.util.UUID.randomUUID().toString(), "Other", token).first)
        PairingApproval.approve(context)
        assertTrue(PairingApproval.authorized(context, "Bearer $token"))
        assertFalse(PairingApproval.authorized(context, "Bearer wrong"))
        PairingApproval.revokeAll(context)
        assertFalse(PairingApproval.authorized(context, "Bearer $token"))
    }
}
