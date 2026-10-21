package dev.wads.phone2mac.signalsync

import org.junit.Assert.*
import org.junit.Test

class SignalStateTest {
    @Test
    fun clearDiscardsPreviousRadioReading() {
        SignalState.level = 4
        SignalState.dbm = -80
        SignalState.network = "4G / LTE"
        SignalState.operator = "Test"
        SignalState.updatedAt = 123L
        SignalState.clear()
        assertNull(SignalState.level)
        assertNull(SignalState.dbm)
        assertNull(SignalState.updatedAt)
        assertEquals("—", SignalState.network)
        assertEquals("—", SignalState.operator)
    }
}
