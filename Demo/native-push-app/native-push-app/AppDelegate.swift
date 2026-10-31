import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import Segmentify

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Segmentify Config
        // Change your appKey, dataCenterUrl and subDomain values with suitable one
        SegmentifyManager.setConfig(apiKey: nil, dataCenterUrl: "https://push-notification-api.preprod.cloud.unifonic.com", subDomain: "push-sfy-web.int.oci.ruh.dev.unifonic.com", authHeader: segmentifyDemoAuthHeader())
        SegmentifyManager.setPushConfig(dataCenterUrlPush: "https://push-notification-api.preprod.cloud.unifonic.com")
        let _ = SegmentifyManager.logStatus(isVisible: true)
        let _ = SegmentifyManager.setSessionKeepSecond(sessionKeepSecond: 604800)

    
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        application.registerForRemoteNotifications()

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs device token: \(hex)")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs kaydı başarısız: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        
        // Segmentify Event
        // fromPush copies instanceId and correlationId; VIEW goes to sendNotificationInteraction
        // (sendNotification posts to the subscription endpoint)
        let obj = NotificationModel.fromPush(userInfo: userInfo, type: NotificationType.VIEW)
        if obj.instanceId == nil {
            obj.instanceId = userInfo["gcm.notification.instanceId"] as? String
        }
        obj.providerType = ProviderType.FIREBASE
        SegmentifyManager.sharedManager().sendNotificationInteraction(segmentifyObject: obj)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        SegmentifyManager.sharedManager().handlePushNotificationResponse(
            response: response,
            completion: completionHandler
        )
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(String(describing: fcmToken))")
        NotificationCenter.default.post(name: .fcmTokenUpdated, object: fcmToken)

        // Segmentify Permission Info
        let obj = NotificationModel()
        obj.deviceToken = fcmToken ?? ""
        obj.type = NotificationType.PERMISSION_INFO
        obj.providerType = ProviderType.FIREBASE
        obj.userId = "2"
        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)
    }
}

/// Demo credentials are not committed. Set SEGMENTIFY_AUTH_HEADER either as an environment
/// variable in the scheme (Edit Scheme > Run > Arguments) or in a gitignored Secrets.plist
/// in the app target: <dict><key>SEGMENTIFY_AUTH_HEADER</key><string>TOKEN</string></dict>
func segmentifyDemoAuthHeader() -> String? {
    if let value = ProcessInfo.processInfo.environment["SEGMENTIFY_AUTH_HEADER"], !value.isEmpty {
        return value
    }
    guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
          let values = NSDictionary(contentsOf: url) as? [String: Any] else {
        print("Segmentify demo: SEGMENTIFY_AUTH_HEADER is not set (see segmentifyDemoAuthHeader)")
        return nil
    }
    return values["SEGMENTIFY_AUTH_HEADER"] as? String
}
