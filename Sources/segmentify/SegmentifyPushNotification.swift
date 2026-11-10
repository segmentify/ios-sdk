//
//  SegmentifyPushNotification.swift
//  Segmentify

import Foundation
import UserNotifications
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// The payload model lives in SegmentifyPushPayload.swift.

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

        guard let imageUrlString = payload.image,
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
            let typeHint: String
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

            if #available(iOS 14.0, *) {
                switch ext {
                case ".png": typeHint = UTType.png.identifier
                case ".jpg", ".jpeg": typeHint = UTType.jpeg.identifier
                case ".gif": typeHint = UTType.gif.identifier
                default: typeHint = UTType.png.identifier
                }
            } else {
                switch ext {
                case ".png": typeHint = "public.png"
                case ".jpg", ".jpeg": typeHint = "public.jpeg"
                case ".gif": typeHint = "com.compuserve.gif"
                default: typeHint = "public.png"
                }
            }

            let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ext)

            do {
                try FileManager.default.moveItem(at: localUrl, to: tmpFile)
                let attachment = try UNNotificationAttachment(
                    identifier: "segmentify-image",
                    url: tmpFile,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: typeHint]
                )
                content.attachments = [attachment]
            } catch {
                print("Segmentify: Failed to attach notification image: \(error)")
            }
        }
        task.resume()
    }
}
