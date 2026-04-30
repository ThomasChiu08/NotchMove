//
//  ReminderEngine.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import Foundation
import Observation
import OSLog

protocol IdleTimeProviding: AnyObject {
    var idleSeconds: TimeInterval { get }
}

protocol SoundPlaying {
    func playReminderSound()
}

protocol Clock {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}

struct SystemClock: Clock {
    var now: Date { .now }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

struct ReminderState: Equatable {
    enum PresentationPhase: Equatable {
        case hidden
        case hoverPreview
        case presenting
        case dismissAnimating
    }

    var presentation: PresentationPhase = .hidden
    var activeSeconds: TimeInterval = 0
    var manualPause = false
    var scheduleState: SchedulePolicy.Evaluation = .disabled
    var reminderStartDate: Date = .distantPast
}

@MainActor
@Observable
final class ReminderEngine {
    struct OverlayState: Equatable {
        var presentation: ReminderState.PresentationPhase = .hidden
        var reminderStartDate: Date = .distantPast
        var reminderDuration: TimeInterval = TimeInterval(Preferences.defaults.autoDismissSeconds)
    }

    enum RunState: Equatable {
        case tracking
        case manuallyPaused
        case scheduleBlocked
        case presentingReminder
        case idleSuppressed
    }

    enum Intent: Equatable {
        case tick(Date)
        case hoverChanged(Bool)
        case setManualPause(Bool)
        case manualTrigger
        case completeBreak
        case dismissReminder
        case autoDismiss
        case cancelReminder
    }

    private let activityMonitor: IdleTimeProviding
    private let preferencesStore: PreferencesStore
    private let soundPlayer: SoundPlaying
    private let breakStatsStore: BreakStatsStore
    private let clock: Clock
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "reminder-engine")

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var autoDismissTask: Task<Void, Never>?
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var preferencesObserver: NSObjectProtocol?
    private var lastTickDate: Date?

    private(set) var state = ReminderState()
    private(set) var overlayState = OverlayState()

    deinit {
        tickTask?.cancel()
        autoDismissTask?.cancel()
        settleTask?.cancel()
        if let observer = preferencesObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    init(
        activityMonitor: IdleTimeProviding,
        preferencesStore: PreferencesStore,
        soundPlayer: SoundPlaying,
        breakStatsStore: BreakStatsStore,
        clock: Clock = SystemClock()
    ) {
        self.activityMonitor = activityMonitor
        self.preferencesStore = preferencesStore
        self.soundPlayer = soundPlayer
        self.breakStatsStore = breakStatsStore
        self.clock = clock

        updateReminderDuration()
        applyPreferences()
        observePreferences()
    }

    var runState: RunState {
        if isReminderPresenting {
            return .presentingReminder
        }

        if state.manualPause {
            return .manuallyPaused
        }

        if state.scheduleState.blocksAutomaticReminders {
            return .scheduleBlocked
        }

        switch activityState(for: idleResetThreshold) {
        case .active:
            return .tracking
        case .idleBelowResetThreshold, .idlePastResetThreshold:
            return .idleSuppressed
        }
    }

    var minutesRemaining: Int {
        let remaining = max(reminderInterval - state.activeSeconds, 0)
        return Int(ceil(remaining / 60))
    }

    var isReminderPresenting: Bool {
        overlayState.presentation == .presenting || overlayState.presentation == .dismissAnimating
    }

    var reminderDuration: TimeInterval {
        overlayState.reminderDuration
    }

    var reminderInterval: TimeInterval {
        TimeInterval(preferencesStore.preferences.reminderIntervalMinutes) * 60
    }

    var idleResetThreshold: TimeInterval {
        preferencesStore.preferences.sitAwareEnabled ? 180 : .greatestFiniteMagnitude
    }

    func start() {
        lastTickDate = clock.now
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await self.clock.sleep(for: .seconds(5))
                await MainActor.run {
                    self.send(.tick(self.clock.now))
                }
            }
        }

        logger.notice("Reminder engine started — interval=\(self.reminderInterval)s, idleReset=\(self.idleResetThreshold)s")
    }

    func send(_ intent: Intent) {
        switch intent {
        case let .tick(now):
            handleTick(now: now)
        case let .hoverChanged(hovering):
            handleHoverChange(hovering)
        case let .setManualPause(paused):
            handleManualPauseChange(paused)
        case .manualTrigger:
            beginReminderPresentation(playSound: true)
        case .completeBreak:
            finishReminder(with: .completedBreak)
        case .dismissReminder:
            finishReminder(with: .dismissed)
        case .autoDismiss:
            finishReminder(with: .autoDismissed)
        case .cancelReminder:
            finishReminder(with: .cancelled, animated: false)
        }
    }

    private func handleTick(now: Date) {
        state.scheduleState = currentScheduleState(at: now)

        if state.scheduleState.blocksAutomaticReminders {
            if state.activeSeconds > 0 {
                state.activeSeconds = 0
            }

            if isReminderPresenting {
                send(.cancelReminder)
            }

            lastTickDate = now
            return
        }

        guard !state.manualPause, !isReminderPresenting else {
            lastTickDate = now
            return
        }

        let elapsed = lastTickDate.map { now.timeIntervalSince($0) } ?? 5
        lastTickDate = now

        switch activityState(for: idleResetThreshold) {
        case .idlePastResetThreshold:
            if state.activeSeconds > 0 {
                logger.notice("Idle reset — user idle \(Int(self.activityMonitor.idleSeconds))s, resetting \(Int(self.state.activeSeconds))s accumulated")
            }
            state.activeSeconds = 0
        case .idleBelowResetThreshold:
            break
        case .active:
            state.activeSeconds += elapsed
        }

        if state.activeSeconds >= reminderInterval {
            logger.notice("Reminder fired — \(Int(self.state.activeSeconds))s active")
            beginReminderPresentation(playSound: true)
        }
    }

    private func handleHoverChange(_ hovering: Bool) {
        if hovering {
            guard overlayState.presentation == .hidden, preferencesStore.preferences.hoverPreviewEnabled else { return }
            updatePresentation(.hoverPreview)
            return
        }

        guard overlayState.presentation == .hoverPreview else { return }
        updatePresentation(.hidden)
    }

    private func handleManualPauseChange(_ paused: Bool) {
        guard state.manualPause != paused else { return }
        state.manualPause = paused
        lastTickDate = clock.now

        if paused {
            if isReminderPresenting {
                send(.cancelReminder)
            } else if overlayState.presentation == .hoverPreview {
                updatePresentation(.hidden)
            }
        }

        logger.notice("Manual pause \(paused ? "enabled" : "disabled")")
    }

    private func beginReminderPresentation(playSound: Bool) {
        autoDismissTask?.cancel()
        settleTask?.cancel()

        state.activeSeconds = 0
        updatePresentation(.presenting)
        updateReminderStartDate(clock.now)
        lastTickDate = clock.now

        if playSound {
            soundPlayer.playReminderSound()
        }

        scheduleAutoDismiss()
        logger.notice("Reminder presentation began")
    }

    private func finishReminder(with outcome: ReminderOutcome, animated: Bool = true) {
        guard isReminderPresenting else {
            if overlayState.presentation == .hoverPreview {
                updatePresentation(.hidden)
            }
            return
        }

        autoDismissTask?.cancel()
        autoDismissTask = nil
        settleTask?.cancel()
        settleTask = nil

        guard animated else {
            finalizeReminder(with: outcome)
            return
        }

        updatePresentation(.dismissAnimating)
        settleTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.finalizeReminder(with: outcome)
            }
        }
    }

    private func finalizeReminder(with outcome: ReminderOutcome) {
        settleTask = nil
        updatePresentation(.hidden)
        lastTickDate = clock.now
        breakStatsStore.recordIfCompleted(outcome)
        logger.notice("Reminder presentation finished with \(String(describing: outcome), privacy: .public)")
    }

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        guard overlayState.reminderDuration > 0, preferencesStore.preferences.autoDismissEnabled else { return }

        let elapsed = max(clock.now.timeIntervalSince(overlayState.reminderStartDate), 0)
        let remaining = max(overlayState.reminderDuration - elapsed, 0)

        guard remaining > 0 else {
            send(.autoDismiss)
            return
        }

        autoDismissTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.send(.autoDismiss)
            }
        }
    }

    private func applyPreferences() {
        updateReminderDuration()
        state.scheduleState = currentScheduleState(at: clock.now)

        if !preferencesStore.preferences.hoverPreviewEnabled, overlayState.presentation == .hoverPreview {
            updatePresentation(.hidden)
        }

        if state.scheduleState.blocksAutomaticReminders {
            state.activeSeconds = 0
            if isReminderPresenting {
                send(.cancelReminder)
            }
        }

        if isReminderPresenting {
            scheduleAutoDismiss()
        }
    }

    private func observePreferences() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: PreferencesStore.reminderRuntimeDidChangeNotification,
            object: preferencesStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyPreferences()
            }
        }
    }

    private func updatePresentation(_ presentation: ReminderState.PresentationPhase) {
        guard overlayState.presentation != presentation || state.presentation != presentation else { return }
        state.presentation = presentation
        overlayState.presentation = presentation
    }

    private func updateReminderStartDate(_ date: Date) {
        guard overlayState.reminderStartDate != date || state.reminderStartDate != date else { return }
        state.reminderStartDate = date
        overlayState.reminderStartDate = date
    }

    private func updateReminderDuration() {
        let duration = TimeInterval(preferencesStore.preferences.autoDismissSeconds)
        guard overlayState.reminderDuration != duration else { return }
        overlayState.reminderDuration = duration
    }

    private func currentScheduleState(at date: Date) -> SchedulePolicy.Evaluation {
        SchedulePolicy.evaluate(preferencesStore.preferences.schedule, at: date)
    }

    private func activityState(for resetThreshold: TimeInterval) -> ActivityState {
        if activityMonitor.idleSeconds < 180 {
            return .active
        }

        if activityMonitor.idleSeconds >= resetThreshold {
            return .idlePastResetThreshold
        }

        return .idleBelowResetThreshold
    }

    private enum ActivityState: Equatable {
        case active
        case idleBelowResetThreshold
        case idlePastResetThreshold
    }
}
