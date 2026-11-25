import XCTest
@testable import Segmentify

final class SecureUserProfileStoreTests: XCTestCase {
    private var keychain: InMemoryKeychain!
    private var store: SecureUserProfileStore!

    override func setUp() {
        super.setUp()
        keychain = InMemoryKeychain()
        store = SecureUserProfileStore(storage: keychain, service: "test-service")
    }

    override func tearDown() {
        keychain.reset()
        store = nil
        keychain = nil
        super.tearDown()
    }

    func testFirstIdentifyShouldSend() {
        let params: [String: Any] = ["email": "user@example.com"]
        let expectation = expectation(description: "shouldSendIdentify")

        store.shouldSendIdentify(params) { shouldSend in
            XCTAssertTrue(shouldSend)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 15)
    }

    func testIdenticalParamsShouldNotSendAfterSnapshotSaved() {
        let params: [String: Any] = [
            "email": "user@example.com",
            "username": "johndoe",
        ]
        let firstExpectation = expectation(description: "firstIdentify")
        let secondExpectation = expectation(description: "secondIdentify")

        store.shouldSendIdentify(params) { shouldSend in
            XCTAssertTrue(shouldSend)
            self.store.saveSnapshot(params) {
                firstExpectation.fulfill()
            }
        }
        wait(for: [firstExpectation], timeout: 15)

        store.shouldSendIdentify(params) { shouldSend in
            XCTAssertFalse(shouldSend)
            secondExpectation.fulfill()
        }
        wait(for: [secondExpectation], timeout: 15)
    }

    func testChangedFieldShouldSendAgain() {
        let initial: [String: Any] = ["email": "user@example.com"]
        let updated: [String: Any] = ["email": "other@example.com"]
        let saveExpectation = expectation(description: "saveSnapshot")
        let identifyExpectation = expectation(description: "identifyUpdated")

        store.shouldSendIdentify(initial) { shouldSend in
            XCTAssertTrue(shouldSend)
            self.store.saveSnapshot(initial) {
                saveExpectation.fulfill()
            }
        }
        wait(for: [saveExpectation], timeout: 15)

        store.shouldSendIdentify(updated) { shouldSend in
            XCTAssertTrue(shouldSend)
            identifyExpectation.fulfill()
        }
        wait(for: [identifyExpectation], timeout: 15)
    }

    func testSnapshotPersistsAcrossNewStoreInstance() {
        let params: [String: Any] = ["email": "persist@example.com"]
        let saveExpectation = expectation(description: "saveSnapshot")
        let identifyExpectation = expectation(description: "identifyPersisted")

        store.shouldSendIdentify(params) { shouldSend in
            XCTAssertTrue(shouldSend)
            self.store.saveSnapshot(params) {
                saveExpectation.fulfill()
            }
        }
        wait(for: [saveExpectation], timeout: 15)

        let restoredStore = SecureUserProfileStore(storage: keychain, service: "test-service")
        restoredStore.shouldSendIdentify(params) { shouldSend in
            XCTAssertFalse(shouldSend)
            identifyExpectation.fulfill()
        }
        wait(for: [identifyExpectation], timeout: 15)
    }

    func testCryptoRoundTripIntegrity() {
        let params: [String: Any] = [
            "email": "user@example.com",
            "custom": ["loyalty_level": "gold"],
        ]
        let saveExpectation = expectation(description: "saveSnapshot")
        let identifyExpectation = expectation(description: "identifyRoundTrip")

        store.saveSnapshot(params) {
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: 15)

        store.shouldSendIdentify(params) { shouldSend in
            XCTAssertFalse(shouldSend)
            identifyExpectation.fulfill()
        }
        wait(for: [identifyExpectation], timeout: 15)
    }
}
