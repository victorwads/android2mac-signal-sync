import AppKit

@main struct IconChecks {
    static func main() throws {
        let first = PhoneStatus(version: 1, id: "leo", name: "Phone One", level: 2, dbm: -95, network: "4G+", operatorName: "Carrier", signalAgeSeconds: 1, battery: 20, charging: false)
        let second = PhoneStatus(version: 1, id: "victor", name: "Phone Two", level: 4, dbm: -80, network: "5G+", operatorName: "Carrier", signalAgeSeconds: 1, battery: 30, charging: true)
        let phones = [PhoneEntry(id: "leo", name: first.name, host: "one", port: 1, status: first, lastSeen: Date(), nickname: "Leo"), PhoneEntry(id: "victor", name: second.name, host: "two", port: 2, status: second, lastSeen: Date(), nickname: "Victor")]
        precondition(phones[0].displayName == "Leo" && phones[1].displayName == "Victor")
        for network in ["4G", "4G+", "5G", "5G+"] { precondition(MenuBarIcon.technology(network) == network) }
        for level in 0...4 {
            let value = PhoneStatus(version: 1, id: "test", name: "Test", level: level, dbm: nil, network: "4G", operatorName: "", signalAgeSeconds: 0, battery: 50, charging: false)
            precondition(MenuBarIcon.render(status: value).size.height == 18)
        }
        var wifiStatus = first
        // Decode the Android extension while keeping compatibility with old payloads.
        let wifiJSON = #"{"version":1,"id":"wifi","name":"Phone","level":2,"network":"WiFi","cellularNetwork":"4G+","operatorName":"Carrier","battery":50,"charging":false}"#
        wifiStatus = try JSONDecoder().decode(PhoneStatus.self, from: Data(wifiJSON.utf8))
        precondition(!BarOptions().showWiFi)
        precondition(MenuBarIcon.displayNetwork(wifiStatus, options: BarOptions()) == "4G+")
        precondition(MenuBarIcon.displayNetwork(wifiStatus, options: BarOptions(showWiFi: true)) == "WiFi")
        let full = MenuBarIcon.render(phones: [phones[0]])
        let compact = MenuBarIcon.render(phones: [phones[0]], options: BarOptions(showName: false, showPercentage: false, showBatteryIcon: false))
        precondition(compact.size.width < full.size.width)
        for name in [false, true] {
            for percentage in [false, true] {
                for battery in [false, true] {
                    let icon = MenuBarIcon.render(phones: [phones[1]], options: BarOptions(showName: name, showPercentage: percentage, showBatteryIcon: battery))
                    precondition(icon.size.width > 0 && icon.tiffRepresentation != nil)
                }
            }
        }
        let image = MenuBarIcon.render(phones: phones)
        precondition(image.size.width > MenuBarIcon.render(status: first).size.width * 2)
        let preview = NSImage(size: NSSize(width: image.size.width + 24, height: 42))
        preview.lockFocus()
        NSColor.white.setFill(); NSBezierPath(rect: NSRect(origin: .zero, size: preview.size)).fill()
        image.draw(at: NSPoint(x: 12, y: 12), from: .zero, operation: .sourceOver, fraction: 1)
        preview.unlockFocus()
        let bitmap = NSBitmapImageRep(data: preview.tiffRepresentation!)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/phone2mac-menu-preview.png"))
        print("PASS: all network labels, levels 0–4, aliases and simultaneous menu rendering")
    }
}
