//
//  SegmentifyUserAgent.swift
//  Segmentify

import Foundation
import UIKit

/// The `User-Agent` header of every request the SDK sends:
///
///     SegmentifySDK/<sdkVersion> (ios; iOS <osVersion>; <model>) <appId>/<appVersion>
///
/// The backend reads the device and operating system from it (SFY-28912), so the
/// format is a contract shared with the Android and React Native SDKs.
enum SegmentifyUserAgent {
    static let headerName = "User-Agent"

    /// The header for this app on this device. Built once.
    static let current: String = make(
        sdkVersion: SDKVersion.value,
        osVersion: UIDevice.current.systemVersion,
        model: hardwareModel(),
        appId: Bundle.main.bundleIdentifier,
        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    )

    static func make(sdkVersion: String, osVersion: String, model: String?, appId: String?, appVersion: String?) -> String {
        var device = "ios; iOS \(token(osVersion))"
        if let model = model.map(text), !model.isEmpty {
            device += "; \(model)"
        }
        var header = "SegmentifySDK/\(token(sdkVersion)) (\(device))"

        if let appId = appId.map(token), !appId.isEmpty {
            header += " \(appId)"
            if let appVersion = appVersion.map(token), !appVersion.isEmpty {
                header += "/\(appVersion)"
            }
        }
        return header
    }

    static func apply(to request: inout URLRequest) {
        request.setValue(current, forHTTPHeaderField: headerName)
    }

    /// Printable ASCII without the characters that delimit the parts of the header.
    private static func text(_ value: String) -> String {
        let kept = value.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 && scalar.value < 0x7F && !";()".unicodeScalars.contains(scalar)
        }
        return String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespaces)
    }

    /// `text` without spaces and slashes, for the parts that are a single token.
    private static func token(_ value: String) -> String {
        text(value).filter { $0 != " " && $0 != "/" }
    }

    /// The operating system version, for example `17.4` or `17.4.1`.
    static func operatingSystemVersion() -> String {
        ""
    }

    /// The hardware identifier, for example `iPhone14,2`.
    static func hardwareModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return Mirror(reflecting: systemInfo.machine).children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
