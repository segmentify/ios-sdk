import XCTest
@testable import Segmentify

/// SFY-28784: a push call can come before the app configures the SDK (a
/// notification handled at launch). It must be dropped, not crash the app.
final class PushBeforeConfigTests: XCTestCase {

    override func tearDown() {
        SegmentifyManager.testingUnconfigure()
        SegmentifyTestSupport.configureSegmentify()
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    func testPushWithOnlyThePushUrlConfiguredDoesNotCrash() {
        SegmentifyManager.testingUnconfigure()
        SegmentifyManager.setPushConfig(dataCenterUrlPush: SegmentifyTestSupport.dataCenterURL)
        let notification = NotificationModel()
        notification.type = .PERMISSION_INFO
        notification.deviceToken = "device-token"
        notification.userId = "user-1"

        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: notification)
        SegmentifyManager.sharedManager().sendNotificationInteraction(segmentifyObject: notification)
    }
}
