import XCTest
@testable import Segmentify

/// SFY-28774: fetching the user id and session id must be bounded, must report
/// its outcome exactly once and must never send an event more than once.
final class SessionBootstrapTests: XCTestCase {
    private var manager: SegmentifyManager!
    private let lock = NSLock()
    private var keyRequests = 0
    private var eventRequests = 0
    private var eventBodies: [[String: Any]] = []

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.clearSessionDefaults()
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        manager.testingClearNetworkSession()
        SegmentifyManager.sessionRetryDelays = [0.01, 0.01]
        keyRequests = 0
        eventRequests = 0
        eventBodies = []
    }

    override func tearDown() {
        // The manager is a singleton: let a running key request finish so that it
        // cannot answer, or be joined by, the next test.
        waitUntil("the session request to finish") { self.manager.testingIsSessionRequestIdle }
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyManager.sessionRetryDelays = SegmentifyManager.defaultSessionRetryDelays
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    private func counts() -> (key: Int, event: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (keyRequests, eventRequests)
    }

    /// Routes requests by endpoint and counts them. `key` receives the 1-based
    /// number of the key request it answers.
    private func serve(key: @escaping (Int, URLRequest) throws -> (HTTPURLResponse, Data)) {
        MockURLProtocol.requestHandler = { [unowned self] request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("/get/key") {
                self.lock.lock()
                self.keyRequests += 1
                let number = self.keyRequests
                self.lock.unlock()
                return try key(number, request)
            }
            // Count only events that carry the session issued in this test. Other
            // test classes share the singleton and their late events (sent with
            // the seeded "test-session") can still arrive here.
            let body = SegmentifyTestSupport.requestBody(of: request) ?? [:]
            if body["sessionId"] as? String == SessionBootstrapTests.issuedSessionId {
                self.lock.lock()
                self.eventRequests += 1
                self.eventBodies.append(body)
                self.lock.unlock()
            }
            let response = SegmentifyTestSupport.httpResponse(for: request)
            return (response, try SegmentifyTestSupport.jsonData(["responses": [[]]]))
        }
    }

    private static let issuedSessionId = "session-1"

    private func keysResponse(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let keys = ["user-1", SessionBootstrapTests.issuedSessionId]
        return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(keys))
    }

    private func bodies() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return eventBodies
    }

    private func sendPageView(category: String = "Home Page", _ onCallback: @escaping () -> Void) {
        let page = PageModel()
        page.category = category
        manager.sendPageView(segmentifyObject: page) { _ in onCallback() }
    }

    /// Lets late requests arrive so that "no more than N" assertions mean something.
    private func settle(_ seconds: TimeInterval = 0.5) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        wait(for: [settled], timeout: seconds + 5)
    }

    func testTransportErrorStopsAfterBoundedAttemptsAndCallsBackOnce() {
        serve { _, _ in throw URLError(.notConnectedToInternet) }
        let called = expectation(description: "callback")
        called.assertForOverFulfill = true

        sendPageView { called.fulfill() }

        wait(for: [called], timeout: 15)
        settle()
        XCTAssertEqual(counts().key, 3, "one attempt plus two retries")
        XCTAssertEqual(counts().event, 0, "no event may be sent without a session")
    }

    func testServerErrorStopsAfterBoundedAttemptsAndCallsBackOnce() {
        serve { _, request in
            (SegmentifyTestSupport.httpResponse(for: request, statusCode: 500), Data())
        }
        let called = expectation(description: "callback")
        called.assertForOverFulfill = true

        sendPageView { called.fulfill() }

        wait(for: [called], timeout: 15)
        settle()
        XCTAssertEqual(counts().key, 3)
        XCTAssertEqual(counts().event, 0)
    }

    func testErrorThenSuccessSendsTheEventExactlyOnce() {
        serve { [unowned self] number, request in
            if number == 1 {
                throw URLError(.notConnectedToInternet)
            }
            return try self.keysResponse(for: request)
        }
        let called = expectation(description: "callback")
        called.assertForOverFulfill = true

        sendPageView { called.fulfill() }

        wait(for: [called], timeout: 15)
        settle()
        XCTAssertEqual(counts().key, 2)
        XCTAssertEqual(counts().event, 1)
    }

    func testEventsWaitingForASessionShareOneKeyRequestAndKeepTheirOwnPayload() {
        serve { [unowned self] _, request in try self.keysResponse(for: request) }
        let called = expectation(description: "callbacks")
        called.expectedFulfillmentCount = 2
        called.assertForOverFulfill = true

        sendPageView(category: "Home Page") { called.fulfill() }
        sendPageView(category: "Category Page") { called.fulfill() }

        wait(for: [called], timeout: 15)
        settle()
        XCTAssertEqual(counts().key, 1)
        // Each event goes out on its own connection, so arrival order is not fixed.
        XCTAssertEqual(Set(bodies().compactMap { $0["category"] as? String }), ["Home Page", "Category Page"])
        XCTAssertEqual(counts().event, 2)
        XCTAssertEqual(bodies().map { $0["sessionId"] as? String }, ["session-1", "session-1"])
        XCTAssertEqual(bodies().map { $0["userId"] as? String }, ["user-1", "user-1"])
    }

    func testEventWithoutCallbackIsKeptAndSentWhenASessionArrivesLater() {
        serve { [unowned self] number, request in
            if number <= 3 {
                throw URLError(.notConnectedToInternet)
            }
            return try self.keysResponse(for: request)
        }
        let basket = BasketModel()
        basket.step = "add"
        basket.productId = "p1"
        basket.quantity = 1

        manager.sendAddOrRemoveBasket(segmentifyObject: basket)
        waitUntil("three failed key requests") {
            self.counts().key == 3 && self.manager.testingIsSessionRequestIdle
        }
        settle()
        XCTAssertEqual(counts().key, 3)
        XCTAssertEqual(counts().event, 0)

        let called = expectation(description: "callback")
        sendPageView { called.fulfill() }
        wait(for: [called], timeout: 15)
        waitUntil("both events to be sent") { self.counts().event == 2 }
        settle()

        XCTAssertEqual(counts().key, 4)
        XCTAssertEqual(bodies().compactMap { $0["name"] as? String }.sorted(), ["BASKET_OPERATIONS", "PAGE_VIEW"])
        let basketBody = bodies().first { $0["name"] as? String == "BASKET_OPERATIONS" }
        XCTAssertEqual(basketBody?["productId"] as? String, "p1")
        XCTAssertEqual(basketBody?["sessionId"] as? String, "session-1")
    }

    func testRateLimitedKeyRequestIsRetried() {
        serve { [unowned self] number, request in
            if number == 1 {
                return (SegmentifyTestSupport.httpResponse(for: request, statusCode: 429), Data())
            }
            return try self.keysResponse(for: request)
        }
        let called = expectation(description: "callback")
        called.assertForOverFulfill = true

        sendPageView { called.fulfill() }

        wait(for: [called], timeout: 15)
        settle()
        XCTAssertEqual(counts().key, 2)
        XCTAssertEqual(counts().event, 1)
    }
}
