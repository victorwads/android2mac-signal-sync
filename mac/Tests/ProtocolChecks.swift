import Foundation

@main
struct ProtocolChecks {
    static func main() throws {
        let payload = #"{"version":1,"id":"one","name":"Phone One","level":3,"dbm":-95,"network":"LTE","operatorName":"Carrier","signalAgeSeconds":4,"battery":72,"charging":true}"#
        let first = try JSONDecoder().decode(PhoneStatus.self, from: Data(payload.utf8))
        let second = try JSONDecoder().decode(PhoneStatus.self, from: Data(payload.replacingOccurrences(of: "one", with: "two").utf8))
        let phones = [PhoneEntry(id: first.id, name: first.name, host: "10.0.0.1", port: 1000, status: first, lastSeen: Date()),
                      PhoneEntry(id: second.id, name: second.name, host: "10.0.0.2", port: 1001, status: second, lastSeen: Date(timeIntervalSinceNow: -61))]
        let store = PhoneStore(startDiscovery: false)
        store.phones = phones
        let originalSelection = UserDefaults.standard.string(forKey: "selectedPhone")
        store.select(first.id)
        precondition(store.selected?.id == first.id && store.barTitle.contains("72%"))
        store.select(second.id)
        precondition(store.selected?.id == second.id && store.barTitle == "—")
        store.phones[1].lastSeen = Date()
        precondition(store.barTitle.contains("72%"))
        UserDefaults.standard.set(originalSelection, forKey: "selectedPhone")
        precondition(phones.count == 2 && phones[0].id != phones[1].id)
        precondition(phones[0].online && !phones[1].online)
        precondition(PhoneStore.pairingCode(String(repeating: "a", count: 32)).count == 6)
        precondition(PhoneStore.pairingCode(String(repeating: "a", count: 32)) == PhoneStore.pairingCode(String(repeating: "a", count: 32)))
        precondition(first.battery == 72 && first.charging && first.level == 3)
        precondition(PhoneStore.isLocalIPv4("10.246.233.70"))
        precondition(PhoneStore.isLocalIPv4("192.168.1.1"))
        for invalid in ["8.8.8.8", "10.0.0.999", "10.0.0.1.2", "10..0.1", "localhost", "+10.0.0.1"] {
            precondition(!PhoneStore.isLocalIPv4(invalid))
        }
        let nullable = payload.replacingOccurrences(of: "\"level\":3", with: "\"level\":null").replacingOccurrences(of: "\"battery\":72", with: "\"battery\":null")
        let unknown = try JSONDecoder().decode(PhoneStatus.self, from: Data(nullable.utf8))
        precondition(unknown.level == nil && unknown.battery == nil)
        print("PASS: protocol decoding, two independent phones, stale connection, battery and local address validation")
    }
}
