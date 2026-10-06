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
        SegmentifyManager.config(appkey: "2031ce11-59e2-aec3-39f2-3adc60252339",
                                 dataCenterUrl: "https://push-notification-api.preprod.cloud.unifonic.com",
                                 subDomain: "push-sfy-web.int.oci.ruh.dev.unifonic.com",
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
        SegmentifyManager.sharedManager().sendNotificationInteraction(segmentifyObject: obj)

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
           var components = URLComponents(string: deepLinkString) {
            var queryItems = components.queryItems ?? []
            if let image = userInfo["image"] as? String {
                queryItems.append(URLQueryItem(name: "image", value: image))
            }
            if let icon = userInfo["icon"] as? String {
                queryItems.append(URLQueryItem(name: "icon", value: icon))
            }
            components.queryItems = queryItems
            if let finalUrl = components.url {
                DispatchQueue.main.async {
                    UIApplication.shared.open(finalUrl)
                }
            }
        }

        let obj = NotificationModel()
        obj.type = NotificationType.CLICK
        obj.providerType = ProviderType.APNS
        obj.instanceId = instanceId
        obj.image = userInfo["image"] as? String
        obj.icon = userInfo["icon"] as? String
        SegmentifyManager.sharedManager().sendNotificationInteraction(segmentifyObject: obj)

        completionHandler()
    }
}
