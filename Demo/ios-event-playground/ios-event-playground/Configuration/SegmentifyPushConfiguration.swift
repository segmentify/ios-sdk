import Foundation
import Segmentify

/// Segmentify + Firebase push settings from `Demo/native-push-app`.
enum SegmentifyPushConfiguration {
    static let apiKey: String? = nil
    static var authHeader: String? { segmentifyDemoAuthHeader() }
    static let dataCenterUrl = "https://push-notification-api.preprod.cloud.unifonic.com"
    static let pushDataCenterUrl = "https://push-notification-api.preprod.cloud.unifonic.com"
    static let subDomain = "push-sfy-web.int.oci.ruh.dev.unifonic.com"
    static let permissionInfoUserId = "2"

    static func apply() {
        SegmentifyManager.setConfig(
            apiKey: apiKey,
            dataCenterUrl: dataCenterUrl,
            subDomain: subDomain,
            authHeader: authHeader
        )
        SegmentifyManager.setPushConfig(dataCenterUrlPush: pushDataCenterUrl)
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
