import AppKit
import SwiftUI
import Combine

@main
struct PhoneSignalSyncApp: App {
    @NSApplicationDelegateAdaptor(StatusBarController.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

/// One independent NSStatusItem and menu per phone, rather than a combined menu.
final class StatusBarController: NSObject, NSApplicationDelegate {
    private let store = PhoneStore()
    private var items: [String: NSStatusItem] = [:]
    private var observation: AnyCancellable?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        observation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }

    private func options(_ id: String) -> BarOptions {
        func enabled(_ key: String) -> Bool { UserDefaults.standard.object(forKey: "bar." + id + "." + key) as? Bool ?? true }
        return BarOptions(showName: enabled("name"), showPercentage: enabled("percentage"), showBatteryIcon: enabled("battery"), showWiFi: UserDefaults.standard.bool(forKey: "bar." + id + ".wifi"))
    }

    private func entry(_ title: String, action: Selector? = nil, value: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; item.representedObject = value
        return item
    }

    private func refresh() {
        let ids = store.phones.isEmpty ? ["empty"] : store.phones.map(\.id)
        for id in Array(items.keys) where !ids.contains(id) {
            if let item = items.removeValue(forKey: id) { NSStatusBar.system.removeStatusItem(item) }
        }
        for id in ids {
            let item = items[id] ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            items[id] = item
            let phone = store.phones.first { $0.id == id }
            item.button?.image = MenuBarIcon.render(phones: phone.map { [$0] } ?? [], options: options(id))
            item.button?.toolTip = phone.map { $0.displayName + " — click for signal and battery details" } ?? "Start monitoring on Android"
            let menu = NSMenu()
            if let phone = phone {
                menu.addItem(entry(phone.displayName))
                if phone.online, let status = phone.status {
                    menu.addItem(entry("Signal: " + (status.level.map { String($0) + "/4" } ?? "Unavailable")))
                    menu.addItem(entry("Power: " + (status.dbm.map { String($0) + " dBm" } ?? "Unavailable")))
                    let network = MenuBarIcon.technology(status.network)
                    menu.addItem(entry("Network: " + (network == "—" ? "Not reported by Android" : network)))
                    if let seen = phone.lastSeen {
                        let age = Int(Date().timeIntervalSince(seen))
                        menu.addItem(entry("Last response: " + String(age) + "s ago" + (phone.error.isEmpty ? "" : " — retrying")))
                    }
                    menu.addItem(entry("Carrier: " + status.operatorName))
                    menu.addItem(entry("Battery: " + (status.battery.map { String($0) + "%" } ?? "Unavailable")))
                    menu.addItem(entry(status.charging ? "Charging / full" : "On battery"))
                    menu.addItem(entry("Signal reading: " + (status.signalAgeSeconds.map { String($0) + "s ago" } ?? "Unavailable")))
                } else { menu.addItem(entry(phone.error)) }
                menu.addItem(.separator())
                let preferences = [("Show name", "name", options(id).showName), ("Show percentage", "percentage", options(id).showPercentage), ("Show battery icon", "battery", options(id).showBatteryIcon), ("Show WiFi", "wifi", options(id).showWiFi)]
                for (title, key, enabled) in preferences {
                    let toggle = entry(title, action: #selector(toggleOption(_:)), value: id + "|" + key)
                    toggle.state = enabled ? .on : .off
                    menu.addItem(toggle)
                }
                menu.addItem(entry("Set nickname…", action: #selector(rename(_:)), value: id))
                menu.addItem(entry("Connect / approve on phone…", action: #selector(pair(_:)), value: id))
                menu.addItem(entry("Forget phone", action: #selector(forget(_:)), value: id))
            } else { menu.addItem(entry("No phones found — start Android monitoring")) }
            menu.addItem(.separator())
            menu.addItem(entry("Add phone by IP…", action: #selector(addPhone)))
            menu.addItem(entry("Quit", action: #selector(quit)))
            item.menu = menu
        }
    }

    @objc private func toggleOption(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let split = value.lastIndex(of: "|") else { return }
        let id = String(value[..<split]); let option = String(value[value.index(after: split)...])
        let key = "bar." + id + "." + option
        UserDefaults.standard.set(!(UserDefaults.standard.object(forKey: key) as? Bool ?? (option != "wifi")), forKey: key)
        refresh()
    }
    @objc private func rename(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { store.rename(id) } }
    @objc private func pair(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { store.pair(id) } }
    @objc private func forget(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { store.forget(id) } }
    @objc private func addPhone() { store.addManual() }
    @objc private func quit() { NSApp.terminate(nil) }
}
