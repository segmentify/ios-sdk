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
        ""
    }

    static func apply(to request: inout URLRequest) {
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
