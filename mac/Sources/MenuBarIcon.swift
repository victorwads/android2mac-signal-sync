import AppKit

/// A single template image keeps signal, radio technology and battery visible in MenuBarExtra.
struct BarOptions {
    var showName = true
    var showPercentage = true
    var showBatteryIcon = true
    var showWiFi = false
}

enum MenuBarIcon {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    // Center the visible capital-height, not the full font line box.
    private static var textY: CGFloat { (18 - font.capHeight) / 2 + font.descender }
    static func render(phones: [PhoneEntry], options: BarOptions = BarOptions()) -> NSImage {
        guard !phones.isEmpty else { return render(status: nil) }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let segments = phones.map { phone -> (String, NSImage, CGFloat) in
            let title = options.showName ? String(phone.displayName.prefix(16)) + ": " : ""
            let icon = render(status: phone.online ? phone.status : nil, options: options)
            return (title, icon, (title as NSString).size(withAttributes: attributes).width)
        }
        let width = segments.reduce(CGFloat(0)) { $0 + $1.2 + $1.1.size.width } + CGFloat(max(0, segments.count - 1) * 18)
        let result = NSImage(size: NSSize(width: width, height: 18), flipped: false) { _ in
            var x: CGFloat = 0
            for (title, icon, titleWidth) in segments {
                (title as NSString).draw(at: NSPoint(x: x, y: textY), withAttributes: attributes)
                x += titleWidth
                icon.draw(in: NSRect(x: x, y: 0, width: icon.size.width, height: 18))
                x += icon.size.width + 18
            }
            return true
        }
        result.isTemplate = true
        return result
    }

    static func render(status: PhoneStatus?, options: BarOptions = BarOptions()) -> NSImage {
        let technology = status.map { technology(displayNetwork($0, options: options)) } ?? "—"
        let network = technology == "—" ? "" : technology
        let battery = options.showPercentage ? (status?.battery.map { "\($0)%" } ?? "—") : ""
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let radioWidth = (network as NSString).size(withAttributes: attributes).width
        let batteryWidth = (battery as NSString).size(withAttributes: attributes).width
        let chargingWidth: CGFloat = status?.charging == true ? 11 : 0
        let batteryIconWidth: CGFloat = options.showBatteryIcon ? 28 : 0
        let barsX = network.isEmpty ? 0 : radioWidth + 4
        let batteryGroupX = barsX + 21
        let width = batteryGroupX + batteryIconWidth + batteryWidth + chargingWidth
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { _ in
            let level = status?.level
            for index in 0..<4 {
                let height = CGFloat(3 + index * 3)
                let rect = NSRect(x: barsX + CGFloat(index) * 4.5, y: 3, width: 3.5, height: height)
                NSColor.black.withAlphaComponent(level.map { index < $0 ? 1 : 0.22 } ?? 0.22).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 0.8, yRadius: 0.8).fill()
            }
            if level == nil { ("?" as NSString).draw(at: NSPoint(x: barsX + 6, y: textY), withAttributes: attributes) }
            (network as NSString).draw(at: NSPoint(x: 0, y: textY), withAttributes: attributes)
            let x = batteryGroupX + chargingWidth
            if options.showBatteryIcon {
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: NSRect(x: x, y: 4, width: 20, height: 10), xRadius: 2, yRadius: 2)
            outline.lineWidth = 1; outline.stroke()
            NSColor.black.setFill()
            NSBezierPath(rect: NSRect(x: x + 21, y: 7, width: 2, height: 4)).fill()
            if let percent = status?.battery {
                let fill = CGFloat(max(0, min(100, percent))) / 100 * 16
                NSBezierPath(roundedRect: NSRect(x: x + 2, y: 6, width: fill, height: 6), xRadius: 1, yRadius: 1).fill()
            }
            }
            if status?.charging == true {
                let bolt = NSBezierPath()
                let bx = batteryGroupX
                bolt.move(to: NSPoint(x: bx + 5, y: 15))
                bolt.line(to: NSPoint(x: bx + 1, y: 8))
                bolt.line(to: NSPoint(x: bx + 4, y: 8))
                bolt.line(to: NSPoint(x: bx + 3, y: 3))
                bolt.line(to: NSPoint(x: bx + 8, y: 10))
                bolt.line(to: NSPoint(x: bx + 5, y: 10))
                bolt.close()
                NSColor.black.setFill()
                bolt.fill()
            }
            (battery as NSString).draw(at: NSPoint(x: x + batteryIconWidth, y: textY), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func displayNetwork(_ status: PhoneStatus, options: BarOptions) -> String {
        if status.network == "WiFi" && !options.showWiFi { return status.cellularNetwork ?? "" }
        return status.network
    }

    static func technology(_ value: String) -> String {
        switch value {
        case "4G / LTE", "LTE": return "4G"
        case "WiFi", "4G", "4G+", "5G", "5G+", "3G", "2G": return value
        default: return "—"
        }
    }
}
