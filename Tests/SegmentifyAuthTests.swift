import XCTest
@testable import Segmentify

final class SegmentifyAuthTests: XCTestCase {

    /// The configured value is sent as is: no "Basic " prefix is added.
    func testValueIsSentAsIs() {
        XCTAssertEqual(SegmentifyAuth.authorizationValue("Basic abc"), "Basic abc")
        XCTAssertEqual(SegmentifyAuth.authorizationValue("abc"), "abc")
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(SegmentifyAuth.authorizationValue("  Basic abc \n"), "Basic abc")
    }

    func testBlankAuthHeaderIsNil() {
        XCTAssertNil(SegmentifyAuth.authorizationValue(nil))
        XCTAssertNil(SegmentifyAuth.authorizationValue(""))
        XCTAssertNil(SegmentifyAuth.authorizationValue("   "))
    }

    func testUrlWithAuthorizationHasNoApiKey() {
        let url = SegmentifyAuth.url("https://host.test/native/interaction/notification",
                                     apiKey: "key", authorization: "Basic abc")
        XCTAssertEqual(url?.absoluteString, "https://host.test/native/interaction/notification")
    }

    func testUrlWithoutAuthorizationAddsApiKey() {
        let url = SegmentifyAuth.url("https://host.test/add/events/v1.json",
                                     apiKey: "key", authorization: nil)
        XCTAssertEqual(url?.absoluteString, "https://host.test/add/events/v1.json?apiKey=key")
    }

    func testApiKeyIsAppendedToExistingQuery() {
        let url = SegmentifyAuth.url("https://host.test/get/key?count=2", apiKey: "key", authorization: nil)
        XCTAssertEqual(url?.absoluteString, "https://host.test/get/key?count=2&apiKey=key")
    }

    func testNoApiKeyAndNoAuthorizationLeavesUrlUnchanged() {
        let url = SegmentifyAuth.url("https://host.test/add/events/v1.json", apiKey: nil, authorization: nil)
        XCTAssertEqual(url?.absoluteString, "https://host.test/add/events/v1.json")
    }
}
