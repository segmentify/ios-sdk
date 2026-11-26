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

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: { body in
            sentRequest = body
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

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: { body in
            sentRequest = body
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

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: { _ in
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

    func testPushPayloadReadsCorrelationId() {
        let payload = SegmentifyPushPayload(userInfo: ["instanceId": "psh_abc", "correlationId": "corr-1"])

        XCTAssertEqual(payload.correlationId, "corr-1")
    }

    func testPushPayloadTreatsEmptyCorrelationIdAsMissing() {
        XCTAssertNil(SegmentifyPushPayload(userInfo: ["instanceId": "psh_abc", "correlationId": ""]).correlationId)
        XCTAssertNil(SegmentifyPushPayload(userInfo: ["instanceId": "psh_abc"]).correlationId)
    }

    func testFromPushCopiesInstanceIdAndCorrelationId() {
        let model = NotificationModel.fromPush(userInfo: ["instanceId": "psh_abc", "correlationId": "corr-1"], type: .VIEW)

        XCTAssertEqual(model.type, .VIEW)
        XCTAssertEqual(model.instanceId, "psh_abc")
        XCTAssertEqual(model.correlationId, "corr-1")
    }

    func testCorrelationIdIsEncodedInInteractionBody() throws {
        let model = makeClick(instanceId: "psh_abc", interactionId: nil)
        model.correlationId = "corr-1"

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any]

        XCTAssertEqual(json?["correlationId"] as? String, "corr-1")
        XCTAssertEqual(json?["instanceId"] as? String, "psh_abc")
    }

    func testBlankCorrelationIdIsDroppedBeforeSending() {
        let legacyPosted = expectation(description: "legacy notification interaction posted")
        MockURLProtocol.requestHandler = stubAllRequests(onLegacyNotification: { legacyPosted.fulfill() })
        let model = makeClick(instanceId: "psh_abc", interactionId: nil)
        model.correlationId = " "

        manager.sendNotificationInteraction(segmentifyObject: model)

        wait(for: [legacyPosted], timeout: 3)
        XCTAssertNil(model.correlationId)
    }

    func testClickDoesNotLeakPushFieldsIntoSharedRequest() {
        let interactionSent = expectation(description: "push interaction dispatched")

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: { _ in
            interactionSent.fulfill()
        })

        manager.sendNotificationInteraction(segmentifyObject: makeClick(instanceId: "psh_abc", interactionId: "static"))

        wait(for: [interactionSent], timeout: 3)
        let shared = manager.testingCurrentRequestDictionary()
        XCTAssertNotEqual(shared["type"] as? String, "push")
        XCTAssertNotEqual(shared["instanceId"] as? String, "psh_abc")
        XCTAssertNotEqual(shared["interactionId"] as? String, "static")
    }

    func testClickFromBackgroundThreadIsSent() {
        let interactionSent = expectation(description: "push interaction dispatched")
        var sentRequest: [AnyHashable: Any] = [:]

        MockURLProtocol.requestHandler = stubAllRequests(onInteraction: { body in
            sentRequest = body
            interactionSent.fulfill()
        })

        DispatchQueue.global().async {
            self.manager.sendNotificationInteraction(segmentifyObject: self.makeClick(instanceId: "psh_bg", interactionId: nil))
        }

        wait(for: [interactionSent], timeout: 3)
        XCTAssertEqual(sentRequest["instanceId"] as? String, "psh_bg")
    }

    func testPushPayloadReadsFirebaseInstanceId() {
        let payload = SegmentifyPushPayload(userInfo: [
            "gcm.message_id": "1",
            "gcm.notification.instanceId": "psh_fcm"
        ])

        XCTAssertEqual(payload.instanceId, "psh_fcm")
        XCTAssertTrue(payload.isSegmentifyNotification)
    }

    func testTopLevelInstanceIdWinsOverFirebaseKey() {
        let payload = SegmentifyPushPayload(userInfo: [
            "instanceId": "psh_top",
            "gcm.notification.instanceId": "psh_fcm"
        ])

        XCTAssertEqual(payload.instanceId, "psh_top")
    }

    func testFromPushCopiesFirebaseInstanceIdAndProvider() {
        let model = NotificationModel.fromPush(userInfo: [
            "gcm.message_id": "1",
            "gcm.notification.instanceId": "psh_fcm"
        ], type: .CLICK)

        XCTAssertEqual(model.instanceId, "psh_fcm")
        XCTAssertEqual(model.providerType, .FIREBASE)
    }

    func testFromPushDetectsApnsProvider() {
        let userInfo: [AnyHashable: Any] = ["instanceId": "psh_apns", "aps": ["alert": ["body": "hi"]]]

        XCTAssertEqual(NotificationModel.fromPush(userInfo: userInfo, type: .VIEW).providerType, .APNS)
        XCTAssertEqual(NotificationModel.fromPush(userInfo: userInfo, type: .CLICK).providerType, .APNS)
    }

    private func makeClick(instanceId: String, interactionId: String?) -> NotificationModel {
        let model = NotificationModel()
        model.type = .CLICK
        model.instanceId = instanceId
        model.interactionId = interactionId
        return model
    }

    private func stubAllRequests(
        onInteraction: @escaping (_ body: [AnyHashable: Any]) -> Void = { _ in },
        onLegacyNotification: @escaping () -> Void = {}
    ) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let path = request.url?.absoluteString ?? ""
            if path.contains("/add/events/") {
                onInteraction(Self.jsonBody(of: request))
            }
            if path.contains("/native/interaction/notification") {
                onLegacyNotification()
            }
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.emptyEventResponse()
            return (response, data)
        }
    }

    /// URLProtocol may expose the POST body as a stream instead of `httpBody`.
    private static func jsonBody(of request: URLRequest) -> [AnyHashable: Any] {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            var buffer = Data()
            stream.open()
            defer { stream.close() }
            let chunk = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { chunk.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(chunk, maxLength: 4096)
                if read <= 0 { break }
                buffer.append(chunk, count: read)
            }
            data = buffer
        }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] else {
            return [:]
        }
        return json
    }
}
