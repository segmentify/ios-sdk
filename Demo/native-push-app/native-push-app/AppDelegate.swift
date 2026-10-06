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
        SegmentifyManager.config(appkey: "5c571072-068e-40c5-8dbc-d8448158de19", dataCenterUrl: "https://gandalf-qa.segmentify.com", subDomain: "demo.segmentify.com")
        SegmentifyManager.setPushConfig(dataCenterUrlPush: "https://gimli-qa.segmentify.com")
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
        let obj = NotificationModel()
        obj.type = NotificationType.VIEW
        obj.providerType = ProviderType.FIREBASE
        obj.instanceId = userInfo["instanceId"] as? String ?? ""
        obj.image = userInfo["image"] as? String
        obj.icon = userInfo["icon"] as? String
        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo

        if let deepLinkString = userInfo["deeplink"] as? String,
           var components = URLComponents(string: deepLinkString) {
            var queryItems = components.queryItems ?? []
            let image = userInfo["image"] as? String
            let icon = userInfo["icon"] as? String
            if let image = image {
                queryItems.append(URLQueryItem(name: "image", value: image))
            }
            if let icon = icon {
                queryItems.append(URLQueryItem(name: "icon", value: icon))
            }
            components.queryItems = queryItems
            if let finalUrl = components.url {
                DispatchQueue.main.async {
                    UIApplication.shared.open(finalUrl)
                }
            }
        } else {
            print("⚠️ 'deeplink' cannot be found")
        }
        
        let obj = NotificationModel()
        obj.deviceToken = ""
        obj.type = NotificationType.CLICK
        obj.providerType = ProviderType.FIREBASE
        obj.instanceId = userInfo["instanceId"] as? String ?? ""
        obj.image = userInfo["image"] as? String
        obj.icon = userInfo["icon"] as? String
        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)
        
        completionHandler()
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
