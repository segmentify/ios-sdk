//
//  SegmentifyConnectionManager.swift
//  Segmentify

import Foundation

class SegmentifyConnectionManager : NSObject, URLSessionDelegate  {
    
    static let timeoutInterval = 10
    static let baseUrl = "/add/events/v1.json"
    
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
        let url = URL.init(string: urlString)
        let request = URLRequest.init(url: url!)
        if SegmentifyManager.logStatus == true {
            debugPrint("Request to : \(url!)")
        }
        let dataTask = SegmentifyConnectionManager.urlSession.dataTask(with: request) {data, response, error in
            debugPrint("Server responded. Error  : \(String(describing: error))")
        }
        dataTask.resume()
    }
    
    func request<R: SegmentifyRequestProtocol>(requestModel: R, success: @escaping (_ response: [String:AnyObject]) -> Void, failure: @escaping (_ error: Error) -> Void) {
        
        var url: URL?
        if let authHeader = requestModel.authHeader {
            url = URL.init(string: "\(requestModel.dataCenterUrl)\(SegmentifyConnectionManager.baseUrl)")
        } else {
            url = URL.init(string: "\(requestModel.dataCenterUrl)\(SegmentifyConnectionManager.baseUrl)?apiKey=\(requestModel.apiKey ?? "")")
        }
        
        if SegmentifyManager.logStatus == true {
            print("URL : \(String(describing: url!))")
        }
        
        var request = URLRequest.init(url: url!)
        request.httpMethod = requestModel.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestModel.subdomain, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authHeader = requestModel.authHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = TimeInterval(SegmentifyConnectionManager.timeoutInterval)
        if SegmentifyManager.logStatus == true {
            print("request header : \(String(describing: (request.allHTTPHeaderFields)!))")
        }
        
        if (requestModel.method == "POST" || requestModel.method == "PUT") {
            request.httpBody = try! JSONSerialization.data(withJSONObject: requestModel.toDictionary(), options: [])
        }
        
        if (request.httpBody != nil) {
            if SegmentifyManager.logStatus == true {
                debugPrint("Request to \(url!) with body \(String.init(data: request.httpBody!, encoding: String.Encoding.utf8)!)")
            }
        }
        
        let dataTask = SegmentifyConnectionManager.urlSession.dataTask(with: request) {data, response, connectionError in
            if SegmentifyManager.logStatus == true {
                print("request : \(request)")
            }
            if connectionError == nil {
                let remoteResponse = response as! HTTPURLResponse
                
                DispatchQueue.main.async {
                    if (connectionError == nil && (remoteResponse.statusCode == 200 || remoteResponse.statusCode == 201)) {
                        if (self.debugMode) {
                            if SegmentifyManager.logStatus == true {
                                print("Server response code : \(remoteResponse.statusCode)")
                            }
                        }
                        
                        do {
                            let jsonObject = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String:AnyObject]
                            if SegmentifyManager.logStatus == true {
                                print("response : \(String(describing: jsonObject))")
                            }
                            
                            success(jsonObject!)
                            
                        } catch {
                            success(([String:AnyObject]() as AnyObject) as! [String : AnyObject])
                        }
                    }
                    else {
                        
                        if (self.debugMode) {
                            print("Server response with failure : \(remoteResponse.statusCode)")
                        }

                        do{
                            print("Server response with failure : \(remoteResponse.statusCode)")
                            return
                        }
                        
                    }
                }
            } else {
                print("Connection error \(String(describing: connectionError))")
                DispatchQueue.main.async {
                    failure(connectionError ?? URLError(.unknown))
                }
            }
        }
        dataTask.resume()
    }
    
    
}
