//
//  SegmentifyRequestProtocol.swift
//  Segmentify

import Foundation

protocol SegmentifyRequestProtocol {
    
    var path: String { get }
    var port: String { get }
    var method: String { get }
    var subdomain: String { get }
    var dataCenterUrl: String { get }
    var apiKey: String { get }
    
    func toDictionary() -> Dictionary<AnyHashable, Any>
}

extension SegmentifyRequestProtocol {
    /// False for a request built before SegmentifyManager.config.
    var isConfigured: Bool {
        !apiKey.isEmpty && !dataCenterUrl.isEmpty
    }
}
