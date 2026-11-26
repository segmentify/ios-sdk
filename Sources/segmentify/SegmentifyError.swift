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

    init(message: String, httpStatus: Int? = nil, statusCode: String? = nil, underlyingError: Error? = nil) {
        self.message = message
        self.httpStatusCode = httpStatus.map { NSNumber(value: $0) }
        self.statusCode = statusCode
        self.underlyingError = underlyingError
    }

    public override var description: String {
        "SegmentifyError: \(message)"
    }
}
