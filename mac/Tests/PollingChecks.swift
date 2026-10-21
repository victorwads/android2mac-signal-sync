import Foundation

final class MockPhoneProtocol: URLProtocol {
    static var codes = ["one.local": 200, "two.local": 200]
    static var authorizedRequests = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let host = request.url!.host!
        let expected = host == "one.local" ? "Bearer first-secret" : "Bearer second-secret"
        guard request.value(forHTTPHeaderField: "Authorization") == expected else { fatalError("Credentials mixed across phones") }
        Self.authorizedRequests += 1
        let code = Self.codes[host]!
        let battery = host == "one.local" ? 81 : 24
        let payload = "{\"version\":1,\"id\":\"" + host + "\",\"name\":\"" + host + "\",\"level\":3,\"dbm\":-95,\"network\":\"LTE\",\"operatorName\":\"Carrier\",\"signalAgeSeconds\":2,\"battery\":" + String(battery) + ",\"charging\":false}"
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct PollingChecks {
    static func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !predicate() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        precondition(predicate(), "Timed out waiting for polling result")
    }
    static func main() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockPhoneProtocol.self]
        let store = PhoneStore(startDiscovery: false, session: URLSession(configuration: config), tokenReader: { $0 == "one" ? "first-secret" : "second-secret" })
        store.phones = [PhoneEntry(id: "one", name: "One", host: "one.local", port: 1234), PhoneEntry(id: "two", name: "Two", host: "two.local", port: 1235)]
        store.poll()
        waitUntil { store.phones.allSatisfy { $0.online } }
        precondition(store.phones[0].status?.battery == 81 && store.phones[1].status?.battery == 24)
        let original = UserDefaults.standard.string(forKey: "selectedPhone")
        store.select("one"); precondition(store.barTitle.contains("81%"))
        store.select("two"); precondition(store.barTitle.contains("24%"))
        MockPhoneProtocol.codes["two.local"] = 503
        store.poll()
        waitUntil { !store.phones[1].error.isEmpty }
        precondition(store.phones[1].online && store.phones[1].status?.battery == 24)
        store.phones[1].lastSeen = Date(timeIntervalSinceNow: -61)
        precondition(!store.phones[1].online)
        MockPhoneProtocol.codes["two.local"] = 401
        store.poll()
        waitUntil { store.phones[1].status == nil }
        precondition(store.phones[0].online && store.phones[1].status == nil && store.barTitle == "—")
        MockPhoneProtocol.codes["two.local"] = 200
        store.poll()
        waitUntil { store.phones[1].online }
        precondition(store.barTitle.contains("24%"))
        precondition(MockPhoneProtocol.authorizedRequests >= 6)
        UserDefaults.standard.set(original, forKey: "selectedPhone")
        print("PASS: production polling, per-phone credentials, two phones, selection, denial and reconnection")
    }
}
