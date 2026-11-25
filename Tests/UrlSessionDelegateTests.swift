import XCTest
@testable import Segmentify

/// SFY-28772: the session delegate must leave server trust evaluation to the system.
final class UrlSessionDelegateTests: XCTestCase {

    private final class ChallengeSender: NSObject, URLAuthenticationChallengeSender {
        func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
        func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
        func cancel(_ challenge: URLAuthenticationChallenge) {}
    }

    private func makeChallenge(authenticationMethod: String) -> URLAuthenticationChallenge {
        let space = URLProtectionSpace(
            host: "gandalf-eu.segmentify.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: authenticationMethod
        )
        return URLAuthenticationChallenge(
            protectionSpace: space,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: ChallengeSender()
        )
    }

    private func respond(
        to challenge: URLAuthenticationChallenge
    ) -> (disposition: URLSession.AuthChallengeDisposition?, credential: URLCredential?) {
        let delegate = SegmentifyUrlSessionDelegate()
        var disposition: URLSession.AuthChallengeDisposition?
        var credential: URLCredential?
        delegate.urlSession(URLSession.shared, didReceive: challenge) { receivedDisposition, receivedCredential in
            disposition = receivedDisposition
            credential = receivedCredential
        }
        return (disposition, credential)
    }

    func testServerTrustChallengeIsLeftToTheSystem() {
        let result = respond(to: makeChallenge(authenticationMethod: NSURLAuthenticationMethodServerTrust))

        XCTAssertEqual(result.disposition, .performDefaultHandling)
        XCTAssertNil(result.credential, "the SDK must not supply its own trust credential")
    }

    func testChallengeWithoutServerTrustDoesNotCrash() {
        let result = respond(to: makeChallenge(authenticationMethod: NSURLAuthenticationMethodHTTPBasic))

        XCTAssertEqual(result.disposition, .performDefaultHandling)
        XCTAssertNil(result.credential)
    }
}
