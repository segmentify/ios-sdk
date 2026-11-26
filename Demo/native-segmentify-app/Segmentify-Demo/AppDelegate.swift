//
//  AppDelegate.swift
//  Segmentify-Demo

import UIKit
import Segmentify
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Segmentify QA by default; see DemoEnvironment to override (this project only reads
        // scheme environment variables, as Secrets.plist is not part of its target)
        DemoEnvironment.apply()
        // option to show or hide console log
        let _ = SegmentifyManager.logStatus(isVisible: true)
        let _ = SegmentifyManager.setSessionKeepSecond(sessionKeepSecond: 604800)
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("willresignactive")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("didenterbackground")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("willenterbackground")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("didbecomeactive")
    }
    
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // [START receive_message]
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        
        if(application.applicationState == UIApplication.State.inactive){
            print("inactive")
        }
        
        if(application.applicationState == UIApplication.State.active){
            print("active")
        }
        
        if(application.applicationState == UIApplication.State.background){

            let apns_instanceId = userInfo["instanceId"]
            let f_instanceId = userInfo["gcm.notification.instanceId"]
            var instanceId_  = ""
            
            if(apns_instanceId != nil){
                instanceId_ = apns_instanceId as! String
            }
            else if(f_instanceId != nil){
                instanceId_ = f_instanceId as! String
            }

            let obj = NotificationModel()
            obj.instanceId = instanceId_
            obj.params = ["price": "123", "productId": "13", "quantity": "132"]
            obj.type = NotificationType.VIEW
            
            SegmentifyManager.sharedManager().sendNotificationInteraction(segmentifyObject: obj)

        }
        // Print full message.
        print(userInfo)
    }
    

    // [START receive_message]
      func application(_ application: UIApplication,
                       didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                       fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                         -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // Print full message.
        print(userInfo)

        completionHandler(UIBackgroundFetchResult.newData)
      }

      // [END receive_message]
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        print("APNs token retrieved: \(deviceToken)")
        let   tokenString = deviceToken.reduce("", {$0 + String(format: "%02X",    $1)})
        print("deviceToken: \(tokenString)")
        // With swizzling disabled you must set the APNs token here.
        // Messaging.messaging().apnsToken = deviceToken
    }
}


// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print full message.
        print(userInfo)
        
        print(userInfo["gcm.notification.instanceId"])
        
        // Change this to your preferred presentation option
        completionHandler([])
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
// [END ios_10_message_handling]

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
