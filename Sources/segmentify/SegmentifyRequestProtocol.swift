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
    var apiKey: String? { get }
    var authHeader: String? { get }
    
    func toDictionary() -> Dictionary<AnyHashable, Any>
}
