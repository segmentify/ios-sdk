//
//  SegmentifyConnectionManager.swift
//  Segmentify

import Foundation

class SegmentifyConnectionManager : NSObject, URLSessionDelegate  {
    
    static let timeoutInterval = 10
    static let baseUrl = "/add/events/v1.json?apiKey="
    static let successStatusCode = "SUCCESS"
    
    static let sharedInstance : SegmentifyConnectionManager = {
        let shareManager = SegmentifyConnectionManager()
        return shareManager
    }()
    
    let sessionDelegate: SegmentifyUrlSessionDelegate
    var debugMode = true
    
    func shared() -> SegmentifyConnectionManager {
        return .sharedInstance
    }
    
    override init() {
        sessionDelegate = SegmentifyUrlSessionDelegate()
    }
    
    private static var cachedTestingURLSession: URLSession?

    static var urlSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 3
        if let testing_protocolClasses {
            configuration.protocolClasses = testing_protocolClasses
            if let cachedTestingURLSession {
                return cachedTestingURLSession
            }
            let session = URLSession(
                configuration: configuration,
                delegate: SegmentifyUrlSessionDelegate(),
                delegateQueue: nil
            )
            cachedTestingURLSession = session
            return session
        }

        return URLSession(
            configuration: configuration,
            delegate: SegmentifyUrlSessionDelegate(),
            delegateQueue: nil
        )
    }

    static var testing_protocolClasses: [AnyClass]?

    static func resetTestingURLSession() {
        cachedTestingURLSession?.invalidateAndCancel()
        cachedTestingURLSession = nil
        testing_protocolClasses = nil
    }
    
    func request(urlString: String) {
        guard let url = URL(string: urlString) else {
            log("Invalid URL : \(urlString)")
            return
        }
        let request = URLRequest(url: url)
        log("Request to : \(url)")
        let dataTask = SegmentifyConnectionManager.urlSession.dataTask(with: request) {data, response, error in
            debugPrint("Server responded. Error  : \(String(describing: error))")
        }
        dataTask.resume()
    }
    
    /// Sends `requestModel` to the event endpoint.
    ///
    /// Exactly one of `success` and `failure` is called, on the main queue:
    /// `success` for a 2xx answer (with an empty dictionary when the body is not
    /// a JSON object), `failure` for everything else.
    func request<R: SegmentifyRequestProtocol>(requestModel: R, success: @escaping (_ response: [String:AnyObject]) -> Void, failure: @escaping (_ error: Error) -> Void) {

        func fail(_ error: Error) {
            log("Request failed : \(error)")
            DispatchQueue.main.async { failure(error) }
        }

        let urlString = "\(requestModel.dataCenterUrl)\(SegmentifyConnectionManager.baseUrl)\(requestModel.apiKey)"
        guard let url = URL(string: urlString) else {
            fail(SegmentifyNetworkError.invalidURL(urlString))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = requestModel.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestModel.subdomain, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = TimeInterval(SegmentifyConnectionManager.timeoutInterval)

        if requestModel.method == "POST" || requestModel.method == "PUT" {
            // JSONSerialization raises an Objective-C exception, which Swift cannot
            // catch, for values it does not support; check before serializing.
            let body = requestModel.toDictionary()
            guard JSONSerialization.isValidJSONObject(body),
                  let data = try? JSONSerialization.data(withJSONObject: body, options: []) else {
                fail(SegmentifyNetworkError.unserializableBody)
                return
            }
            request.httpBody = data
            log("Request to \(url) with body \(String(data: data, encoding: .utf8) ?? "")")
        } else {
            log("Request to \(url)")
        }

        let dataTask = SegmentifyConnectionManager.urlSession.dataTask(with: request) { data, response, connectionError in
            if let connectionError = connectionError {
                fail(connectionError)
                return
            }
            guard let remoteResponse = response as? HTTPURLResponse else {
                fail(SegmentifyNetworkError.noResponse)
                return
            }
            guard (200...299).contains(remoteResponse.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) }
                fail(SegmentifyNetworkError.httpStatus(remoteResponse.statusCode, body: (body?.isEmpty ?? true) ? nil : body))
                return
            }

            let jsonObject = data.flatMap {
                try? JSONSerialization.jsonObject(with: $0, options: .allowFragments)
            } as? [String:AnyObject]
            self.log("Server response code : \(remoteResponse.statusCode), response : \(String(describing: jsonObject))")

            // The backend answers 200 even when it refuses an event.
            if let statusCode = jsonObject?["statusCode"] as? String, statusCode != SegmentifyConnectionManager.successStatusCode {
                fail(SegmentifyNetworkError.rejected(statusCode: statusCode))
                return
            }

            DispatchQueue.main.async {
                success(jsonObject ?? [:])
            }
        }
        dataTask.resume()
    }

    private func log(_ message: @autoclosure () -> String) {
        if SegmentifyManager.logStatus {
            print(message())
        }
    }
}

/// Why a request to the event endpoint did not produce a usable answer.
enum SegmentifyNetworkError: Error, Equatable {
    case invalidURL(String)
    case unserializableBody
    case noResponse
    /// The server answered with an HTTP error; `body` is what it sent along.
    case httpStatus(Int, body: String?)
    /// The server answered 200 but refused the event; `statusCode` is its
    /// reason, for example NO_SESSIONID, INVALID_EVENT, BOT or TIMEOUT.
    case rejected(statusCode: String)
}
