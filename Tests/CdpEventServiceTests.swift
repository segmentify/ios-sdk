import XCTest
@testable import Segmentify

final class CdpEventServiceTests: XCTestCase {
    private var sessionResolver: StubSessionResolver!
    private var requestBuilder: StubRequestBuilder!
    private var keychain: InMemoryKeychain!
    private var profileStore: SecureUserProfileStore!
    private var dispatcher: SpyDispatcher!
    private var service: CdpEventService!

    override func setUp() {
        super.setUp()
        sessionResolver = StubSessionResolver(userId: "user-1", sessionId: "session-1")
        requestBuilder = StubRequestBuilder()
        keychain = InMemoryKeychain()
        profileStore = SecureUserProfileStore(storage: keychain, service: "test-service")
        dispatcher = SpyDispatcher()
        service = CdpEventService(
            sessionResolver: sessionResolver,
            requestBuilder: requestBuilder,
            profileStore: profileStore,
            dispatcher: dispatcher.dispatch
        )
    }

    override func tearDown() {
        keychain.reset()
        service = nil
        dispatcher = nil
        profileStore = nil
        keychain = nil
        requestBuilder = nil
        sessionResolver = nil
        super.tearDown()
    }

    func testSendSkipsWhenPropertiesEmpty() {
        let completion = expectation(description: "completion")

        service.send(name: CdpEventName.userTraits, properties: [:]) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 0)
    }

    func testSendBuildsRequestWithNamePropertiesAndSession() throws {
        dispatcher.mode = .success
        let completion = expectation(description: "completion")

        service.send(
            name: CdpEventName.userLogin,
            properties: ["email": "user@example.com"]
        ) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 15)

        let sent = try XCTUnwrap(dispatcher.lastRequest)
        XCTAssertEqual(sent.eventName, CdpEventName.userLogin)
        XCTAssertEqual(sent.userID, "user-1")
        XCTAssertEqual(sent.sessionID, "session-1")
        XCTAssertEqual(sent.userTraitsProperties?["email"] as? String, "user@example.com")
    }

    func testSendInvokesCompletionOnFailure() {
        dispatcher.mode = .failure
        let completion = expectation(description: "completion")

        service.send(
            name: CdpEventName.userLogout,
            properties: ["email": "user@example.com"]
        ) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 1)
    }

    func testIdentifySkipsDispatchWhenPropertiesEmpty() {
        let completion = expectation(description: "completion")

        service.identify(properties: [:]) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 0)
    }

    func testIdentifySavesSnapshotOnlyAfterSuccess() {
        dispatcher.mode = .success
        let params: [String: Any] = ["email": "user@example.com"]
        let first = expectation(description: "first identify")

        service.identify(properties: params) {
            first.fulfill()
        }
        wait(for: [first], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 1)

        // Snapshot must have been persisted, so an identical identify is skipped.
        let second = expectation(description: "second identify")
        service.identify(properties: params) {
            second.fulfill()
        }
        wait(for: [second], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 1, "Identical identify after success must not re-dispatch")
    }

    func testIdentifyDoesNotSaveSnapshotOnFailure() {
        dispatcher.mode = .failure
        let params: [String: Any] = ["email": "user@example.com"]
        let first = expectation(description: "first identify")

        service.identify(properties: params) {
            first.fulfill()
        }
        wait(for: [first], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 1)

        // Failure must not persist a snapshot, so the next identify retries.
        dispatcher.mode = .success
        let retry = expectation(description: "retry identify")
        service.identify(properties: params) {
            retry.fulfill()
        }
        wait(for: [retry], timeout: 15)
        XCTAssertEqual(dispatcher.dispatchCount, 2, "Identify must retry after a failed send")
    }
}

// MARK: - Test doubles

private final class StubSessionResolver: CdpSessionResolving {
    private let userId: String?
    private let sessionId: String?

    init(userId: String?, sessionId: String?) {
        self.userId = userId
        self.sessionId = sessionId
    }

    func resolveCdpSession(completion: @escaping (String?, String?) -> Void) {
        completion(userId, sessionId)
    }
}

private final class StubRequestBuilder: CdpRequestBuilding {
    func makeCdpRequest() -> SegmentifyRegisterRequest {
        let request = SegmentifyRegisterRequest()
        request.apiKey = "test-api-key"
        request.dataCenterUrl = "https://segmentify-sdk.test"
        request.subdomain = "example.com"
        return request
    }
}

private final class SpyDispatcher {
    enum Mode {
        case success
        case failure
        case ignore
    }

    var mode: Mode = .ignore
    private(set) var dispatchCount = 0
    private(set) var lastRequest: SegmentifyRegisterRequest?

    func dispatch(
        _ request: SegmentifyRegisterRequest,
        success: @escaping () -> Void,
        failure: @escaping () -> Void
    ) {
        dispatchCount += 1
        lastRequest = request
        switch mode {
        case .success:
            success()
        case .failure:
            failure()
        case .ignore:
            break
        }
    }
}
