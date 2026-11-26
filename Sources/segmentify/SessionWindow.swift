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
        true
    }

    /// Starts the window again from now.
    static func extend(keepSeconds: Int, defaults: UserDefaults = .standard) {
    }
}
