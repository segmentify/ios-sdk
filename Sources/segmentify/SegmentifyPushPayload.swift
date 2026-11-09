//
//  SegmentifyPushPayload.swift
//  Segmentify

import Foundation

public struct SegmentifyPushAction: Equatable {
    public let action: String
    public let title: String
    public let icon: String?
    public let redirectUrl: String?
    public let deeplink: String?

    public init(action: String, title: String = "", icon: String? = nil, redirectUrl: String? = nil, deeplink: String? = nil) {
        self.action = action
        self.title = title
        self.icon = icon
        self.redirectUrl = redirectUrl
        self.deeplink = deeplink
    }
}

public struct SegmentifyPushPayload: Equatable {
    public internal(set) var sgmVersion: String?
    public internal(set) var title: String
    public internal(set) var message: String
    public internal(set) var image: String?
    public internal(set) var redirectUrl: String?
    public internal(set) var deeplink: String?
    public internal(set) var tag: String?
    public internal(set) var instanceId: String?
    public internal(set) var apiKey: String?
    public internal(set) var dataCenterUrl: String?
    public internal(set) var userId: String?
    public internal(set) var actions: [SegmentifyPushAction]
    public internal(set) var providerType: ProviderType

    public var isV2: Bool {
        return sgmVersion != nil
    }

    public var targetUrl: String? {
        return deeplink ?? redirectUrl
    }

    public init(userInfo: [AnyHashable: Any]) {
        let alert = SegmentifyPushPayload.alert(from: userInfo["aps"])

        sgmVersion = SegmentifyPushPayload.string(userInfo["sgmVersion"])
        title = SegmentifyPushPayload.string(userInfo["title"]) ?? SegmentifyPushPayload.string(alert["title"]) ?? ""
        message = SegmentifyPushPayload.string(userInfo["message"]) ?? SegmentifyPushPayload.string(alert["body"]) ?? ""
        image = SegmentifyPushPayload.string(userInfo["image"])
        redirectUrl = SegmentifyPushPayload.string(userInfo["redirectUrl"])
        deeplink = SegmentifyPushPayload.string(userInfo["deeplink"])
        tag = SegmentifyPushPayload.string(userInfo["tag"])
        instanceId = SegmentifyPushPayload.string(userInfo["instanceId"])
        apiKey = SegmentifyPushPayload.string(userInfo["apiKey"])
        dataCenterUrl = SegmentifyPushPayload.string(userInfo["dataCenterUrl"])
        userId = SegmentifyPushPayload.string(userInfo["userId"])
        actions = SegmentifyPushPayload.actions(from: userInfo["actions"])
        providerType = userInfo["gcm.message_id"] != nil ? .FIREBASE : .APNS
    }

    private static func string(_ value: Any?) -> String? {
        let text: String?
        switch value {
        case let value as String:
            text = value
        case let value as NSNumber where CFGetTypeID(value) != CFBooleanGetTypeID():
            text = value.stringValue
        default:
            text = nil
        }
        guard let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private static func alert(from aps: Any?) -> [String: Any] {
        guard let aps = aps as? [String: Any] else {
            return [:]
        }
        if let body = aps["alert"] as? String {
            return ["body": body]
        }
        return aps["alert"] as? [String: Any] ?? [:]
    }

    private static func actions(from value: Any?) -> [SegmentifyPushAction] {
        var items: Any? = value
        if let json = value as? String {
            guard let data = json.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) else {
                return []
            }
            items = parsed
        }
        guard let list = items as? [Any] else {
            return []
        }
        return list.compactMap { item in
            guard let item = item as? [String: Any], let action = string(item["action"]) else {
                return nil
            }
            return SegmentifyPushAction(
                action: action,
                title: string(item["title"]) ?? "",
                icon: string(item["icon"]),
                redirectUrl: string(item["redirectUrl"]),
                deeplink: string(item["deeplink"])
            )
        }
    }
}
