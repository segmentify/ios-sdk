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
        SegmentifyManager.setConfig(apiKey: nil,
                                 dataCenterUrl: "https://push-notification-api.preprod.cloud.unifonic.com",
                                 subDomain: "push-sfy-web.int.oci.ruh.dev.unifonic.com",
                                 authHeader: segmentifyDemoAuthHeader())
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
        // fromPush copies instanceId and correlationId; VIEW goes to sendNotificationInteraction
        // (sendNotification posts to the subscription endpoint)
        let obj = NotificationModel.fromPush(userInfo: userInfo, type: NotificationType.VIEW)
        obj.providerType = ProviderType.APNS
        SegmentifyManager.sharedManager().sendNotificationInteraction(segmentifyObject: obj)

        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - UNUserNotificationCenterDelegate (Tap / Click)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        SegmentifyManager.sharedManager().handlePushNotificationResponse(
            response: response,
            completion: completionHandler
        )
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
