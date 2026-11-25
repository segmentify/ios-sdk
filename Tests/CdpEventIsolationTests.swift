import XCTest
@testable import Segmentify

/// Proves that CDP events dispatch through their own isolated request and never
/// mutate the shared `eventRequest` used by the legacy tracking pipeline.
final class CdpEventIsolationTests: XCTestCase {
    private var manager: SegmentifyManager!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        super.tearDown()
    }

    func testLoginUserDispatchesWithoutMutatingSharedRequest() {
        let dispatched = expectation(description: "cdp event dispatched")

        MockURLProtocol.requestHandler = SegmentifyTestSupport.routeRequests { request in
            dispatched.fulfill()
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.emptyEventResponse()
            return (response, data)
        }

        manager.loginUser(["email": "user@example.com"])

        wait(for: [dispatched], timeout: 15)

        let sharedRequest = manager.testingCurrentRequestDictionary()
        XCTAssertNil(sharedRequest["name"], "CDP event must not set the shared request event name")
        XCTAssertNil(sharedRequest["properties"], "CDP payload must not leak into the shared request")
    }

    func testSubscribeUserDispatchesEvent() {
        let dispatched = expectation(description: "subscribe dispatched")

        MockURLProtocol.requestHandler = SegmentifyTestSupport.routeRequests { request in
            dispatched.fulfill()
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.emptyEventResponse()
            return (response, data)
        }

        manager.subscribeUser(.email(email: "user@example.com", purpose: "marketing"))

        wait(for: [dispatched], timeout: 15)

        let sharedRequest = manager.testingCurrentRequestDictionary()
        XCTAssertNil(sharedRequest["name"])
    }
}
