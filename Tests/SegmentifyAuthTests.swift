import XCTest
@testable import Segmentify

final class SegmentifyAuthTests: XCTestCase {

    func testRawTokenGetsBasicPrefix() {
        XCTAssertEqual(SegmentifyAuth.authorizationValue("abc"), "Basic abc")
        XCTAssertEqual(SegmentifyAuth.authorizationValue("  abc \n"), "Basic abc")
    }

    func testValueWithBasicSchemeIsKept() {
        XCTAssertEqual(SegmentifyAuth.authorizationValue("Basic abc"), "Basic abc")
        XCTAssertEqual(SegmentifyAuth.authorizationValue("basic abc"), "basic abc")
        XCTAssertEqual(SegmentifyAuth.authorizationValue("BASIC\tabc"), "BASIC\tabc")
    }

    /// Same rule as the web SDK: only a "Basic " prefix is kept, any other value gets one.
    func testNonBasicValueGetsBasicPrefix() {
        XCTAssertEqual(SegmentifyAuth.authorizationValue("Bearer abc"), "Basic Bearer abc")
        XCTAssertEqual(SegmentifyAuth.authorizationValue("Basicabc"), "Basic Basicabc")
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
