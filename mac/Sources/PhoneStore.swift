import AppKit
import Foundation
import Security
import LocalAuthentication
import CryptoKit

struct PhoneStatus: Decodable {
    let version: Int
    let id: String
    let name: String
    let level: Int?
    let dbm: Int?
    let network: String
    var cellularNetwork: String? = nil
    let operatorName: String
    let signalAgeSeconds: Int?
    let battery: Int?
    let charging: Bool
}

struct PhoneEntry: Identifiable {
    let id: String
    var name: String
    var host: String
    var port: Int
    var status: PhoneStatus?
    var lastSeen: Date?
    var nickname: String? = nil
    var displayName: String { nickname?.isEmpty == false ? nickname! : name }
    var error = "Pair to connect"
    var online: Bool { lastSeen.map { Date().timeIntervalSince($0) < 60 } ?? false }
}

/// All UI state lives on the main queue. A request never overlaps a prior poll for that phone.
final class PhoneStore: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var phones: [PhoneEntry] = []
    @Published var selectedID = UserDefaults.standard.string(forKey: "selectedPhone")
    @Published var discoveryMessage = "Searching local network…"
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var timer: Timer?
    private var pending = Set<String>()
    private var approvalDeadlines: [String: Date] = [:]
    private var tokenReader: (String) -> String? = { KeychainToken.read(id: $0) }
    private var injectedSession: URLSession?
    private lazy var session: URLSession = {
        if let injected = injectedSession { return injected }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 3
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }()
    var accessibilitySummary: String {
        phones.map { phone in
            guard phone.online, let value = phone.status else { return phone.displayName + ": disconnected" }
            let signal = value.level.map { String($0) + " of 4" } ?? "unknown"
            let battery = value.battery.map { String($0) + "%" } ?? "unknown"
            let parts = [phone.displayName, value.network, "signal " + signal, "battery " + battery, value.charging ? "charging" : "on battery"]
            return parts.joined(separator: ", ")
        }.joined(separator: "; ")
    }
    var selected: PhoneEntry? { phones.first { $0.id == selectedID } ?? phones.first }
    var barTitle: String {
        guard let phone = selected, phone.online, let status = phone.status else { return "—" }
        let level = status.level.map { max(0, min(4, $0)) }
        let bars = level.map { String("▂▄▆█".prefix($0)) + String(repeating: "·", count: 4 - $0) } ?? "????"
        return "\(bars)  \(status.charging ? "⚡" : "▰") \(status.battery.map { "\($0)%" } ?? "—")"
    }

    override convenience init() { self.init(startDiscovery: true) }

    init(startDiscovery: Bool, session: URLSession? = nil, tokenReader: ((String) -> String?)? = nil) {
        super.init()
        self.injectedSession = session
        if let reader = tokenReader { self.tokenReader = reader }
        guard startDiscovery else { return }
        if let data = UserDefaults.standard.data(forKey: "manualPhones"),
           let saved = try? JSONDecoder().decode([SavedPhone].self, from: data) {
            phones = saved.map { PhoneEntry(id: $0.id, name: $0.name, host: $0.host, port: $0.port, nickname: $0.nickname) }
        }
        browser.delegate = self
        browser.searchForServices(ofType: "_phone2mac._tcp.", inDomain: "local.")
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }
    }

    func select(_ id: String) {
        selectedID = id
        UserDefaults.standard.set(id, forKey: "selectedPhone")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        discoveryMessage = "Discovery unavailable. Allow Local Network access or add an IP manually."
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName, sender.port > 0 else { return }
        let key = sender.name
        if let index = phones.firstIndex(where: { $0.id == key || ($0.host == host && $0.port == sender.port) }) {
            phones[index].host = host; phones[index].port = sender.port
        } else {
            phones.append(PhoneEntry(id: key, name: sender.name, host: host, port: sender.port))
        }
        discoveryMessage = "Phones on your local network"
        save()
        poll()
    }

    func pair(_ id: String) {
        guard let phone = phones.first(where: { $0.id == id }) else { return }
        let clientID = UserDefaults.standard.string(forKey: "clientID") ?? UUID().uuidString.lowercased()
        UserDefaults.standard.set(clientID, forKey: "clientID")
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        var components = URLComponents()
        components.scheme = "http"; components.host = phone.host; components.port = phone.port; components.path = "/v1/pair"
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(clientID, forHTTPHeaderField: "X-Client-Id")
        request.setValue("Mac", forHTTPHeaderField: "X-Client-Name")
        session.dataTask(with: request) { [weak self] data, response, _ in
            let http = response as? HTTPURLResponse
            let code = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["code"] as? String
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard http?.statusCode == 202, let code = code, code == Self.pairingCode(token) else {
                    self.showError("Could not request pairing. Open Android and try again; another request may be pending."); return
                }
                guard KeychainToken.store(token, id: id) else { self.showError("Could not save credentials in Keychain."); return }
                self.approvalDeadlines[id] = Date().addingTimeInterval(60)
                if let index = self.phones.firstIndex(where: { $0.id == id }) { self.phones[index].error = "Waiting for approval (60s)" }
                let alert = NSAlert()
                alert.messageText = "Approve on your phone: " + code
                alert.informativeText = "Open Android 2 Mac Sinal Sync, compare this code, then tap Permitir. No typing required. Request expires in 60 seconds. Trusted networks only: HTTP is not encrypted."
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
                self.poll()
            }
        }.resume()
    }

    func addManual() {
        let alert = NSAlert()
        alert.messageText = "Add phone by IP"
        alert.informativeText = "Enter the phone's local IPv4 address and port shown in the Android app, for example 10.246.233.70:43210."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Add"); alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let parts = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2, let port = Int(parts[1]), (1...65535).contains(port), Self.isLocalIPv4(String(parts[0])) else {
            showError("Enter a private local IPv4 address and a port between 1 and 65535."); return
        }
        let host = String(parts[0])
        let id = "manual-\(host):\(port)"
        if !phones.contains(where: { $0.id == id }) { phones.append(PhoneEntry(id: id, name: host, host: host, port: port)) }
        select(id); save(); pair(id)
    }

    static func pairingCode(_ token: String) -> String {
        let bytes = Array(SHA256.hash(data: Data(token.utf8)))
        let number = (Int(bytes[0]) << 16) | (Int(bytes[1]) << 8) | Int(bytes[2])
        return String(format: "%06d", number % 1_000_000)
    }

    static func isLocalIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }) else { return false }
        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        return octets[0] == 10 || (octets[0] == 192 && octets[1] == 168) ||
            (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 169 && octets[1] == 254)
    }

    func rename(_ id: String) {
        guard let phone = phones.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "Device nickname"
        alert.informativeText = "Up to 16 characters. Leave empty to use the device name."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = phone.nickname ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        setNickname(id, field.stringValue)
    }

    func setNickname(_ id: String, _ value: String) {
        guard let index = phones.firstIndex(where: { $0.id == id }) else { return }
        let clean = value.filter { !$0.isNewline && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }.trimmingCharacters(in: .whitespacesAndNewlines)
        phones[index].nickname = clean.isEmpty ? nil : String(clean.prefix(16))
        save()
    }

    func forget(_ id: String) {
        KeychainToken.remove(id: id)
        phones.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil; UserDefaults.standard.removeObject(forKey: "selectedPhone") }
        save()
    }

    func poll() {
        objectWillChange.send()
        for phone in phones where !pending.contains(phone.id) {
            guard let token = tokenReader(phone.id) else { continue }
            var components = URLComponents()
            components.scheme = "http"; components.host = phone.host; components.port = phone.port; components.path = "/v1/status"
            guard let url = components.url else { continue }
            pending.insert(phone.id)
            var request = URLRequest(url: url)
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            session.dataTask(with: request) { [weak self] data, response, error in
                let http = response as? HTTPURLResponse
                let status = data.flatMap { $0.count <= 32768 ? try? JSONDecoder().decode(PhoneStatus.self, from: $0) : nil }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.pending.remove(phone.id)
                    guard let index = self.phones.firstIndex(where: { $0.id == phone.id }) else { return }
                    if http?.statusCode == 200, let status = status, status.version == 1,
                       status.battery.map({ (0...100).contains($0) }) ?? true,
                       status.level.map({ (0...4).contains($0) }) ?? true {
                        self.approvalDeadlines.removeValue(forKey: phone.id)
                        self.phones[index].status = status
                        self.phones[index].name = status.name
                        self.phones[index].lastSeen = Date()
                        self.phones[index].error = ""
                    } else {
                        if http?.statusCode == 401 {
                            self.phones[index].lastSeen = nil
                            self.phones[index].status = nil
                        }
                        let waiting = self.approvalDeadlines[phone.id].map { $0 > Date() } ?? false
                        self.phones[index].error = waiting ? "Waiting for approval on Android" : (http?.statusCode == 401 ? "Access denied / expired — connect again" : "Disconnected / unavailable")
                    }
                }
            }.resume()
        }
    }

    private struct SavedPhone: Codable { let id: String; let name: String; let host: String; let port: Int; let nickname: String? }
    private func save() {
        let values = phones.map { SavedPhone(id: $0.id, name: $0.name, host: $0.host, port: $0.port, nickname: $0.nickname) }
        UserDefaults.standard.set(try? JSONEncoder().encode(values), forKey: "manualPhones")
    }
    private func showError(_ message: String) {
        let alert = NSAlert(); alert.messageText = message; alert.runModal()
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

private enum KeychainToken {
    private static var cache: [String: String] = [:]
    private static var attempted = Set<String>()
    static func query(_ id: String) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "dev.wads.phone2mac.signalsync", kSecAttrAccount as String: id, kSecUseAuthenticationContext as String: context]
    }
    static func store(_ token: String, id: String) -> Bool {
        remove(id: id)
        var item = query(id); item[kSecValueData as String] = Data(token.utf8)
        let saved = SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        if saved { cache[id] = token; attempted.insert(id) }
        return saved
    }
    static func read(id: String) -> String? {
        if attempted.contains(id) { return cache[id] }
        attempted.insert(id)
        var item = query(id); item[kSecReturnData as String] = true; item[kSecMatchLimit as String] = kSecMatchLimitOne
        // Background polling must never trigger a password dialog.
        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        let token = String(data: data, encoding: .utf8)
        cache[id] = token
        return token
    }
    static func remove(id: String) {
        cache.removeValue(forKey: id); attempted.remove(id)
        let item = query(id)
        SecItemDelete(item as CFDictionary)
    }
}
