import XCTest
@testable import Segmentify

/// SFY-28777: whatever the event endpoint answers, the SDK must not trap and
/// must call the host app back exactly once.
final class RecommendationResponseHandlingTests: XCTestCase {
    private var manager: SegmentifyManager!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        super.tearDown()
    }

    /// Answers the event named `eventName` with `body`; every other event (the
    /// impressions the SDK sends on its own, late events of other tests) gets an
    /// empty recommendation response.
    private func serve(_ body: [String: Any], to eventName: String) {
        MockURLProtocol.requestHandler = SegmentifyTestSupport.routeRequests { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            if SegmentifyTestSupport.eventName(of: request) == eventName {
                return (response, try SegmentifyTestSupport.jsonData(body))
            }
            return (response, try SegmentifyTestSupport.jsonData(["responses": [[]]]))
        }
    }

    private func pageViewRecommendations() -> [RecommendationModel]? {
        let called = expectation(description: "recommendation callback")
        called.assertForOverFulfill = true
        var received: [RecommendationModel]?

        let page = PageModel()
        page.category = "Home Page"
        manager.sendPageView(segmentifyObject: page) { recommendations in
            received = recommendations
            called.fulfill()
        }

        wait(for: [called], timeout: 15)
        return received
    }

    private let source = "RECOMMENDATION_SOURCE_ALL_PRODUCTS|TIME_FRAME_THIS_WEEK|SCORE_VIEW"

    private func dynamicItems(itemCount: String) -> String {
        "[{\"recommendationSource\":\"RECOMMENDATION_SOURCE_ALL_PRODUCTS\",\"timeFrame\":\"TIME_FRAME_THIS_WEEK\"," +
            "\"score\":\"SCORE_VIEW\"\(itemCount)}]"
    }

    private func recommendation(dynamicItems: String) -> [String: Any] {
        [
            "type": "recommendProducts",
            "params": [
                "notificationTitle": "For you",
                "instanceId": "scn_1",
                "actionId": "act_1",
                "staticItems": "[]",
                "dynamicItems": dynamicItems,
                "recommendedProducts": [
                    source: [
                        ["productId": "p1", "name": "One"],
                        ["productId": "p2", "name": "Two"],
                        ["productId": "p3", "name": "Three"],
                    ],
                ],
            ] as [String: Any],
        ]
    }

    // Characterization: the shape that works today.

    func testRecommendationIsParsed() {
        serve(["responses": [[recommendation(dynamicItems: dynamicItems(itemCount: ",\"itemCount\":\"2\""))]]], to: "PAGE_VIEW")

        let recommendations = pageViewRecommendations()

        XCTAssertEqual(recommendations?.count, 1)
        XCTAssertEqual(recommendations?.first?.notificationTitle, "For you")
        XCTAssertEqual(recommendations?.first?.instanceId, "scn_1")
        XCTAssertEqual(recommendations?.first?.products?.map { $0.productId }, ["p1", "p2"])
    }

    // SFY-28777

    func testBodyWithoutResponsesAndWithoutStatusCodeCallsBackWithNothing() {
        serve(["search": [[]]], to: "PAGE_VIEW")

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    func testEmptyResponsesCallBackWithNothing() {
        serve(["responses": []], to: "PAGE_VIEW")

        XCTAssertEqual(pageViewRecommendations()?.count, 0)
    }

    func testItemOfAnotherTypeIsSkippedAndTheRecommendationIsKept() {
        let popup: [String: Any] = ["type": "showPopup", "params": ["html": "<div></div>"]]
        let valid = recommendation(dynamicItems: dynamicItems(itemCount: ",\"itemCount\":\"2\""))
        serve(["responses": [[popup, ["type": "recommendProducts"], valid]]], to: "PAGE_VIEW")

        let recommendations = pageViewRecommendations()

        XCTAssertEqual(recommendations?.count, 1)
        XCTAssertEqual(recommendations?.first?.products?.map { $0.productId }, ["p1", "p2"])
    }

    func testNumericItemCountIsAccepted() {
        serve(["responses": [[recommendation(dynamicItems: dynamicItems(itemCount: ",\"itemCount\":2"))]]], to: "PAGE_VIEW")

        XCTAssertEqual(pageViewRecommendations()?.first?.products?.map { $0.productId }, ["p1", "p2"])
    }

    func testMissingItemCountReturnsAllProducts() {
        serve(["responses": [[recommendation(dynamicItems: dynamicItems(itemCount: ""))]]], to: "PAGE_VIEW")

        XCTAssertEqual(pageViewRecommendations()?.first?.products?.map { $0.productId }, ["p1", "p2", "p3"])
    }

    func testSearchBodyWithoutSearchAndWithoutStatusCodeCallsBack() {
        serve(["responses": [[]]], to: "SEARCH")
        let called = expectation(description: "search callback")
        called.assertForOverFulfill = true

        manager.testingResetSearchResponses()
        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchEvent { _ in called.fulfill() }

        wait(for: [called], timeout: 15)
    }
}
