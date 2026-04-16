//
//  ActivityMonitor.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import CoreGraphics
import Foundation

/// Polls system-wide idle time via CGEventSource.
/// No Accessibility permission required — reads the combined session state directly.
@Observable
final class ActivityMonitor {
    private(set) var idleSeconds: TimeInterval = 0

    /// True when the user has been active within the idle threshold (default 3 min).
    var isActivelyUsing: Bool {
        idleSeconds < idleThreshold
    }

    let idleThreshold: TimeInterval = 180

    private var pollTask: Task<Void, Never>?

    // kCGAnyInputEventType (documented as ~0) — matches any keyboard, mouse, or tablet event
    // swiftlint:disable:next force_unwrapping
    nonisolated private static let anyInputEvent = CGEventType(rawValue: ~0)!

    func start() {
        poll()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func poll() {
        idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: Self.anyInputEvent
        )
    }
}
