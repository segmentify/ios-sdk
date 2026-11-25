import XCTest
@testable import Segmentify

/// SFY-28783: the `version` file must stay reachable as a package resource,
/// otherwise every event reports `sdkVersion: "unknown"`.
final class SDKVersionTests: XCTestCase {
    func testVersionIsReadFromThePackagedVersionFile() {
        XCTAssertNotEqual(SDKVersion.value, "unknown")
        XCTAssertFalse(SDKVersion.value.isEmpty)
    }
}
