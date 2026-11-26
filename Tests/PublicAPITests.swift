import XCTest
// Not @testable: this file sees only what host apps see.
import Segmentify

/// SFY-28913: host apps can build a `SegmentifyError` in their own tests, as
/// they can build a `SegmentifyException` on Android.
final class PublicAPITests: XCTestCase {
    func testHostAppsCanCreateASegmentifyError() {
        let error = SegmentifyError(message: "offline", httpStatus: 503, statusCode: "NO_SESSIONID", underlyingError: URLError(.notConnectedToInternet))

        XCTAssertEqual(error.message, "offline")
        XCTAssertEqual(error.httpStatus, 503)
        XCTAssertEqual(error.httpStatusCode, 503)
        XCTAssertEqual(error.statusCode, "NO_SESSIONID")
        XCTAssertNotNil(error.underlyingError)
    }
}
