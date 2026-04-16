//
//  ReminderScheduler.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import Foundation
import OSLog

/// Sit-aware reminder engine.
/// Accumulates active-use seconds, resets when user goes idle (already standing),
/// fires a callback when the reminder interval is reached.
@Observable
final class ReminderScheduler {
    private(set) var activeSeconds: TimeInterval = 0
    private(set) var isPaused = false
    var isEnabled = true

    /// Seconds of active use before firing a reminder. Default 30 min.
    var reminderInterval: TimeInterval = 1800

    /// Seconds of idle time that resets the accumulator (user probably stood up).
    var idleResetThreshold: TimeInterval = 180

    /// Progress toward the next reminder (0.0–1.0).
    var progress: Double {
        guard reminderInterval > 0 else { return 0 }
        return min(activeSeconds / reminderInterval, 1)
    }

    /// Minutes remaining until the next reminder.
    var minutesRemaining: Int {
        let remaining = max(reminderInterval - activeSeconds, 0)
        return Int(ceil(remaining / 60))
    }

    private let activityMonitor: ActivityMonitor
    private let onReminder: () -> Void
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "scheduler")
    private var tickTask: Task<Void, Never>?
    private var lastTickDate: Date?

    init(activityMonitor: ActivityMonitor, onReminder: @escaping () -> Void) {
        self.activityMonitor = activityMonitor
        self.onReminder = onReminder
    }

    func start() {
        lastTickDate = .now
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                tick()
            }
        }
        logger.notice("Scheduler started — interval=\(self.reminderInterval)s, idleReset=\(self.idleResetThreshold)s")
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Call after a reminder is dismissed to resume tracking.
    func resume() {
        isPaused = false
        activeSeconds = 0
        lastTickDate = .now
        logger.notice("Scheduler resumed")
    }

    private func tick() {
        guard isEnabled, !isPaused else { return }

        let now = Date.now
        let elapsed = lastTickDate.map { now.timeIntervalSince($0) } ?? 5
        lastTickDate = now

        // If the user has been idle longer than the threshold, they're probably
        // already standing — reset the accumulator.
        if activityMonitor.idleSeconds >= idleResetThreshold {
            if activeSeconds > 0 {
                logger.notice("Idle reset — user idle \(Int(self.activityMonitor.idleSeconds))s, resetting \(Int(self.activeSeconds))s accumulated")
            }
            activeSeconds = 0
            return
        }

        // Only accumulate while the user is actively at the computer.
        guard activityMonitor.isActivelyUsing else { return }
        activeSeconds += elapsed

        if activeSeconds >= reminderInterval {
            logger.notice("Reminder fired — \(Int(self.activeSeconds))s active")
            activeSeconds = 0
            isPaused = true
            onReminder()
        }
    }
}
