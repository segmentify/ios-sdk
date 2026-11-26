import XCTest
import UIKit
@testable import Segmentify

/// SFY-28779: the session ends `sessionKeepSecond` after the last event. A
/// stored session inside that window is used without asking the server.
final class SessionWindowTests: XCTestCase {
    private var manager: SegmentifyManager!
    private let lock = NSLock()
    private var keyPaths: [String] = []
    private var sessionsSent: [String] = []
    private var now = Date()
    private let keep = 100

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        SegmentifyTestSupport.clearSessionDefaults()
        SegmentifyTestSupport.configureSegmentify()
        manager = SegmentifyManager.sharedManager()
        manager.testingClearNetworkSession()
        SegmentifyManager.sessionRetryDelays = [0.01, 0.01]
        _ = SegmentifyManager.setSessionKeepSecond(sessionKeepSecond: keep)
        now = Date()
        SessionWindow.clock = { [unowned self] in self.now }
        keyPaths = []
        sessionsSent = []
        serve()
    }

    override func tearDown() {
        waitUntil("the session request to finish") { self.manager.testingIsSessionRequestIdle }
        SessionWindow.clock = Date.init
        _ = SegmentifyManager.setSessionKeepSecond(sessionKeepSecond: 86400)
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        SegmentifyManager.sessionRetryDelays = SegmentifyManager.defaultSessionRetryDelays
        SegmentifyTestSupport.resetTestNetworking()
        SegmentifyTestSupport.clearSessionDefaults()
        super.tearDown()
    }

    /// Every key request issues a new session: window-1, window-2, ...
    private func serve() {
        MockURLProtocol.requestHandler = { [unowned self] request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("/get/key") {
                self.lock.lock()
                self.keyPaths.append(url)
                let session = "window-\(self.keyPaths.count)"
                self.lock.unlock()
                let keys = url.contains("count=2") ? ["user-1", session] : [session]
                return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.jsonData(keys))
            }
            let body = SegmentifyTestSupport.requestBody(of: request) ?? [:]
            if SegmentifyTestSupport.eventName(of: request) == "PAGE_VIEW",
               let session = body["sessionId"] as? String,
               session.hasPrefix("window-") || session.hasPrefix("stored-") {
                self.lock.lock()
                self.sessionsSent.append(session)
                self.lock.unlock()
            }
            return (SegmentifyTestSupport.httpResponse(for: request), try SegmentifyTestSupport.emptyEventResponse())
        }
    }

    private func recorded() -> (keys: [String], sessions: [String]) {
        lock.lock()
        defer { lock.unlock() }
        return (keyPaths, sessionsSent)
    }

    private func sendPageView() {
        let before = recorded().sessions.count
        var answered = false
        let page = PageModel()
        page.category = "Home Page"
        manager.sendPageView(segmentifyObject: page) { _ in answered = true }
        waitUntil("the page view") { answered && self.recorded().sessions.count == before + 1 }
    }

    private func store(session: String, endsIn seconds: TimeInterval) {
        UserDefaults.standard.set("user-1", forKey: "SEGMENTIFY_USER_ID")
        UserDefaults.standard.set(session, forKey: SessionWindow.sessionKey)
        UserDefaults.standard.set(round(now.addingTimeInterval(seconds).timeIntervalSince1970), forKey: SessionWindow.endKey)
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    func testStoredSessionInsideTheWindowIsUsedWithoutAKeyRequest() {
        store(session: "stored-1", endsIn: 50)

        sendPageView()

        XCTAssertEqual(recorded().keys, [])
        XCTAssertEqual(recorded().sessions, ["stored-1"])
    }

    func testStoredSessionPastTheWindowIsReplaced() {
        store(session: "stored-1", endsIn: -10)

        sendPageView()

        XCTAssertEqual(recorded().keys.count, 1)
        XCTAssertTrue(recorded().keys.first?.contains("count=1") ?? false, "\(recorded().keys)")
        XCTAssertEqual(recorded().sessions, ["window-1"])
    }

    /// A stored end that is not a number counts as ended; it must not trap.
    func testCorruptedEndIsTreatedAsEnded() {
        store(session: "stored-1", endsIn: 50)
        UserDefaults.standard.set("not a time", forKey: SessionWindow.endKey)

        sendPageView()

        XCTAssertEqual(recorded().sessions, ["window-1"])
    }

    /// The app does not have to go to the background for the session to end.
    func testSessionEndsWhileTheAppStaysActive() {
        sendPageView()
        now = now.addingTimeInterval(TimeInterval(keep + 1))

        sendPageView()

        XCTAssertEqual(recorded().keys.count, 2, "\(recorded().keys)")
        XCTAssertEqual(recorded().sessions, ["window-1", "window-2"])
    }

    func testEveryEventKeepsTheSessionAlive() {
        sendPageView()
        now = now.addingTimeInterval(TimeInterval(keep) * 0.8)
        sendPageView()
        now = now.addingTimeInterval(TimeInterval(keep) * 0.8)
        sendPageView()

        XCTAssertEqual(recorded().keys.count, 1, "\(recorded().keys)")
        XCTAssertEqual(recorded().sessions, ["window-1", "window-1", "window-1"])
    }

    func testBecomingActiveInsideTheWindowMakesNoKeyRequest() {
        store(session: "stored-1", endsIn: 50)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        settle()

        XCTAssertEqual(recorded().keys, [])
    }

    func testSessionKeepSecondSetsTheWindow() {
        sendPageView()

        let end = UserDefaults.standard.double(forKey: SessionWindow.endKey)
        XCTAssertEqual(end, round(now.timeIntervalSince1970) + Double(keep), accuracy: 1)
    }
}
