//
//  SegmentifyPushNotification.swift
//  Segmentify

import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Segmentify Push Payload

/// A model representing a parsed Segmentify push notification payload.
public struct SegmentifyPushPayload {
    public let title: String?
    public let body: String?
    public let imageUrl: String?
    public let iconUrl: String?
    public let deeplink: String?
    public let redirectUrl: String?
    public let instanceId: String?
    public let apiKey: String?
    public let dataCenterUrl: String?

    /// Returns the effective link URL: prefers `deeplink`, falls back to `redirectUrl`.
    public var effectiveLink: URL? {
        if let deeplink = deeplink, let url = URL(string: deeplink) {
            return url
        }
        if let redirectUrl = redirectUrl, let url = URL(string: redirectUrl) {
            return url
        }
        return nil
    }

    /// Whether this notification originated from Segmentify (has instanceId or apiKey).
    public var isSegmentifyNotification: Bool {
        return instanceId != nil || apiKey != nil
    }

    public init(userInfo: [AnyHashable: Any]) {
        self.title = userInfo["title"] as? String
        self.imageUrl = userInfo["image"] as? String
        self.iconUrl = userInfo["icon"] as? String
        self.deeplink = userInfo["deeplink"] as? String
        self.redirectUrl = userInfo["redirectUrl"] as? String
        self.instanceId = userInfo["instanceId"] as? String
        self.apiKey = userInfo["apiKey"] as? String
        self.dataCenterUrl = userInfo["dataCenterUrl"] as? String

        // Body from top-level "message" field
        if let message = userInfo["message"] as? String {
            self.body = message
        } else if let aps = userInfo["aps"] as? [String: Any],
                  let alert = aps["alert"] as? [String: Any] {
            self.body = alert["body"] as? String
        } else {
            self.body = nil
        }
    }
}

// MARK: - Segmentify Push Notification Handler

/// Handles Segmentify push notification image attachment and deeplink navigation.
public class SegmentifyPushNotificationHandler {

    public init() {}

    /// Call from your `UNNotificationServiceExtension`'s `didReceive(_:withContentHandler:)`
    /// to automatically download and attach the image from the Segmentify push payload.
    public static func handleNotificationServiceExtension(
        request: UNNotificationRequest,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo
        let payload = SegmentifyPushPayload(userInfo: userInfo)

        guard let imageUrlString = payload.imageUrl,
              let imageUrl = URL(string: imageUrlString) else {
            contentHandler(bestAttemptContent)
            return
        }

        Self.downloadAndAttachImage(url: imageUrl, to: bestAttemptContent) { content in
            contentHandler(content)
        }
    }

    /// Returns the parsed Segmentify push payload from a notification's userInfo.
    public static func parsePayload(userInfo: [AnyHashable: Any]) -> SegmentifyPushPayload {
        return SegmentifyPushPayload(userInfo: userInfo)
    }

    /// Returns the deeplink/redirect URL from a push notification's userInfo.
    public static func getDeeplinkUrl(userInfo: [AnyHashable: Any]) -> URL? {
        let payload = SegmentifyPushPayload(userInfo: userInfo)
        return payload.effectiveLink
    }

    // MARK: - Private Helpers

    private static func downloadAndAttachImage(
        url: URL,
        to content: UNMutableNotificationContent,
        completion: @escaping (UNMutableNotificationContent) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localUrl, response, error in
            defer { completion(content) }

            guard let localUrl = localUrl, error == nil else { return }

            let pathExt = url.pathExtension.lowercased()
            let ext: String
            if ["png", "jpg", "jpeg", "gif"].contains(pathExt) {
                ext = "." + pathExt
            } else if let mimeType = response?.mimeType?.lowercased() {
                if mimeType.contains("png") { ext = ".png" }
                else if mimeType.contains("jpeg") || mimeType.contains("jpg") { ext = ".jpg" }
                else if mimeType.contains("gif") { ext = ".gif" }
                else { ext = ".png" }
            } else {
                ext = ".png"
            }

            let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ext)

            do {
                try FileManager.default.moveItem(at: localUrl, to: tmpFile)
                let attachment = try UNNotificationAttachment(
                    identifier: "segmentify-image",
                    url: tmpFile,
                    options: nil
                )
                content.attachments = [attachment]
            } catch {
                print("Segmentify: Failed to attach notification image: \(error)")
            }
        }
        task.resume()
    }
}
