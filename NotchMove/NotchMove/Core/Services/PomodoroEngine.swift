//
//  PomodoroEngine.swift
//  NotchMove
//
//  Created by Codex on 6/2/26.
//

import Foundation
import Observation
import OSLog

enum PomodoroPhase: Equatable {
    case focus
    case rest
}

enum PomodoroRunState: Equatable {
    case idle
    case running
    case paused
}

struct PomodoroState: Equatable {
    var runState: PomodoroRunState = .idle
    var phase: PomodoroPhase = .focus
    var phaseStartDate: Date = .distantPast
    var phaseEndDate: Date = .distantPast
    var remainingSeconds: Int = 0
}

struct PomodoroReminderContent: Equatable {
    enum Kind: Equatable {
        case focusCompleted
        case breakCompleted
    }

    let kind: Kind
    let completedAt: Date
    let nextPhaseDuration: TimeInterval
}

@MainActor
@Observable
final class PomodoroEngine {
    private let preferencesStore: PreferencesStore
    private let breakStatsStore: BreakStatsStore
    private let clock: Clock
    private let onReminder: (PomodoroReminderContent) -> Void
    private let onSuppressionChanged: (Bool) -> Void
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "pomodoro")

    @ObservationIgnored private var tickTask: Task<Void, Never>?

    private(set) var state = PomodoroState()

    init(
        preferencesStore: PreferencesStore,
        breakStatsStore: BreakStatsStore,
        clock: Clock = SystemClock(),
        onReminder: @escaping (PomodoroReminderContent) -> Void = { _ in },
        onSuppressionChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.preferencesStore = preferencesStore
        self.breakStatsStore = breakStatsStore
        self.clock = clock
        self.onReminder = onReminder
        self.onSuppressionChanged = onSuppressionChanged
    }

    deinit {
        tickTask?.cancel()
    }

    var isActive: Bool {
        state.runState != .idle
    }

    var isRunning: Bool {
        state.runState == .running
    }

    var isPaused: Bool {
        state.runState == .paused
    }

    var focusDuration: TimeInterval {
        duration(minutes: preferencesStore.preferences.pomodoroFocusMinutes)
    }

    var breakDuration: TimeInterval {
        duration(minutes: preferencesStore.preferences.pomodoroBreakMinutes)
    }

    func startFocusSession() {
        guard !isActive else { return }
        onSuppressionChanged(true)
        beginPhase(.focus, duration: focusDuration, at: clock.now)
        logger.notice("Pomodoro focus session started")
    }

    func pause() {
        guard state.runState == .running else { return }
        updateRemainingSeconds(at: clock.now)
        state.runState = .paused
        tickTask?.cancel()
        tickTask = nil
        onSuppressionChanged(true)
        logger.notice("Pomodoro paused with \(self.state.remainingSeconds)s remaining")
    }

    func resume() {
        guard state.runState == .paused else { return }
        let now = clock.now
        state.runState = .running
        state.phaseStartDate = now
        state.phaseEndDate = now.addingTimeInterval(TimeInterval(max(state.remainingSeconds, 1)))
        onSuppressionChanged(true)
        startTicking()
        logger.notice("Pomodoro resumed")
    }

    func stop() {
        guard isActive else { return }
        resetState()
        onSuppressionChanged(false)
        logger.notice("Pomodoro stopped")
    }

    private func beginPhase(_ phase: PomodoroPhase, duration: TimeInterval, at date: Date) {
        let safeDuration = max(duration, 60)
        state = PomodoroState(
            runState: .running,
            phase: phase,
            phaseStartDate: date,
            phaseEndDate: date.addingTimeInterval(safeDuration),
            remainingSeconds: Int(ceil(safeDuration))
        )
        startTicking()
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await self.clock.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.handleTick(at: self.clock.now)
                }
            }
        }
    }

    private func handleTick(at date: Date) {
        guard state.runState == .running else { return }
        updateRemainingSeconds(at: date)

        guard state.remainingSeconds <= 0 else { return }
        completeCurrentPhase(at: date)
    }

    private func updateRemainingSeconds(at date: Date) {
        let remaining = max(state.phaseEndDate.timeIntervalSince(date), 0)
        state.remainingSeconds = Int(ceil(remaining))
    }

    private func completeCurrentPhase(at date: Date) {
        switch state.phase {
        case .focus:
            onReminder(PomodoroReminderContent(
                kind: .focusCompleted,
                completedAt: date,
                nextPhaseDuration: breakDuration
            ))
            beginPhase(.rest, duration: breakDuration, at: date)
            logger.notice("Pomodoro focus completed; break started")
        case .rest:
            breakStatsStore.recordIfCompleted(.completedBreak)
            onReminder(PomodoroReminderContent(
                kind: .breakCompleted,
                completedAt: date,
                nextPhaseDuration: focusDuration
            ))
            resetState()
            onSuppressionChanged(false)
            logger.notice("Pomodoro break completed")
        }
    }

    private func resetState() {
        tickTask?.cancel()
        tickTask = nil
        state = PomodoroState()
    }

    private func duration(minutes: Int) -> TimeInterval {
        TimeInterval(max(minutes, 1)) * 60
    }
}
