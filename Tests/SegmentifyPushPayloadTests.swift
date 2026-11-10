import XCTest
@testable import Segmentify

final class SegmentifyPushPayloadTests: XCTestCase {

    private func fixture(_ name: String) throws -> [AnyHashable: Any] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "push-fixtures"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try XCTUnwrap(object as? [AnyHashable: Any])
    }

    private func adding(_ extra: [AnyHashable: Any], to userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        userInfo.merging(extra) { _, new in new }
    }

    private let v2Keys: [AnyHashable: Any] = ["sgmVersion": "2", "tag": "summer-sale", "userId": "user-1"]

    func testV2AndLegacyFcmAndApnsParseIdentically() throws {
        let legacyFcm = SegmentifyPushPayload(userInfo: try fixture("legacy-ios-fcm"))
        let v2Fcm = SegmentifyPushPayload(userInfo: adding(v2Keys, to: try fixture("legacy-ios-fcm")))
        XCTAssertEqual(legacyFcm, v2Fcm.withoutV2Keys())

        let legacyApns = SegmentifyPushPayload(userInfo: try fixture("legacy-apns"))
        let v2Apns = SegmentifyPushPayload(userInfo: adding(v2Keys.merging(["message": "Up to 50% off"]) { _, new in new }, to: try fixture("legacy-apns")))
        XCTAssertEqual(legacyApns, v2Apns.withoutV2Keys())

        XCTAssertEqual(v2Fcm.sgmVersion, "2")
        XCTAssertTrue(v2Fcm.isV2)
        XCTAssertFalse(legacyFcm.isV2)
        XCTAssertEqual(v2Apns.tag, "summer-sale")
        XCTAssertEqual(v2Apns.userId, "user-1")
    }

    func testSharedV2FixtureParsesLikeItsLegacyFixture() throws {
        let legacy = SegmentifyPushPayload(userInfo: try fixture("legacy-android"))
        let v2 = SegmentifyPushPayload(userInfo: try fixture("v2-full"))

        XCTAssertTrue(v2.isV2)
        XCTAssertEqual(v2.withoutV2Keys(), legacy)
        XCTAssertEqual(v2.tag, "summer-sale")
        XCTAssertEqual(v2.userId, "user-1")
    }

    func testArrayAndStringActionsParseTheSame() throws {
        let arrayActions = SegmentifyPushPayload(userInfo: try fixture("legacy-vapid")).actions
        let stringActions = SegmentifyPushPayload(userInfo: try fixture("legacy-web-fcm")).actions

        XCTAssertEqual(arrayActions, stringActions)
        XCTAssertEqual(arrayActions, [SegmentifyPushAction(action: "action0", title: "Open", redirectUrl: "https://shop.example.com/open")])
    }

    func testBooleanValuesAreTreatedAsMissing() {
        let payload = SegmentifyPushPayload(userInfo: ["instanceId": true, "sgmVersion": 2])

        XCTAssertNil(payload.instanceId)
        XCTAssertEqual(payload.sgmVersion, "2")
    }

    func testParsesLegacyFcmKeys() throws {
        let payload = SegmentifyPushPayload(userInfo: try fixture("legacy-ios-fcm"))

        XCTAssertEqual(payload.title, "Summer sale")
        XCTAssertEqual(payload.message, "Up to 50% off")
        XCTAssertEqual(payload.image, "https://cdn.example.com/sale.png")
        XCTAssertEqual(payload.redirectUrl, "https://shop.example.com/sale")
        XCTAssertEqual(payload.deeplink, "app://sale-ios")
        XCTAssertEqual(payload.instanceId, "ins-1")
        XCTAssertEqual(payload.apiKey, "api-key")
        XCTAssertEqual(payload.dataCenterUrl, "https://dc.example.com")
        XCTAssertEqual(payload.actions, [SegmentifyPushAction(action: "action0", title: "Open", redirectUrl: "https://shop.example.com/open")])
    }

    func testMissingMessageAndTitleFallBackToApsAlert() throws {
        var userInfo = try fixture("legacy-apns")
        userInfo["title"] = nil

        let payload = SegmentifyPushPayload(userInfo: userInfo)

        XCTAssertEqual(payload.message, "Up to 50% off")
        XCTAssertEqual(payload.title, "Summer sale")
    }

    func testStringApsAlertIsTheMessage() {
        let payload = SegmentifyPushPayload(userInfo: ["aps": ["alert": "Up to 50% off"]])

        XCTAssertEqual(payload.message, "Up to 50% off")
        XCTAssertEqual(payload.title, "")
    }

    func testEmptyDeeplinkFallsBackToRedirectUrl() throws {
        let payload = SegmentifyPushPayload(userInfo: adding(["deeplink": ""], to: try fixture("legacy-ios-fcm")))

        XCTAssertNil(payload.deeplink)
        XCTAssertEqual(payload.targetUrl, "https://shop.example.com/sale")
    }

    func testDeeplinkIsTheTargetUrl() throws {
        XCTAssertEqual(SegmentifyPushPayload(userInfo: try fixture("legacy-ios-fcm")).targetUrl, "app://sale-ios")
    }

    func testUnknownKeysAreIgnored() throws {
        let userInfo = try fixture("legacy-ios-fcm")

        XCTAssertEqual(SegmentifyPushPayload(userInfo: userInfo), SegmentifyPushPayload(userInfo: adding(["futureKey": "value"], to: userInfo)))
    }

    func testMalformedActionsGiveEmptyList() throws {
        let payload = SegmentifyPushPayload(userInfo: try fixture("malformed-actions"))

        XCTAssertEqual(payload.actions, [])
        XCTAssertEqual(payload.title, "Summer sale")
    }

    func testEmptyUserInfoDoesNotCrash() throws {
        let payload = SegmentifyPushPayload(userInfo: try fixture("empty"))

        XCTAssertEqual(payload.title, "")
        XCTAssertEqual(payload.message, "")
        XCTAssertNil(payload.instanceId)
        XCTAssertNil(payload.targetUrl)
        XCTAssertEqual(payload.actions, [])
    }

    func testEmptyV2ValuesAreTreatedAsMissing() throws {
        let payload = SegmentifyPushPayload(userInfo: try fixture("v2-minimal"))

        XCTAssertNil(payload.instanceId)
        XCTAssertNil(payload.tag)
        XCTAssertNil(payload.targetUrl)
        XCTAssertEqual(payload.actions, [])
    }

    func testProviderTypeIsFirebaseForFcmAndApnsOtherwise() throws {
        let fcm = SegmentifyPushPayload(userInfo: adding(["gcm.message_id": "0:1"], to: try fixture("legacy-ios-fcm")))
        let apns = SegmentifyPushPayload(userInfo: try fixture("legacy-apns"))

        XCTAssertEqual(fcm.providerType, .FIREBASE)
        XCTAssertEqual(apns.providerType, .APNS)
    }

    func testPushInteractionUsesPayloadInstanceIdAndProviderType() throws {
        let payload = SegmentifyPushPayload(userInfo: adding(["gcm.message_id": "0:1"], to: try fixture("legacy-ios-fcm")))

        let model = try XCTUnwrap(SegmentifyManager.pushInteractionModel(payload: payload, type: .CLICK))

        XCTAssertEqual(model.type, .CLICK)
        XCTAssertEqual(model.instanceId, "ins-1")
        XCTAssertEqual(model.providerType, .FIREBASE)
    }

    func testPushInteractionCarriesCorrelationId() throws {
        let payload = SegmentifyPushPayload(userInfo: ["instanceId": "ins-1", "correlationId": "corr-1"])

        let model = try XCTUnwrap(SegmentifyManager.pushInteractionModel(payload: payload, type: .VIEW))

        XCTAssertEqual(model.correlationId, "corr-1")
    }

    func testFcmNotificationInstanceIdIsUsedWhenTopLevelIsMissing() {
        let payload = SegmentifyPushPayload(userInfo: ["gcm.message_id": "0:1", "gcm.notification.instanceId": "ins-fcm"])

        XCTAssertEqual(payload.instanceId, "ins-fcm")
        XCTAssertEqual(payload.providerType, .FIREBASE)
        XCTAssertTrue(payload.isSegmentifyNotification)
    }

    func testPushInteractionWithoutInstanceIdIsNotSent() throws {
        XCTAssertNil(SegmentifyManager.pushInteractionModel(payload: SegmentifyPushPayload(userInfo: try fixture("empty")), type: .VIEW))
    }

    func testPermissionInfoEncodesSdkVersion() throws {
        let model = NotificationModel()
        model.type = .PERMISSION_INFO
        model.deviceToken = "device-token"

        let body = try XCTUnwrap(SegmentifyManager.subscriptionBody(for: model))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        let versionFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("version")
        let expected = try String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertNotEqual(SDKVersion.value, "unknown")
        XCTAssertEqual(json["sdkVersion"] as? String, expected)
    }

    func testSubscriptionBodyOfOtherTypesHasNoSdkVersion() throws {
        let model = NotificationModel()
        model.type = .VIEW
        model.sdkVersion = "stale"

        let body = try XCTUnwrap(SegmentifyManager.subscriptionBody(for: model))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["sdkVersion"])
    }

    func testInteractionsDoNotCarrySdkVersion() {
        XCTAssertNil(SegmentifyManager.registrationSdkVersion(for: .VIEW))
        XCTAssertNil(SegmentifyManager.registrationSdkVersion(for: .CLICK))
    }
}

private extension SegmentifyPushPayload {
    func withoutV2Keys() -> SegmentifyPushPayload {
        var copy = self
        copy.sgmVersion = nil
        copy.tag = nil
        copy.userId = nil
        return copy
    }
}
