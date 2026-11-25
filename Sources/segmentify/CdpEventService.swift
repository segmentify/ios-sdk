//
//  CdpEventService.swift
//  Segmentify
//
//  Isolated pipeline for CDP user events (USER_TRAITS, USER_IDENTIFY,
//  USER_REGISTER, USER_LOGIN, USER_LOGOUT, USER_SUBSCRIBE, USER_UNSUBSCRIBE).
//
//  CDP events never mutate the shared `eventRequest` used by the legacy
//  e-commerce / tracking pipeline. Each send builds a fresh request instance,
//  resolves the current session, and dispatches directly.

import Foundation

/// Resolves the current user id / session id without leaking CDP event data
/// into the shared request state.
protocol CdpSessionResolving: AnyObject {
    func resolveCdpSession(completion: @escaping (_ userId: String?, _ sessionId: String?) -> Void)
}

/// Builds a fresh, config-populated request for a single CDP event so that no
/// event-specific state is shared between sends.
protocol CdpRequestBuilding: AnyObject {
    func makeCdpRequest() -> SegmentifyRegisterRequest
}

final class CdpEventService {
    /// Dispatches a fully-built request and reports transport success / failure.
    typealias Dispatcher = (
        _ request: SegmentifyRegisterRequest,
        _ success: @escaping () -> Void,
        _ failure: @escaping () -> Void
    ) -> Void

    // Held weakly: the owning manager retains this service, so strong references
    // here would create a retain cycle.
    private weak var sessionResolver: CdpSessionResolving?
    private weak var requestBuilder: CdpRequestBuilding?
    private let profileStore: SecureUserProfileStore
    private let dispatcher: Dispatcher

    init(
        sessionResolver: CdpSessionResolving,
        requestBuilder: CdpRequestBuilding,
        profileStore: SecureUserProfileStore,
        dispatcher: @escaping Dispatcher
    ) {
        self.sessionResolver = sessionResolver
        self.requestBuilder = requestBuilder
        self.profileStore = profileStore
        self.dispatcher = dispatcher
    }

    /// Sends a CDP event. Empty payloads are ignored. `completion` is invoked
    /// once the transport settles (success or failure).
    func send(name: String, properties: [String: Any], completion: (() -> Void)? = nil) {
        perform(name: name, properties: properties) { _ in
            completion?()
        }
    }

    /// Sends `USER_IDENTIFY` only when the profile snapshot changed. The
    /// encrypted snapshot is persisted **after** a successful send so a failed
    /// request is retried on the next call.
    func identify(properties: [String: Any], completion: (() -> Void)? = nil) {
        guard !properties.isEmpty else {
            completion?()
            return
        }

        profileStore.shouldSendIdentify(properties) { [weak self] shouldSend in
            guard let self else {
                completion?()
                return
            }

            guard shouldSend else {
                completion?()
                return
            }

            self.perform(name: CdpEventName.userIdentify, properties: properties) { success in
                guard success else {
                    completion?()
                    return
                }

                self.profileStore.saveSnapshot(properties) {
                    completion?()
                }
            }
        }
    }

    private func perform(
        name: String,
        properties: [String: Any],
        onResult: @escaping (_ success: Bool) -> Void
    ) {
        guard !properties.isEmpty else {
            onResult(false)
            return
        }

        guard let sessionResolver, let requestBuilder else {
            onResult(false)
            return
        }

        let dispatcher = self.dispatcher
        sessionResolver.resolveCdpSession { userId, sessionId in
            // The backend rejects an event without a session id; report the
            // failure instead of sending it.
            guard let sessionId = sessionId, !sessionId.isEmpty else {
                onResult(false)
                return
            }

            let request = requestBuilder.makeCdpRequest()
            request.eventName = name
            request.userTraitsProperties = properties
            request.userOperationStep = nil
            request.params = nil
            request.userID = userId
            request.sessionID = sessionId

            dispatcher(
                request,
                { onResult(true) },
                { onResult(false) }
            )
        }
    }
}
