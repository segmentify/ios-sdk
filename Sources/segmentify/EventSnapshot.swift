//
//  EventSnapshot.swift
//  Segmentify

import Foundation

/// An event frozen at the moment the host app asked for it.
///
/// Events that have to wait for a session cannot keep pointing at the shared,
/// mutable request: the next event would overwrite them. A snapshot carries its
/// own payload; only the session ids are filled in when it is finally sent.
final class EventSnapshot: SegmentifyRequestProtocol {
    let path: String
    let port: String
    let method: String
    let subdomain: String
    let dataCenterUrl: String
    let apiKey: String

    private var body: Dictionary<AnyHashable, Any>

    init(of request: SegmentifyRegisterRequest) {
        path = request.path
        port = request.port
        method = request.method
        subdomain = request.subdomain
        dataCenterUrl = request.dataCenterUrl
        apiKey = request.apiKey
        body = request.toDictionary()
    }

    var eventName: String? {
        body["name"] as? String
    }

    /// A user id captured with the event (set by the host app) is kept.
    func applySession(userId: String?, sessionId: String?) {
        if body["userId"] == nil, let userId = userId {
            body["userId"] = userId
        }
        if let sessionId = sessionId {
            body["sessionId"] = sessionId
        }
    }

    func toDictionary() -> Dictionary<AnyHashable, Any> {
        body
    }
}
