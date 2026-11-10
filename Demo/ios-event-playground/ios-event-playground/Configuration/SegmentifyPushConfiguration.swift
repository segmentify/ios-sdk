import Foundation
import Segmentify

/// Segmentify + Firebase push settings from `Demo/native-push-app`.
enum SegmentifyPushConfiguration {
    static let permissionInfoUserId = "2"

    static func apply() {
        DemoEnvironment.apply()
    }
}

/// Backend settings for this demo. The defaults are Segmentify QA. To run against another
/// environment (e.g. Unifonic), override any value without editing code, either as an
/// environment variable in the scheme (Edit Scheme > Run > Arguments) or in a gitignored
/// Secrets.plist in the app target. See Demo/README.md and Demo/Secrets.example.plist.
enum DemoEnvironment {
    static var authHeader: String? { value("SEGMENTIFY_AUTH_HEADER") }
    /// With an auth header and no explicit API key, no apiKey is sent.
    static var apiKey: String? { value("SEGMENTIFY_API_KEY") ?? (authHeader == nil ? "5c571072-068e-40c5-8dbc-d8448158de19" : nil) }
    static var dataCenterUrl: String { value("SEGMENTIFY_DATA_CENTER_URL") ?? "https://gandalf-qa.segmentify.com" }
    static var pushDataCenterUrl: String { value("SEGMENTIFY_PUSH_DATA_CENTER_URL") ?? "https://gimli-qa.segmentify.com" }
    static var subDomain: String { value("SEGMENTIFY_SUB_DOMAIN") ?? "demo.segmentify.com" }

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
