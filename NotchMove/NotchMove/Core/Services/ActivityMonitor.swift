//
//  ActivityMonitor.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import CoreGraphics
import Foundation
import Observation

/// Polls system-wide idle time via CGEventSource.
/// No Accessibility permission required — reads the combined session state directly.
@Observable
final class ActivityMonitor: IdleTimeProviding {
    private(set) var idleSeconds: TimeInterval = 0

    @ObservationIgnored private var pollTask: Task<Void, Never>?

    // kCGAnyInputEventType (documented as ~0) — matches any keyboard, mouse, or tablet event
    // swiftlint:disable:next force_unwrapping
    nonisolated private static let anyInputEvent = CGEventType(rawValue: ~0)!

    deinit {
        pollTask?.cancel()
    }

    func start() {
        pollTask?.cancel()
        poll()
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self.poll()
            }
        }
    }

    private func poll() {
        idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: Self.anyInputEvent
        )
    }
}
