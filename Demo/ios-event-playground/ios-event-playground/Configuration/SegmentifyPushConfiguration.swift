import Foundation
import Segmentify

/// Segmentify + Firebase push settings from `Demo/native-push-app`.
enum SegmentifyPushConfiguration {
    static let apiKey: String? = nil
    static let authHeader = "Basic ZTc5NmJlNGUtNjExNi00Y2Y4LTgyYjgtNDIxMGEzNjNkMWJlOlhtU09WbjJhMjNVOGhjV0xDNVlraDd3S0ZYblBpZUhx"
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
