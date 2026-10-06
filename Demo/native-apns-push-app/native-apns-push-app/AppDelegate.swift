//
//  AppDelegate.swift
//  SegmentifyDemo
//

import UIKit
import UserNotifications
import Segmentify

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    // MARK: - App Launch
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            print("Notification authorization granted: \(granted)")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        // Segmentify configuration
        SegmentifyManager.config(appkey: "3c9e211a-d049-43d5-aa4a-f98b7e66e482",
                                 dataCenterUrl: "https://push-notification-api.preprod.cloud.unifonic.com",
                                 subDomain: "demosfy.com",
                                 authToken: "ZTc5NmJlNGUtNjExNi00Y2Y4LTgyYjgtNDIxMGEzNjNkMWJlOlhtU09WbjJhMjNVOGhjV0xDNVlraDd3S0ZYblBpZUhx")
        SegmentifyManager.setPushConfig(dataCenterUrlPush: "https://push-notification-api.preprod.cloud.unifonic.com")
        _ = SegmentifyManager.logStatus(isVisible: true)
        _ = SegmentifyManager.setSessionKeepSecond(sessionKeepSecond: 604800)

        return true
    }

    // MARK: - APNs Token
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs device token: \(tokenString)")

        UserDefaults.standard.set(tokenString, forKey: "apnsToken")

        // Permission/registration info
        let obj = NotificationModel()
        obj.deviceToken = tokenString
        obj.type = NotificationType.PERMISSION_INFO
        obj.providerType = ProviderType.APNS
        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - UNUserNotificationCenterDelegate (Foreground Delivery)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let userInfo = notification.request.content.userInfo
        let instanceId = userInfo["instanceId"] as? String ?? ""

        let obj = NotificationModel()
        obj.type = NotificationType.VIEW
        obj.providerType = ProviderType.APNS
        obj.instanceId = instanceId
        obj.image = userInfo["image"] as? String
        obj.icon = userInfo["icon"] as? String
        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)

        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - UNUserNotificationCenterDelegate (Tap / Click)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped (APNs), userInfo: \(userInfo)")

        let instanceId = userInfo["instanceId"] as? String ?? ""

        // Handle Deep Link
        if let deepLinkString = userInfo["deeplink"] as? String,
           let url = URL(string: deepLinkString) {
            UIApplication.shared.open(url)
        }

        let obj = NotificationModel()
        obj.type = NotificationType.CLICK
        obj.providerType = ProviderType.APNS
        obj.instanceId = instanceId
        obj.image = userInfo["image"] as? String
        obj.icon = userInfo["icon"] as? String
        SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)

        completionHandler()
    }
}
