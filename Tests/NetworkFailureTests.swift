import XCTest
@testable import Segmentify

/// SFY-28775 / SFY-28776: every request ends in exactly one `success` or
/// `failure`, and nothing in the request path can trap.
final class NetworkFailureTests: XCTestCase {
    private var manager: SegmentifyManager!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        SegmentifyManager.sessionRetryDelays = [0.01, 0.01]
    }

    override func tearDown() {
        waitUntil("the session request to finish") { self.manager.testingIsSessionRequestIdle }
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyManager.sessionRetryDelays = SegmentifyManager.defaultSessionRetryDelays
        SegmentifyTestSupport.resetTestNetworking()
        super.tearDown()
    }

    /// Answers page views with the given status and body; everything else gets
    /// an empty recommendation response.
    private func servePageView(status: Int, body: Data) {
        MockURLProtocol.requestHandler = SegmentifyTestSupport.routeRequests { request in
            if SegmentifyTestSupport.eventName(of: request) == "PAGE_VIEW" {
                return (SegmentifyTestSupport.httpResponse(for: request, statusCode: status), body)
            }
            return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(["responses": [[]]]))
        }
    }

    private func pageViewRecommendations() -> [RecommendationModel]? {
        let called = expectation(description: "recommendation callback")
        called.assertForOverFulfill = true
        var received: [RecommendationModel]?

        let page = PageModel()
        page.category = "Home Page"
        manager.sendPageView(segmentifyObject: page) { recommendations in
            received = recommendations
            called.fulfill()
        }

        wait(for: [called], timeout: 15)
        return received
    }

    // HTTP outcomes seen through the public API

    func testServerErrorCallsBackOnceWithNothing() {
        servePageView(status: 500, body: Data())

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    func testClientErrorCallsBackOnceWithNothing() throws {
        servePageView(status: 400, body: try SegmentifyTestSupport.jsonData(["statusCode": "NO_SESSIONID"]))

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    func testNoContentCallsBackOnceWithNothing() {
        servePageView(status: 204, body: Data())

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    func testBodyThatIsNotAJsonObjectCallsBackOnceWithNothing() throws {
        servePageView(status: 200, body: try SegmentifyTestSupport.jsonData(["a", "b"]))

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    func testBodyThatIsNotJsonCallsBackOnceWithNothing() {
        servePageView(status: 200, body: Data("<html>gateway</html>".utf8))

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    // The connection manager itself

    private struct StubRequest: SegmentifyRequestProtocol {
        var path = ""
        var port = ""
        var method = "POST"
        var subdomain = "segmentify-sdk.test"
        var dataCenterUrl = "https://segmentify-sdk.test"
        var apiKey = "test-api-key"
        var body: Dictionary<AnyHashable, Any> = ["name": "PAGE_VIEW"]

        func toDictionary() -> Dictionary<AnyHashable, Any> {
            body
        }
    }

    private enum Outcome: Equatable {
        case success
        case failure
    }

    private var lastError: Error?

    private func outcome(of request: StubRequest) -> Outcome? {
        let finished = expectation(description: "request finished")
        finished.assertForOverFulfill = true
        var outcome: Outcome?
        lastError = nil

        SegmentifyConnectionManager.sharedInstance.request(requestModel: request, success: { _ in
            outcome = .success
            finished.fulfill()
        }, failure: { error in
            outcome = .failure
            self.lastError = error
            finished.fulfill()
        })

        wait(for: [finished], timeout: 15)
        return outcome
    }

    func testBodyThatCannotBeSerializedFailsInsteadOfTrapping() {
        servePageView(status: 200, body: Data("{}".utf8))
        var request = StubRequest()
        request.body = ["name": "PAGE_VIEW", "when": Date()]

        XCTAssertEqual(outcome(of: request), .failure)
    }

    func testHttpErrorIsReportedAsFailure() {
        servePageView(status: 503, body: Data())

        XCTAssertEqual(outcome(of: StubRequest()), .failure)
    }

    func testSuccessIsReportedAsSuccess() {
        servePageView(status: 200, body: Data("{\"responses\":[[]]}".utf8))

        XCTAssertEqual(outcome(of: StubRequest()), .success)
    }

    // The backend answers every request with HTTP 200; a refusal is a body
    // whose statusCode is not SUCCESS (gandalf ResponseHelper.getResponse).

    func testEventRefusedByTheBackendIsAFailureCarryingTheReason() throws {
        servePageView(status: 200, body: try SegmentifyTestSupport.jsonData(["statusCode": "NO_SESSIONID", "timestamp": 1] as [String: Any]))

        XCTAssertEqual(outcome(of: StubRequest()), .failure)
        XCTAssertEqual(lastError as? SegmentifyNetworkError, .rejected(statusCode: "NO_SESSIONID"))
    }

    func testSuccessStatusCodeIsASuccess() throws {
        servePageView(status: 200, body: try SegmentifyTestSupport.jsonData(["statusCode": "SUCCESS", "responses": [[Any]]()] as [String: Any]))

        XCTAssertEqual(outcome(of: StubRequest()), .success)
    }

    func testHttpErrorKeepsTheResponseBody() {
        servePageView(status: 400, body: Data("bad request: missing apiKey".utf8))

        XCTAssertEqual(outcome(of: StubRequest()), .failure)
        XCTAssertEqual(lastError as? SegmentifyNetworkError, .httpStatus(400, body: "bad request: missing apiKey"))
    }

    // CDP events

    func testCdpSessionResolutionReportsBackWhenNoSessionCanBeObtained() {
        manager.testingClearNetworkSession()
        MockURLProtocol.requestHandler = { request in
            (SegmentifyTestSupport.httpResponse(for: request, statusCode: 500), Data())
        }
        let resolved = expectation(description: "resolution")
        resolved.assertForOverFulfill = true
        var resolvedSession: String? = "unset"

        manager.resolveCdpSession { _, sessionId in
            resolvedSession = sessionId
            resolved.fulfill()
        }

        wait(for: [resolved], timeout: 15)
        XCTAssertNil(resolvedSession)
    }
}
