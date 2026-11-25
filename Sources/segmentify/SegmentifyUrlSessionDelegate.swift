//
//  SegmentifyUrlSessionDelegate.swift
//  Segmentify


import Foundation

class SegmentifyUrlSessionDelegate : NSObject, URLSessionDelegate {

    /// Authentication challenges, server trust included, are evaluated by the
    /// system. The SDK never supplies its own trust credential: doing so would
    /// accept any certificate.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}
