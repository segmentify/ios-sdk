//
//  SegmentifyAuth.swift
//  Segmentify

import Foundation

/// Authentication for SDK requests.
///
/// - authHeader set: `Authorization: Basic <token>` and no `apiKey` query parameter
///   (Unifonic push-notification-api)
/// - otherwise:      `?apiKey=<apiKey>` as in the original Segmentify setup
enum SegmentifyAuth {

    /// Returns the Authorization header value for a configured authHeader.
    /// A value that already starts with "Basic " (case-insensitive) is used as is;
    /// anything else gets the "Basic " prefix. Same rule as the web SDK. Blank values return nil.
    static func authorizationValue(_ authHeader: String?) -> String? {
        guard let value = authHeader?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let hasBasicScheme = value.range(of: "^Basic\\s", options: [.regularExpression, .caseInsensitive]) != nil
        return hasBasicScheme ? value : "Basic \(value)"
    }

    /// Builds the request URL, adding `apiKey` as a query parameter only when
    /// there is no Authorization header.
    static func url(_ urlString: String, apiKey: String?, authorization: String?) -> URL? {
        guard authorization == nil, let apiKey = apiKey, !apiKey.isEmpty,
              var components = URLComponents(string: urlString) else {
            return URL(string: urlString)
        }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "apiKey", value: apiKey)]
        return components.url
    }
}
