import XCTest
@testable import Segmentify

/// SFY-28773: instant search responses carrying grouped products or lookup maps
/// must be parsed, and unexpected value types must be skipped, never trapped on.
final class SearchResponseParsingTests: XCTestCase {
    private var manager: SegmentifyManager!
    private let lock = NSLock()
    private var eventRequestCount = 0

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        manager.testingResetSearchResponses()
        eventRequestCount = 0
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        super.tearDown()
    }

    /// The first event request is the search itself; the impression and widget-view
    /// events the SDK sends afterwards get an empty recommendation response.
    private func serveSearchResponse(_ searchObject: [String: Any]) {
        MockURLProtocol.requestHandler = SegmentifyTestSupport.routeRequests { [unowned self] request in
            self.lock.lock()
            self.eventRequestCount += 1
            let isSearchRequest = self.eventRequestCount == 1
            self.lock.unlock()

            let response = SegmentifyTestSupport.httpResponse(for: request)
            if isSearchRequest {
                return (response, try SegmentifyTestSupport.jsonData(["search": [[searchObject]]]))
            }
            return (response, try SegmentifyTestSupport.emptyEventResponse())
        }
    }

    private func runSearch() -> SearchModel? {
        let expectation = expectation(description: "search callback")
        var received: SearchModel?

        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchEvent { response in
            received = response
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3)
        return received
    }

    private let campaign: [String: Any] = [
        "instanceId": "scn_search",
        "name": "Searchbox",
        "stringSearchAssetTextMap": [
            "EN": [
                "popularProductsText": "Popular",
                "mobileCancelText": "Cancel",
                "notFoundText": "Nothing found",
            ],
        ],
    ]

    func testGroupedProductsAndLookupMapsAreParsed() {
        serveSearchResponse([
            "products": [["productId": "p1", "name": "Pan"]],
            "campaign": campaign,
            "categoryProducts": ["Kitchen": [["productId": "c1", "name": "Pot", "price": 12.5] as [String: Any]]],
            "brandProducts": ["Acme": [["productId": "b1"], ["productId": "b2"]]],
            "keywords": ["kitchen knife": [["productId": "k1"]]],
            "categories": ["Kitchen": "Home > Kitchen"],
            "brands": ["Acme": "acme"],
            "lastSearches": ["pan"],
        ])

        let response = runSearch()

        XCTAssertEqual(response?.products?.map { $0.productId }, ["p1"])
        XCTAssertEqual(response?.categoryProducts["Kitchen"]?.map { $0.productId }, ["c1"])
        XCTAssertEqual(response?.categoryProducts["Kitchen"]?.first?.name, "Pot")
        XCTAssertEqual(response?.categoryProducts["Kitchen"]?.first?.price, 12.5)
        XCTAssertEqual(response?.brandProducts["Acme"]?.map { $0.productId }, ["b1", "b2"])
        XCTAssertEqual(response?.keywords["kitchen knife"]?.map { $0.productId }, ["k1"])
        XCTAssertEqual(response?.categories, ["Kitchen": "Home > Kitchen"])
        XCTAssertEqual(response?.brands, ["Acme": "acme"])
        XCTAssertEqual(response?.lastSearches, ["pan"])
        XCTAssertEqual(response?.campaign?.instanceId, "scn_search")
        XCTAssertEqual(response?.campaign?.stringSearchAssetTextMap["EN"]?.notFoundText, "Nothing found")
    }

    func testUnexpectedValueTypesAreSkippedWithoutCrashing() {
        serveSearchResponse([
            "products": [["productId": "p1"]],
            "campaign": [
                "instanceId": "scn_search",
                "stringSearchAssetTextMap": [
                    "EN": ["popularProductsText": 3, "notFoundText": "Nothing found"] as [String: Any],
                    "TR": "not an object",
                ] as [String: Any],
            ] as [String: Any],
            "categoryProducts": ["Kitchen": "not a list", "Garden": [["productId": "g1"]]] as [String: Any],
            "brandProducts": ["Acme": 7],
            "keywords": ["knife": [["productId": "k1"]], "pot": NSNull()] as [String: Any],
            "categories": ["Kitchen": 5, "Garden": "Home > Garden"] as [String: Any],
            "brands": ["Acme": ["nested"], "Zen": "zen"] as [String: Any],
        ])

        let response = runSearch()

        XCTAssertEqual(response?.products?.map { $0.productId }, ["p1"])
        XCTAssertEqual(response?.categoryProducts.keys.sorted(), ["Garden"])
        XCTAssertEqual(response?.brandProducts.count, 0)
        XCTAssertEqual(response?.keywords.keys.sorted(), ["knife"])
        XCTAssertEqual(response?.categories, ["Garden": "Home > Garden"])
        XCTAssertEqual(response?.brands, ["Zen": "zen"])
        XCTAssertEqual(response?.campaign?.instanceId, "scn_search")
        XCTAssertEqual(response?.campaign?.stringSearchAssetTextMap.keys.sorted(), ["EN"])
        XCTAssertEqual(response?.campaign?.stringSearchAssetTextMap["EN"]?.notFoundText, "Nothing found")
    }
}
