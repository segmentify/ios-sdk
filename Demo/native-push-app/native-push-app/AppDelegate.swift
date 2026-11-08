import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import Segmentify

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Segmentify Config (Segmentify QA by default; see DemoEnvironment to override)
        DemoEnvironment.apply()
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
        // fromPush copies instanceId (incl. FCM's gcm.notification.instanceId), correlationId and
        // providerType; VIEW goes to sendNotificationInteraction (sendNotification posts to the
        // subscription endpoint)
        let obj = NotificationModel.fromPush(userInfo: userInfo, type: NotificationType.VIEW)
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

/// Backend settings for this demo. The defaults are Segmentify QA. To run against another
/// environment (e.g. Unifonic), override any value without editing code, either as an
/// environment variable in the scheme (Edit Scheme > Run > Arguments) or in a gitignored
/// Secrets.plist in the app target. See Demo/README.md and Demo/Secrets.example.plist.
enum DemoEnvironment {
    static var authHeader: String? { value("SEGMENTIFY_AUTH_HEADER") }
    /// With an auth header and no explicit API key, no apiKey is sent.
    static var apiKey: String? { value("SEGMENTIFY_API_KEY") ?? (authHeader == nil ? "5c571072-068e-40c5-8dbc-d8448158de19" : nil) }
    static var dataCenterUrl: String { value("SEGMENTIFY_DATA_CENTER_URL") ?? "https://gandalf-qa.segmentify.com" }
    static var pushDataCenterUrl: String { value("SEGMENTIFY_PUSH_DATA_CENTER_URL") ?? "https://gimli-qa.segmentify.com" }
    static var subDomain: String { value("SEGMENTIFY_SUB_DOMAIN") ?? "demo.segmentify.com" }

    static func apply() {
        SegmentifyManager.setConfig(
            apiKey: apiKey,
            dataCenterUrl: dataCenterUrl,
            subDomain: subDomain,
            authHeader: authHeader
        )
        SegmentifyManager.setPushConfig(dataCenterUrlPush: pushDataCenterUrl)
    }

    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let values = NSDictionary(contentsOf: url) as? [String: Any] else {
            return [:]
        }
        return values
    }()

    private static func value(_ key: String) -> String? {
        let raw = ProcessInfo.processInfo.environment[key] ?? secrets[key] as? String
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
