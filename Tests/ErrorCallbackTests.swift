import XCTest
@testable import Segmentify

/// SFY-28913: the `onError` variants report a failure instead of answering with
/// an empty result, and call exactly one of the two closures.
final class ErrorCallbackTests: XCTestCase {
    private var manager: SegmentifyManager!
    private let lock = NSLock()
    private var eventsSent = 0

    /// What the server answers events with.
    private var eventAnswer: (status: Int, body: [String: Any])?
    private var eventTransportError: URLError?
    private var keyStatus = 200

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.clearSessionDefaults()
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        manager.testingClearNetworkSession()
        manager.testingResetSearchResponses()
        SegmentifyManager.sessionRetryDelays = [0.01, 0.01]
        eventsSent = 0
        eventAnswer = nil
        eventTransportError = nil
        keyStatus = 200
        serve()
    }

    override func tearDown() {
        waitUntil("the session request to finish") { self.manager.testingIsSessionRequestIdle }
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyManager.sessionRetryDelays = SegmentifyManager.defaultSessionRetryDelays
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    /// The event under test gets `eventAnswer`; the
    /// impressions the SDK sends on its own get an empty response.
    private func serve() {
        MockURLProtocol.requestHandler = { [unowned self] request in
            let url = request.url?.absoluteString ?? ""
            self.lock.lock()
            let keyStatus = self.keyStatus
            let answer = self.eventAnswer
            let transportError = self.eventTransportError
            self.lock.unlock()

            if url.contains("/get/key") {
                let keys = keyStatus == 200 ? ["user-1", "session-1"] : []
                return (SegmentifyTestSupport.httpResponse(for: request, statusCode: keyStatus), try SegmentifyTestSupport.jsonData(keys))
            }
            let name = SegmentifyTestSupport.eventName(of: request)
            // Impressions and widget views the SDK sends on its own are INTERACTION events.
            guard name != nil, name != "INTERACTION" else {
                return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.emptyEventResponse())
            }
            self.lock.lock()
            self.eventsSent += 1
            self.lock.unlock()
            if let transportError = transportError {
                throw transportError
            }
            let status = answer?.status ?? 200
            let body: [String: Any] = answer?.body ?? ["statusCode": "SUCCESS", "responses": [[]] as [[Any]]]
            return (SegmentifyTestSupport.httpResponse(for: request, statusCode: status), try SegmentifyTestSupport.jsonData(body))
        }
    }

    private func answerEvents(status: Int = 200, body: [String: Any] = [:]) {
        lock.lock()
        eventAnswer = (status, body)
        lock.unlock()
    }

    private func sent() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return eventsSent
    }

    private struct Outcome {
        var answers = 0
        var errors: [SegmentifyError] = []
        var total: Int { answers + errors.count }
    }

    /// Sends a page view through the `onError` variant and waits for an answer.
    private func pageViewOutcome(category: String? = "Home Page") -> Outcome {
        var outcome = Outcome()
        let page = PageModel()
        page.category = category
        manager.sendPageView(segmentifyObject: page, callback: { _ in outcome.answers += 1 }, onError: { outcome.errors.append($0) })
        waitUntil("an answer to the page view") { outcome.total > 0 }
        settle()
        return outcome
    }

    /// Gives a second, unwanted callback the chance to arrive.
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    // MARK: Recommendation events

    func testSuccessCallsOnlyTheCallback() {
        let outcome = pageViewOutcome()

        XCTAssertEqual(outcome.answers, 1)
        XCTAssertTrue(outcome.errors.isEmpty)
    }

    func testHttpErrorCallsOnlyOnErrorWithTheStatus() {
        answerEvents(status: 500)

        let outcome = pageViewOutcome()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(outcome.errors.first?.httpStatus, 500)
        XCTAssertNil(outcome.errors.first?.statusCode)
    }

    func testRefusalByTheBackendCarriesItsStatusCode() {
        answerEvents(status: 200, body: ["statusCode": "INVALID_EVENT"])

        let outcome = pageViewOutcome()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(outcome.errors.first?.statusCode, "INVALID_EVENT")
        XCTAssertNil(outcome.errors.first?.httpStatus)
    }

    func testTransportErrorCarriesTheUnderlyingError() {
        lock.lock()
        eventTransportError = URLError(.notConnectedToInternet)
        lock.unlock()

        let outcome = pageViewOutcome()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertNotNil(outcome.errors.first?.underlyingError)
        XCTAssertNil(outcome.errors.first?.httpStatus)
    }

    func testNoSessionCallsOnlyOnErrorAndSendsNothing() {
        lock.lock()
        keyStatus = 500
        lock.unlock()

        let outcome = pageViewOutcome()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(sent(), 0)
    }

    func testCallRejectedBeforeSendingCallsOnError() {
        let outcome = pageViewOutcome(category: nil)

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(sent(), 0)
    }

    /// The second call runs with a session, the first without: both paths.
    func testErrorIsReportedWithAndWithoutAnExistingSession() {
        XCTAssertEqual(pageViewOutcome().answers, 1)
        answerEvents(status: 503)

        let outcome = pageViewOutcome()

        XCTAssertEqual(outcome.errors.first?.httpStatus, 503)
        XCTAssertEqual(outcome.answers, 0)
    }

    /// An error handler belongs to its own call only.
    func testCallbackOnlyMethodStillAnswersFailuresWithAnEmptyResult() {
        answerEvents(status: 500)
        var first = Outcome()
        let page = PageModel()
        page.category = "Home Page"
        manager.sendPageView(segmentifyObject: page, callback: { _ in first.answers += 1 }, onError: { first.errors.append($0) })

        var legacy: [RecommendationModel]?
        manager.sendPageView(segmentifyObject: page) { legacy = $0 }

        waitUntil("both answers") { first.total > 0 && legacy != nil }
        settle()
        XCTAssertEqual(legacy?.count, 0)
        XCTAssertEqual(first.errors.count, 1)
        XCTAssertEqual(first.answers, 0)
    }

    // MARK: Checkout steps that used to drop their callback

    private func checkout() -> CheckoutModel {
        let checkout = CheckoutModel()
        checkout.totalPrice = 10
        checkout.productList = [["productId": "p1", "price": 10, "quantity": 1] as [String: Any]]
        return checkout
    }

    /// Before SFY-28913 these two methods took a callback and never called it.
    func testPaymentAndCustomerInformationAnswerTheirCallback() {
        var payment: [RecommendationModel]?
        manager.sendPaymentInformation(segmentifyObject: checkout()) { payment = $0 }
        waitUntil("the payment information callback") { payment != nil }

        var customer: [RecommendationModel]?
        manager.sendCustomerInformation(segmentifyObject: checkout()) { customer = $0 }
        waitUntil("the customer information callback") { customer != nil }
    }

    func testFailedPaymentAndCustomerInformationCallOnlyOnError() {
        answerEvents(status: 500)

        var payment = Outcome()
        manager.sendPaymentInformation(segmentifyObject: checkout(), callback: { _ in payment.answers += 1 }, onError: { payment.errors.append($0) })
        waitUntil("an answer to payment information") { payment.total > 0 }

        var customer = Outcome()
        manager.sendCustomerInformation(segmentifyObject: checkout(), callback: { _ in customer.answers += 1 }, onError: { customer.errors.append($0) })
        waitUntil("an answer to customer information") { customer.total > 0 }
        settle()

        XCTAssertEqual(payment.answers, 0)
        XCTAssertEqual(payment.errors.count, 1)
        XCTAssertEqual(payment.errors.first?.httpStatus, 500)
        XCTAssertEqual(customer.answers, 0)
        XCTAssertEqual(customer.errors.count, 1)
        XCTAssertEqual(customer.errors.first?.httpStatus, 500)
    }

    // MARK: Every variant

    private func product() -> ProductModel {
        let product = ProductModel()
        product.productId = "p1"
        product.title = "Shoe"
        product.url = "https://shop.test/p1"
        product.image = "https://shop.test/p1.jpg"
        product.category = "Shoes"
        product.price = 10
        return product
    }

    private func customEvent() -> CustomEventModel {
        let event = CustomEventModel()
        event.type = "video-watched"
        return event
    }

    /// The variants not covered above, with an HTTP error: each calls only onError.
    func testEveryRecommendationVariantReportsAFailure() {
        answerEvents(status: 500)
        let calls: [(String, (@escaping ([RecommendationModel]) -> Void, @escaping (SegmentifyError) -> Void) -> Void)] = [
            ("sendProductView", { self.manager.sendProductView(segmentifyObject: self.product(), callback: $0, onError: $1) }),
            ("sendCustomEvent", { self.manager.sendCustomEvent(segmentifyObject: self.customEvent(), callback: $0, onError: $1) }),
            ("sendViewBasket", { self.manager.sendViewBasket(segmentifyObject: self.checkout(), callback: $0, onError: $1) }),
            ("sendPurchase", { self.manager.sendPurchase(segmentifyObject: self.checkout(), callback: $0, onError: $1) }),
        ]

        for (name, call) in calls {
            var outcome = Outcome()
            call({ _ in outcome.answers += 1 }, { outcome.errors.append($0) })
            waitUntil("an answer to \(name)") { outcome.total > 0 }
            settle()
            XCTAssertEqual(outcome.answers, 0, name)
            XCTAssertEqual(outcome.errors.count, 1, name)
            XCTAssertEqual(outcome.errors.first?.httpStatus, 500, name)
        }
    }

    // MARK: Threads

    /// The handler waits for the call it was given to, on that call's thread. A
    /// call made on another thread in the meantime must not take or clear it.
    func testErrorHandlerBelongsToTheThreadThatMadeTheCall() {
        let inSend = DispatchSemaphore(value: 0)
        let proceed = DispatchSemaphore(value: 0)
        let finished = expectation(description: "background call finished")
        var takenOnBackground = false
        var backgroundErrors = 0

        DispatchQueue.global().async {
            self.manager.reportingErrors(to: { _ in backgroundErrors += 1 }) {
                inSend.signal()
                proceed.wait()
                takenOnBackground = self.manager.takeErrorHandler() != nil
            }
            finished.fulfill()
        }
        inSend.wait()

        var mainErrors = 0
        manager.reportingErrors(to: { _ in mainErrors += 1 }) {}
        proceed.signal()

        wait(for: [finished], timeout: 5)
        waitUntil("the main thread call to report") { mainErrors == 1 }
        settle()
        XCTAssertTrue(takenOnBackground, "the background call lost its handler")
        XCTAssertEqual(backgroundErrors, 0, "a call that got as far as sending was reported as not sent")
        XCTAssertEqual(mainErrors, 1)
    }

    // MARK: Search

    func testFailedSearchCallsOnlyOnError() {
        answerEvents(status: 500)
        var outcome = Outcome()
        let page = SearchPageModel()
        page.query = "shoes"

        manager.sendSearchPageView(segmentifyObject: page, callback: { _ in outcome.answers += 1 }, onError: { outcome.errors.append($0) })
        waitUntil("an answer to the search") { outcome.total > 0 }
        settle()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.first?.httpStatus, 500)
    }

    func testSuccessfulSearchCallsOnlyTheCallback() {
        answerEvents(body: ["statusCode": "SUCCESS", "search": [[["products": [[String: Any]](), "campaign": ["instanceId": "scn_1"]] as [String: Any]]]])
        var outcome = Outcome()
        let page = SearchPageModel()
        page.query = "shoes"

        manager.sendSearchPageView(segmentifyObject: page, callback: { _ in outcome.answers += 1 }, onError: { outcome.errors.append($0) })
        waitUntil("an answer to the search") { outcome.total > 0 }
        settle()

        XCTAssertEqual(outcome.answers, 1)
        XCTAssertTrue(outcome.errors.isEmpty)
    }

    func testFailedFacetedSearchCallsOnlyOnError() {
        answerEvents(status: 200, body: ["statusCode": "NO_SESSIONID"])
        var outcome = Outcome()
        let page = SearchFacetPageModel()
        page.query = "shoes"

        manager.sendFacetedSearchPageView(segmentifyObject: page, callback: { _ in outcome.answers += 1 }, onError: { outcome.errors.append($0) })
        waitUntil("an answer to the faceted search") { outcome.total > 0 }
        settle()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.first?.statusCode, "NO_SESSIONID")
    }

    func testSearchThatCannotGetASessionCallsOnlyOnError() {
        lock.lock()
        keyStatus = 500
        lock.unlock()
        var outcome = Outcome()
        let page = SearchPageModel()
        page.query = "shoes"

        manager.sendSearchPageView(segmentifyObject: page, callback: { _ in outcome.answers += 1 }, onError: { outcome.errors.append($0) })
        waitUntil("an answer to the search") { outcome.total > 0 }
        settle()

        XCTAssertEqual(outcome.answers, 0)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(sent(), 0)
    }
}
