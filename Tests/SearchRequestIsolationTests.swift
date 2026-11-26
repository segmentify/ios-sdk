import XCTest
@testable import Segmentify

/// SFY-28778: a search must send the query it was asked for and answer with its
/// own result, also when it had to wait for a session or the request failed.
final class SearchRequestIsolationTests: XCTestCase {
    private var manager: SegmentifyManager!
    private let lock = NSLock()
    private var searchQueries: [String] = []
    private var failSearches = false

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.clearSessionDefaults()
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        manager.testingClearNetworkSession()
        manager.testingResetSearchResponses()
        searchQueries = []
        failSearches = false
        serve()
    }

    override func tearDown() {
        waitUntil("the session request to finish") { self.manager.testingIsSessionRequestIdle }
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    /// Issues a session, and answers every search with one product and a
    /// campaign named after the query it carried.
    private func serve() {
        MockURLProtocol.requestHandler = { [unowned self] request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("/get/key") {
                return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(["user-1", "session-1"]))
            }
            guard SegmentifyTestSupport.eventName(of: request) == "SEARCH" else {
                return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.emptyEventResponse())
            }
            let query = SegmentifyTestSupport.requestBody(of: request)?["query"] as? String ?? ""
            self.lock.lock()
            self.searchQueries.append(query)
            let fail = self.failSearches
            self.lock.unlock()
            if fail {
                return (SegmentifyTestSupport.httpResponse(for: request, statusCode: 500), Data())
            }
            let item: [String: Any] = [
                "products": [["productId": query, "name": query] as [String: Any]],
                "campaign": ["instanceId": "scn_\(query)", "name": "Searchbox"] as [String: Any],
            ]
            return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(["search": [[item]]] as [String: Any]))
        }
    }

    private func sentQueries() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return searchQueries
    }

    private func page(_ query: String) -> SearchPageModel {
        let page = SearchPageModel()
        page.query = query
        return page
    }

    private func facetedPage(_ query: String) -> SearchFacetPageModel {
        let page = SearchFacetPageModel()
        page.query = query
        return page
    }

    func testTwoSearchesWaitingForASessionEachSendTheirOwnQuery() {
        var results: [String: SearchModel] = [:]

        manager.sendSearchPageView(segmentifyObject: page("shoes")) { results["shoes"] = $0 }
        manager.sendSearchPageView(segmentifyObject: page("bags")) { results["bags"] = $0 }

        waitUntil("both search callbacks") { results.count == 2 }
        XCTAssertEqual(sentQueries().sorted(), ["bags", "shoes"])
        XCTAssertEqual(results["shoes"]?.campaign?.instanceId, "scn_shoes")
        XCTAssertEqual(results["bags"]?.campaign?.instanceId, "scn_bags")
    }

    func testTwoFacetedSearchesWaitingForASessionEachSendTheirOwnQuery() {
        var answered = 0

        manager.sendFacetedSearchPageView(segmentifyObject: facetedPage("shoes")) { _ in answered += 1 }
        manager.sendFacetedSearchPageView(segmentifyObject: facetedPage("bags")) { _ in answered += 1 }

        waitUntil("both faceted search callbacks") { answered == 2 }
        XCTAssertEqual(sentQueries().sorted(), ["bags", "shoes"])
    }

    func testFailedSearchDoesNotAnswerWithThePreviousResult() {
        var first: SearchModel?
        manager.sendSearchPageView(segmentifyObject: page("shoes")) { first = $0 }
        waitUntil("the first search callback") { first != nil }
        XCTAssertEqual(first?.products?.count, 1)

        lock.lock()
        failSearches = true
        lock.unlock()

        var second: SearchModel?
        manager.sendSearchPageView(segmentifyObject: page("bags")) { second = $0 }
        waitUntil("the second search callback") { second != nil }

        XCTAssertEqual(second?.products?.count ?? 0, 0)
        XCTAssertNil(second?.campaign)
        XCTAssertEqual(second?.errorString, "error")
        XCTAssertEqual(first?.products?.count, 1, "the result already handed to the host app must not change")
    }

    func testEachSearchAnswersWithItsOwnResultObject() {
        var first: SearchModel?
        manager.sendSearchPageView(segmentifyObject: page("shoes")) { first = $0 }
        waitUntil("the first search callback") { first != nil }

        var second: SearchModel?
        manager.sendSearchPageView(segmentifyObject: page("bags")) { second = $0 }
        waitUntil("the second search callback") { second != nil }

        XCTAssertFalse(first === second)
        XCTAssertEqual(first?.campaign?.instanceId, "scn_shoes")
        XCTAssertEqual(second?.campaign?.instanceId, "scn_bags")
    }
}
