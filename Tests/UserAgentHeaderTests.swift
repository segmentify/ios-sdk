import XCTest
@testable import Segmentify

/// SFY-28912: every request names the SDK, the operating system and the device
/// in the User-Agent header, in the format the backend parses.
final class UserAgentHeaderTests: XCTestCase {
    private let lock = NSLock()
    private var userAgents: [String: String?] = [:]

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.clearSessionDefaults()
        SegmentifyTestSupport.configureSegmentify()
        SegmentifyManager.sharedManager().testingClearNetworkSession()
    }

    override func tearDown() {
        waitUntil("the session request to finish") { SegmentifyManager.sharedManager().testingIsSessionRequestIdle }
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    // MARK: Format

    func testFormat() {
        let header = SegmentifyUserAgent.make(
            sdkVersion: "1.5.0", osVersion: "17.4", model: "iPhone14,2", appId: "com.acme.shop", appVersion: "2.3.1"
        )
        XCTAssertEqual(header, "SegmentifySDK/1.5.0 (ios; iOS 17.4; iPhone14,2) com.acme.shop/2.3.1")
    }

    func testPartsThatAreNotKnownAreLeftOut() {
        XCTAssertEqual(
            SegmentifyUserAgent.make(sdkVersion: "1.5.0", osVersion: "17.4", model: nil, appId: nil, appVersion: nil),
            "SegmentifySDK/1.5.0 (ios; iOS 17.4)"
        )
        XCTAssertEqual(
            SegmentifyUserAgent.make(sdkVersion: "1.5.0", osVersion: "17.4", model: "", appId: "com.acme.shop", appVersion: nil),
            "SegmentifySDK/1.5.0 (ios; iOS 17.4) com.acme.shop"
        )
        XCTAssertEqual(
            SegmentifyUserAgent.make(sdkVersion: "1.5.0", osVersion: "17.4", model: "iPhone14,2", appId: nil, appVersion: "2.3.1"),
            "SegmentifySDK/1.5.0 (ios; iOS 17.4; iPhone14,2)"
        )
    }

    /// gandalf needs a version after "iOS"; the Android and React Native SDKs
    /// send "unknown" when it is missing, and so must this one.
    func testMissingVersionsAreSentAsUnknown() {
        XCTAssertEqual(
            SegmentifyUserAgent.make(sdkVersion: "", osVersion: " ", model: nil, appId: nil, appVersion: nil),
            "SegmentifySDK/unknown (ios; iOS unknown)"
        )
    }

    /// Read without UIKit, so building the header off the main thread is safe.
    func testOperatingSystemVersionComesFromProcessInfo() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var expected = "\(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion > 0 {
            expected += ".\(version.patchVersion)"
        }
        XCTAssertEqual(SegmentifyUserAgent.operatingSystemVersion(), expected)
    }

    /// The backend splits on `;`, `(`, `)` and spaces, and a header must be ASCII.
    func testCharactersThatWouldBreakTheFormatAreRemoved() {
        let header = SegmentifyUserAgent.make(
            sdkVersion: "1.5.0 beta", osVersion: "17.4 (21E219)", model: "iPhone;14,2 Ayşe", appId: "com.acme/shop app", appVersion: "2.3.1 (45)"
        )
        XCTAssertEqual(header, "SegmentifySDK/1.5.0beta (ios; iOS 17.421E219; iPhone14,2 Aye) com.acmeshopapp/2.3.145")
        XCTAssertTrue(header.unicodeScalars.allSatisfy { $0.isASCII })
    }

    func testCurrentDescribesThisSdkAndDevice() {
        let pattern = "^SegmentifySDK/\(NSRegularExpression.escapedPattern(for: SDKVersion.value)) \\(ios; iOS [0-9.]+; [^;()]+\\)"
        XCTAssertNotNil(SegmentifyUserAgent.current.range(of: pattern, options: .regularExpression), SegmentifyUserAgent.current)
    }

    // MARK: Requests

    func testEventAndKeyRequestsCarryTheHeader() {
        MockURLProtocol.requestHandler = { [unowned self] request in
            let url = request.url?.absoluteString ?? ""
            let kind = url.contains("/get/key") ? "key" : (SegmentifyTestSupport.eventName(of: request) ?? "event")
            self.lock.lock()
            self.userAgents[kind] = request.value(forHTTPHeaderField: "User-Agent")
            self.lock.unlock()
            if url.contains("/get/key") {
                return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(["user-1", "session-1"]))
            }
            return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.emptyEventResponse())
        }

        var answered = false
        let page = SearchPageModel()
        page.query = "shoes"
        SegmentifyManager.sharedManager().sendSearchPageView(segmentifyObject: page) { _ in answered = true }
        waitUntil("the search callback") { answered }

        lock.lock()
        let seen = userAgents
        lock.unlock()
        XCTAssertEqual(seen["key"] ?? nil, SegmentifyUserAgent.current)
        XCTAssertEqual(seen["SEARCH"] ?? nil, SegmentifyUserAgent.current)
    }
}
