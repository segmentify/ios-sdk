import XCTest
@testable import Segmentify

final class PushClickInteractionTests: XCTestCase {
    private var manager: SegmentifyManager!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.configureSegmentify()
        SegmentifyManager.setPushConfig(dataCenterUrlPush: SegmentifyTestSupport.dataCenterURL)
        manager = SegmentifyManager.sharedManager()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        UserDefaults.standard.removeObject(forKey: "SEGMENTIFY_PUSH_CAMPAIGN_ID")
        super.tearDown()
    }

    func testClickSendsPushInteractionWithSuppliedInteractionId() {
        let interactionSent = expectation(description: "push interaction dispatched")
        var sentRequest: [AnyHashable: Any] = [:]

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: {
            sentRequest = self.manager.testingCurrentRequestDictionary()
            interactionSent.fulfill()
        })

        manager.sendNotificationInteraction(segmentifyObject: makeClick(instanceId: "psh_abc", interactionId: "static"))

        wait(for: [interactionSent], timeout: 3)
        XCTAssertEqual(sentRequest["name"] as? String, "INTERACTION")
        XCTAssertEqual(sentRequest["type"] as? String, "push")
        XCTAssertEqual(sentRequest["instanceId"] as? String, "psh_abc")
        XCTAssertEqual(sentRequest["interactionId"] as? String, "static")
    }

    func testClickFallsBackToInstanceIdWhenInteractionIdMissing() {
        let interactionSent = expectation(description: "push interaction dispatched")
        var sentRequest: [AnyHashable: Any] = [:]

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: {
            sentRequest = self.manager.testingCurrentRequestDictionary()
            interactionSent.fulfill()
        })

        manager.sendNotificationInteraction(segmentifyObject: makeClick(instanceId: "psh_abc", interactionId: nil))

        wait(for: [interactionSent], timeout: 3)
        XCTAssertEqual(sentRequest["type"] as? String, "push")
        XCTAssertEqual(sentRequest["interactionId"] as? String, "psh_abc")
    }

    func testClickKeepsPostingLegacyNotificationInteraction() {
        let legacyPosted = expectation(description: "legacy notification interaction posted")

        MockURLProtocol.requestHandler = stubAllRequests(onLegacyNotification: {
            legacyPosted.fulfill()
        })

        manager.sendNotificationInteraction(segmentifyObject: makeClick(instanceId: "psh_abc", interactionId: "static"))

        wait(for: [legacyPosted], timeout: 3)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "SEGMENTIFY_PUSH_CAMPAIGN_ID"), "psh_abc")
    }

    func testClickViewStillSendsClickType() {
        let interactionSent = expectation(description: "click interaction dispatched")
        var sentRequest: [AnyHashable: Any] = [:]

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: {
            sentRequest = self.manager.testingCurrentRequestDictionary()
            interactionSent.fulfill()
        })

        manager.sendClickView(instanceId: "widget_1", interactionId: "product_1")

        wait(for: [interactionSent], timeout: 3)
        XCTAssertEqual(sentRequest["type"] as? String, "click")
        XCTAssertEqual(sentRequest["instanceId"] as? String, "widget_1")
        XCTAssertEqual(sentRequest["interactionId"] as? String, "product_1")
    }

    func testHandlePushClickedPostsInteractionWithPayloadInstanceId() {
        let legacyPosted = expectation(description: "push click posted to the interaction endpoint")

        MockURLProtocol.requestHandler = stubAllRequests(onLegacyNotification: {
            legacyPosted.fulfill()
        })

        manager.handlePushClicked(SegmentifyPushPayload(userInfo: ["instanceId": "psh_abc"]))

        wait(for: [legacyPosted], timeout: 3)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "SEGMENTIFY_PUSH_CAMPAIGN_ID"), "psh_abc")
    }

    func testHandlePushReceivedPostsViewToTheInteractionEndpoint() {
        let viewPosted = expectation(description: "push view posted to the interaction endpoint")

        MockURLProtocol.requestHandler = stubAllRequests(onLegacyNotification: {
            viewPosted.fulfill()
        })

        manager.handlePushReceived(SegmentifyPushPayload(userInfo: ["instanceId": "psh_abc"]))

        wait(for: [viewPosted], timeout: 3)
    }

    func testHandlePushWithoutInstanceIdSendsNothing() {
        let nothingSent = expectation(description: "no push interaction request")
        nothingSent.isInverted = true

        MockURLProtocol.requestHandler = stubAllRequests(onLegacyNotification: {
            nothingSent.fulfill()
        })

        manager.handlePushReceived(SegmentifyPushPayload(userInfo: [:]))
        manager.handlePushClicked(SegmentifyPushPayload(userInfo: ["instanceId": ""]))

        wait(for: [nothingSent], timeout: 1)
        XCTAssertNil(UserDefaults.standard.string(forKey: "SEGMENTIFY_PUSH_CAMPAIGN_ID"))
    }

    private func makeClick(instanceId: String, interactionId: String?) -> NotificationModel {
        let model = NotificationModel()
        model.type = .CLICK
        model.instanceId = instanceId
        model.interactionId = interactionId
        return model
    }

    private func stubAllRequests(
        onInteraction: @escaping () -> Void = {},
        onLegacyNotification: @escaping () -> Void = {}
    ) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let path = request.url?.absoluteString ?? ""
            if path.contains("/add/events/") {
                onInteraction()
            }
            if path.contains("/native/interaction/notification") {
                onLegacyNotification()
            }
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.emptyEventResponse()
            return (response, data)
        }
    }
}
