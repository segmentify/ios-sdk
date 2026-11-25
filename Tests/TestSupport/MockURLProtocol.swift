import Foundation
import XCTest
@testable import Segmentify

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "segmentify-sdk.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

enum SegmentifyTestSupport {
    static let dataCenterURL = "https://segmentify-sdk.test"
    static let apiKey = "test-api-key"
    static let subDomain = "example.com"

    static func configureSegmentify() {
        SegmentifyManager.config(
            appkey: apiKey,
            dataCenterUrl: dataCenterURL,
            subDomain: subDomain
        )
        _ = SegmentifyManager.logStatus(isVisible: false)
        SegmentifyConnectionManager.testing_protocolClasses = [MockURLProtocol.self]
        SegmentifyManager.sharedManager().testingPrepareNetworkSession()
    }

    static func resetTestNetworking() {
        SegmentifyManager.sharedManager().testingClearNetworkSession()
        SegmentifyConnectionManager.resetTestingURLSession()
    }

    static func emptyEventResponse() throws -> Data {
        try jsonData(["responses": []])
    }

    static func seedSessionDefaults(
        userId: String = "test-user",
        sessionId: String = "test-session"
    ) {
        let futureTimestamp = Date().timeIntervalSince1970 + 86_400
        UserDefaults.standard.set(userId, forKey: "SEGMENTIFY_USER_ID")
        UserDefaults.standard.set(sessionId, forKey: "SEGMENTIFY_SESSION_ID")
        UserDefaults.standard.set(futureTimestamp, forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP")
    }

    static func clearSessionDefaults() {
        UserDefaults.standard.removeObject(forKey: "SEGMENTIFY_USER_ID")
        UserDefaults.standard.removeObject(forKey: "SEGMENTIFY_SESSION_ID")
        UserDefaults.standard.removeObject(forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP")
        UserDefaults.standard.removeObject(forKey: "UserSentUserId")
        UserDefaults.standard.removeObject(forKey: "SEGMENTIFY_EMAIL")
        UserDefaults.standard.removeObject(forKey: "SEGMENTIFY_USERNAME")
    }

    static func httpResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    static func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// The JSON body of an event request. URLProtocol hands the body over as a
    /// stream, so it is read from there when `httpBody` is nil.
    static func requestBody(of request: URLRequest) -> [String: Any]? {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 {
                    break
                }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// The `name` field of the event in the request body.
    static func eventName(of request: URLRequest) -> String? {
        requestBody(of: request)?["name"] as? String
    }

    static func sessionKeyHandler() -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let response = httpResponse(for: request)
            let data = try jsonData(["ignored-session-key"])
            return (response, data)
        }
    }

    static func routeRequests(
        eventHandler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let path = request.url?.absoluteString ?? ""
            if path.contains("/get/key") {
                return try sessionKeyHandler()(request)
            }
            if path.contains("/add/events/") {
                return try eventHandler(request)
            }
            throw URLError(.unsupportedURL)
        }
    }
}

extension XCTestCase {
    /// Polls instead of sleeping a fixed time: CI simulators stall for seconds.
    func waitUntil(_ what: String, timeout: TimeInterval = 15, _ condition: @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertTrue(condition(), "timed out waiting for \(what)")
    }
}
