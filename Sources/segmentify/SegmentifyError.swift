//
//  SegmentifyError.swift
//  Segmentify

import Foundation

/// Why a request could not be completed. Handed to the `onError` closure of the
/// `send…(segmentifyObject:callback:onError:)` methods.
///
/// The counterpart of `SegmentifyException` in the Android SDK.
@objc public class SegmentifyError: NSObject, Error {
    /// What went wrong, for logs. Not meant to be shown to the user.
    @objc public let message: String

    /// The HTTP status when the server answered with an error; `nil` when it
    /// did not answer or the request was never sent.
    @objc public let httpStatusCode: NSNumber?

    /// The backend's reason when it answered but refused the request, for
    /// example `NO_SESSIONID` or `INVALID_EVENT`.
    @objc public let statusCode: String?

    /// The transport error (no network, timeout, …), when there is one.
    @objc public let underlyingError: Error?

    /// `httpStatusCode` as a Swift integer.
    public var httpStatus: Int? { httpStatusCode?.intValue }

    /// Public so that host apps can build one in their own tests.
    public init(message: String, httpStatus: Int? = nil, statusCode: String? = nil, underlyingError: Error? = nil) {
        self.message = message
        self.httpStatusCode = httpStatus.map { NSNumber(value: $0) }
        self.statusCode = statusCode
        self.underlyingError = underlyingError
    }

    /// How much of an error response's body goes into `message`.
    static let maxBodyInMessage = 200

    static func noSession() -> SegmentifyError {
        SegmentifyError(message: "The event was not sent: no session could be obtained")
    }

    /// The public form of what the network layer reports.
    static func from(_ error: Error) -> SegmentifyError {
        guard let networkError = error as? SegmentifyNetworkError else {
            return SegmentifyError(message: "The request failed: \(error.localizedDescription)", underlyingError: error)
        }
        switch networkError {
        case .httpStatus(let status, let body):
            var message = "The server answered with HTTP \(status)"
            if let body = body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                message += ": " + (body.count > maxBodyInMessage ? body.prefix(maxBodyInMessage) + "…" : body)
            }
            return SegmentifyError(message: message, httpStatus: status)
        case .rejected(let statusCode):
            return SegmentifyError(message: "The backend refused the request: \(statusCode)", statusCode: statusCode)
        case .invalidURL(let url):
            return SegmentifyError(message: "The request URL is not valid: \(url)")
        case .unserializableBody:
            return SegmentifyError(message: "The event could not be serialized")
        case .noResponse:
            return SegmentifyError(message: "The server did not answer with an HTTP response")
        case .notConfigured:
            return SegmentifyError(message: "The event was not sent: SegmentifyManager.config must be called before sending events")
        }
    }

    public override var description: String {
        "SegmentifyError: \(message)"
    }
}
