import XCTest
@testable import Segmentify

final class SearchFacetedEventTests: XCTestCase {
    private var manager: SegmentifyManager!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        manager.testingResetSearchResponses()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        super.tearDown()
    }

    func testFacetedSearchInvokesCallbackWhenSearchPayloadMissing() {
        let expectation = expectation(description: "callback on missing search payload")

        MockURLProtocol.requestHandler = { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.jsonData(["statusCode": 400])
            return (response, data)
        }

        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchFacetedEvent { response in
            XCTAssertNotNil(response)
            XCTAssertEqual(response.products?.count ?? 0, 0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testFacetedSearchInvokesCallbackWhenSearchPayloadEmpty() {
        let expectation = expectation(description: "callback on empty search payload")

        MockURLProtocol.requestHandler = { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.jsonData(["search": []])
            return (response, data)
        }

        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchFacetedEvent { response in
            XCTAssertNotNil(response)
            XCTAssertEqual(response.products?.count ?? 0, 0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testFacetedSearchInvokesCallbackWhenProductsFieldMissing() {
        let expectation = expectation(description: "callback on invalid faceted object")

        MockURLProtocol.requestHandler = { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.jsonData([
                "search": [
                    [
                        ["instanceId": "facet-1"],
                    ],
                ],
            ])
            return (response, data)
        }

        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchFacetedEvent { response in
            XCTAssertNotNil(response)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testFacetedSearchDecodesValidResponseWithoutChangingSearchEventName() {
        let expectation = expectation(description: "callback on valid faceted response")

        MockURLProtocol.requestHandler = { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.jsonData([
                "search": [[
                    [
                        "products": [
                            ["productId": "p1", "name": "Test Product"],
                        ],
                        "facets": [],
                        "instanceId": "facet-instance",
                    ],
                ]],
            ])
            return (response, data)
        }

        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchFacetedEvent { response in
            XCTAssertEqual(response.instanceId, "facet-instance")
            XCTAssertEqual(response.products?.count, 1)
            XCTAssertEqual(response.products?.first?.productId, "p1")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testFacetedSearchDecodesResponseWithEmptyProductsArray() {
        let expectation = expectation(description: "callback on zero-result faceted response")

        MockURLProtocol.requestHandler = { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.jsonData([
                "search": [[
                    [
                        "products": [],
                        "facets": [],
                        "instanceId": "facet-empty",
                    ],
                ]],
            ])
            return (response, data)
        }

        manager.testingConfigureFacetedSearch(query: "kitchen")
        manager.sendSearchFacetedEvent { response in
            XCTAssertEqual(response.instanceId, "facet-empty")
            XCTAssertEqual(response.products?.count, 0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testFacetedSearchRequestIncludesTypeWhenConfigured() throws {
        let manager = SegmentifyManager.sharedManager()
        manager.testingConfigureFacetedSearch(query: "kitchen", type: "faceted", lang: "EN")

        let body = try JSONSerialization.data(
            withJSONObject: manager.testingCurrentRequestDictionary(),
            options: []
        )
        let dictionary = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        XCTAssertEqual(dictionary?["name"] as? String, "SEARCH")
        XCTAssertEqual(dictionary?["query"] as? String, "kitchen")
        XCTAssertEqual(dictionary?["type"] as? String, "faceted")
    }

    func testInstantSearchStillInvokesCallbackWhenSearchPayloadMissing() {
        let expectation = expectation(description: "instant search callback")

        MockURLProtocol.requestHandler = { request in
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.jsonData(["statusCode": 400])
            return (response, data)
        }

        let search = SearchPageModel()
        search.query = "kitchen"
        search.lang = "EN"

        manager.testingConfigureFacetedSearch(query: search.query ?? "", lang: search.lang)
        manager.sendSearchEvent { response in
            XCTAssertNotNil(response)
            XCTAssertEqual(response.keywords.count, 0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }
}
