package dev.wads.phone2mac.signalsync

/** Process-local state; never persisted as an apparently live reading after restart. */
object SignalState {
    var running = false
    var battery: Int? = null
    var charging = false
    var connection = "Servidor parado"
    var level: Int? = null
    var dbm: Int? = null
    var operator = "—"
    var network = "—"
    var updatedAt: Long? = null
    var message = "Monitoramento parado"

    fun clear() {
        level = null
        dbm = null
        operator = "—"
        network = "—"
        updatedAt = null
    }
}
