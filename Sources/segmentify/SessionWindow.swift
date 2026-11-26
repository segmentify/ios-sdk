//
//  SessionWindow.swift
//  Segmentify

import Foundation

/// When the stored session id may still be used (SFY-28779).
///
/// `SEGMENTIFY_SESSION_ID_TIMESTAMP` holds the moment the session ends: the
/// last activity plus `sessionKeepSecond`, in seconds since 1970. A session is
/// used only up to that moment, every event moves it forward, and the check
/// runs before every event. The Android SDK follows the same rule (SFY-28789).
enum SessionWindow {
    static let endKey = "SEGMENTIFY_SESSION_ID_TIMESTAMP"
    static let sessionKey = "SEGMENTIFY_SESSION_ID"

    /// Replaced in tests.
    static var clock: () -> Date = Date.init

    /// True while the stored session has not ended.
    static func isOpen(defaults: UserDefaults = .standard) -> Bool {
        // A missing or unreadable end counts as ended.
        guard let end = defaults.object(forKey: endKey) as? NSNumber else {
            return false
        }
        return clock().timeIntervalSince1970 <= end.doubleValue
    }

    /// The stored session id while its window is open.
    static func storedSessionId(defaults: UserDefaults = .standard) -> String? {
        guard isOpen(defaults: defaults),
              let sessionId = defaults.string(forKey: sessionKey),
              !sessionId.isEmpty else {
            return nil
        }
        return sessionId
    }

    /// Stores a new session id and opens its window.
    static func start(sessionId: String?, keepSeconds: Int, defaults: UserDefaults = .standard) {
        defaults.set(sessionId, forKey: sessionKey)
        extend(keepSeconds: keepSeconds, defaults: defaults)
    }

    /// Starts the window again from now.
    static func extend(keepSeconds: Int, defaults: UserDefaults = .standard) {
        defaults.set(round(clock().timeIntervalSince1970) + Double(keepSeconds), forKey: endKey)
    }
}
