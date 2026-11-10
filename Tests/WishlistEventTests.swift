import XCTest
@testable import Segmentify

final class WishlistEventTests: XCTestCase {
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

    func testWishlistAddSendsProductIdWithAddStep() {
        let sentRequest = captureEvent {
            self.manager.sendWishlistAdd(productId: "p1")
        }

        XCTAssertEqual(sentRequest["name"] as? String, "WISHLIST")
        XCTAssertEqual(sentRequest["step"] as? String, "add")
        XCTAssertEqual(sentRequest["productId"] as? String, "p1")
    }

    func testWishlistRemoveSendsProductIdWithRemoveStep() {
        let sentRequest = captureEvent {
            self.manager.sendWishlistRemove(productId: "p1")
        }

        XCTAssertEqual(sentRequest["step"] as? String, "remove")
        XCTAssertEqual(sentRequest["productId"] as? String, "p1")
    }

    func testWishlistDetailSendsProductIdWithDetailStep() {
        let sentRequest = captureEvent {
            self.manager.sendWishlistDetail(productId: "p1")
        }

        XCTAssertEqual(sentRequest["step"] as? String, "detail")
        XCTAssertEqual(sentRequest["productId"] as? String, "p1")
    }

    func testWishlistViewFavoritesSendsFavoritesList() {
        let sentRequest = captureEvent {
            self.manager.sendWishlistViewFavorites(favoritesList: ["p1", "p2"])
        }

        XCTAssertEqual(sentRequest["name"] as? String, "WISHLIST")
        XCTAssertEqual(sentRequest["step"] as? String, "view-favorites")
        XCTAssertEqual(sentRequest["favoritesList"] as? [String], ["p1", "p2"])
    }

    func testWishlistAddWithoutProductIdIsNotSent() {
        let model = WishlistModel()
        model.step = "add"

        assertNoEventSent {
            self.manager.sendWishlist(segmentifyObject: model)
        }
    }

    func testWishlistDetailWithEmptyProductIdIsNotSent() {
        let model = WishlistModel()
        model.step = "detail"
        model.productId = ""

        assertNoEventSent {
            self.manager.sendWishlist(segmentifyObject: model)
        }
    }

    func testWishlistViewFavoritesWithoutFavoritesListIsNotSent() {
        let model = WishlistModel()
        model.step = "view-favorites"

        assertNoEventSent {
            self.manager.sendWishlist(segmentifyObject: model)
        }
    }

    func testWishlistWithUnknownStepIsNotSent() {
        let model = WishlistModel()
        model.step = "favorite"
        model.productId = "p1"

        assertNoEventSent {
            self.manager.sendWishlist(segmentifyObject: model)
        }
    }

    private func captureEvent(_ send: @escaping () -> Void) -> [AnyHashable: Any] {
        let eventSent = expectation(description: "wishlist event dispatched")
        var sentRequest: [AnyHashable: Any] = [:]

        MockURLProtocol.requestHandler = stubAllRequests(onEvent: {
            sentRequest = self.manager.testingCurrentRequestDictionary()
            eventSent.fulfill()
        })

        send()

        wait(for: [eventSent], timeout: 3)
        return sentRequest
    }

    private func assertNoEventSent(_ send: @escaping () -> Void) {
        let eventSent = expectation(description: "no wishlist event dispatched")
        eventSent.isInverted = true

        MockURLProtocol.requestHandler = stubAllRequests(onEvent: {
            eventSent.fulfill()
        })

        send()

        wait(for: [eventSent], timeout: 1)
    }

    private func stubAllRequests(onEvent: @escaping () -> Void) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let path = request.url?.absoluteString ?? ""
            if path.contains("/add/events/") {
                onEvent()
            }
            let response = SegmentifyTestSupport.httpResponse(for: request)
            let data = try SegmentifyTestSupport.emptyEventResponse()
            return (response, data)
        }
    }
}
