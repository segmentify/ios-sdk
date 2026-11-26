import XCTest
@testable import Segmentify

/// SFY-28784: one configuration for one manager, whatever the order of the
/// calls, and nothing sent before the SDK is configured.
final class ConfigurationTests: XCTestCase {
    private let lock = NSLock()
    private var urls: [String] = []

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.clearSessionDefaults()
        SegmentifyManager.testingUnconfigure()
        _ = SegmentifyManager.logStatus(isVisible: false)
        SegmentifyConnectionManager.testing_protocolClasses = [MockURLProtocol.self]
        SegmentifyManager.sessionRetryDelays = [0.01, 0.01]
        MockURLProtocol.requestHandler = { [unowned self] request in
            let url = request.url?.absoluteString ?? ""
            self.lock.lock()
            self.urls.append(url)
            self.lock.unlock()
            if url.contains("/get/key") {
                return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(["user-1", "session-1"]))
            }
            let body: [String: Any] = ["statusCode": "SUCCESS", "responses": [[]] as [[Any]]]
            return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(body))
        }
    }

    override func tearDown() {
        waitUntil("the session request to finish") { SegmentifyManager.sharedManager().testingIsSessionRequestIdle }
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyManager.sessionRetryDelays = SegmentifyManager.defaultSessionRetryDelays
        // The next test class starts from a configured SDK, as before this one.
        SegmentifyManager.testingUnconfigure()
        SegmentifyTestSupport.configureSegmentify()
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    private struct Outcome {
        var answers = 0
        var errors: [SegmentifyError] = []
        var total: Int { answers + errors.count }
    }

    private func pageView(on manager: SegmentifyManager) -> Outcome {
        var outcome = Outcome()
        let page = PageModel()
        page.category = "Home Page"
        manager.sendPageView(segmentifyObject: page, callback: { _ in outcome.answers += 1 }, onError: { outcome.errors.append($0) })
        waitUntil("an answer to the page view") { outcome.total > 0 }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        return outcome
    }

    private func sentURLs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    private func eventURLs() -> [String] {
        sentURLs().filter { $0.contains("/add/events/") }
    }

    // MARK: Before config

    func testEventBeforeConfigFailsThroughOnErrorWithoutARequest() {
        let outcome = pageView(on: SegmentifyManager.sharedManager())

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertTrue(outcome.errors.first?.message.contains("config") == true, "\(outcome.errors)")
        XCTAssertTrue(sentURLs().isEmpty, "sent before config: \(sentURLs())")
    }

    func testEventWithASessionBeforeConfigFailsThroughOnErrorWithoutARequest() {
        let manager = SegmentifyManager.sharedManager()
        manager.testingPrepareNetworkSession()

        let outcome = pageView(on: manager)

        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertTrue(outcome.errors.first?.message.contains("config") == true, "\(outcome.errors)")
        XCTAssertTrue(sentURLs().isEmpty, "sent before config: \(sentURLs())")
    }

    func testManagerTakenBeforeConfigIsConfiguredByConfig() {
        let early = SegmentifyManager.sharedManager()

        SegmentifyTestSupport.configureSegmentify()
        let outcome = pageView(on: early)

        XCTAssertTrue(outcome.errors.isEmpty, "\(outcome.errors)")
        XCTAssertTrue(
            eventURLs().contains { $0.hasPrefix(SegmentifyTestSupport.dataCenterURL) && $0.hasSuffix("apiKey=" + SegmentifyTestSupport.apiKey) },
            "\(sentURLs())"
        )
    }

    // MARK: setConfig

    func testSetConfigKeepsTheSameManager() {
        SegmentifyTestSupport.configureSegmentify()
        let first = SegmentifyManager.sharedManager()

        SegmentifyManager.setConfig(apiKey: "other-key", dataCenterUrl: SegmentifyTestSupport.dataCenterURL, subDomain: SegmentifyTestSupport.subDomain)

        XCTAssertTrue(first === SegmentifyManager.sharedManager())
    }

    func testSetConfigReachesAManagerTheHostAppAlreadyHolds() {
        SegmentifyTestSupport.configureSegmentify()
        let held = SegmentifyManager.sharedManager()

        SegmentifyManager.setConfig(apiKey: "other-key", dataCenterUrl: SegmentifyTestSupport.dataCenterURL, subDomain: SegmentifyTestSupport.subDomain)
        held.testingPrepareNetworkSession()
        let outcome = pageView(on: held)

        XCTAssertTrue(outcome.errors.isEmpty, "\(outcome.errors)")
        XCTAssertTrue(eventURLs().contains { $0.hasSuffix("apiKey=other-key") }, "\(sentURLs())")
    }
}
