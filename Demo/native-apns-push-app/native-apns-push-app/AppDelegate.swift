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

        // Segmentify configuration (Segmentify QA by default; see DemoEnvironment to override)
        DemoEnvironment.apply()
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

        // handlePushReceived sends the VIEW interaction with instanceId (incl. FCM's
        // gcm.notification.instanceId), correlationId and providerType from the payload
        let payload = SegmentifyPushPayload(userInfo: notification.request.content.userInfo)
        SegmentifyManager.sharedManager().handlePushReceived(payload)

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

/// Backend settings for this demo. The defaults are Segmentify QA. To run against another
/// environment (e.g. Unifonic), override any value without editing code, either as an
/// environment variable in the scheme (Edit Scheme > Run > Arguments) or in a gitignored
/// Secrets.plist in the app target. See Demo/README.md and Demo/Secrets.example.plist.
enum DemoEnvironment {
    static var authHeader: String? { value("SEGMENTIFY_AUTH_HEADER") }
    /// With an auth header and no explicit API key, no apiKey is sent.
    static var apiKey: String? { value("SEGMENTIFY_API_KEY") ?? (authHeader == nil ? "3c9e211a-d049-43d5-aa4a-f98b7e66e482" : nil) }
    static var dataCenterUrl: String { value("SEGMENTIFY_DATA_CENTER_URL") ?? "https://gandalf-qa.segmentify.com" }
    static var pushDataCenterUrl: String { value("SEGMENTIFY_PUSH_DATA_CENTER_URL") ?? "https://gimli-qa.segmentify.com" }
    static var subDomain: String { value("SEGMENTIFY_SUB_DOMAIN") ?? "demosfy.com" }

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
