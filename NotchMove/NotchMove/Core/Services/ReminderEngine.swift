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

enum ReminderSoundCue: Equatable {
    case breakReminder
    case scheduleReminder
    case pomodoro
}

protocol SoundPlaying {
    func playSound(_ cue: ReminderSoundCue)
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
        case reminderPending
        case hoverPreviewPending
        case hoverPreview
        case hoverPreviewDismissing
        case presenting
        case dismissAnimating
    }

    var presentation: PresentationPhase = .hidden
    var activeSeconds: TimeInterval = 0
    var manualPause = false
    var scheduleState: SchedulePolicy.Evaluation = .disabled
    var reminderStartDate: Date = .distantPast
    var breakSnoozedUntilDate: Date?
}

@MainActor
@Observable
final class ReminderEngine {
    static let reminderPresentationPreflightDelay: Duration = .milliseconds(90)
    static let hoverPreviewPromotionDelay: Duration = .milliseconds(70)
    static let hoverPreviewDismissalDelay: Duration = .milliseconds(240)
    static let reminderDismissSettleDelay: Duration = .milliseconds(380)

    struct ScheduleReminderContent: Equatable {
        let id: DailyScheduleItem.ID
        let title: String
        let startDate: Date
        let endDate: Date?

        init(item: DailyScheduleItem) {
            id = item.id
            title = item.title
            startDate = item.startDate
            endDate = item.endDate
        }
    }

    struct BreakCompletionCountdownContent: Equatable {
        let startedAt: Date
        let duration: TimeInterval
    }

    enum OverlayContent: Equatable {
        case breakReminder
        case breakCompletionCountdown(BreakCompletionCountdownContent)
        case schedule(ScheduleReminderContent)
        case pomodoro(PomodoroReminderContent)
        case pomodoroCountdown(PomodoroCountdownContent)
    }

    struct OverlayState: Equatable {
        var presentation: ReminderState.PresentationPhase = .hidden
        var reminderStartDate: Date = .distantPast
        var reminderDuration: TimeInterval = TimeInterval(Preferences.defaults.autoDismissSeconds)
        var content: OverlayContent = .breakReminder
    }

    struct NextReminderPreview: Equatable {
        let breakRow: Row
        let pomodoroRow: Row

        struct Row: Equatable {
            enum Mode: Equatable {
                case breakReminder
                case pomodoro
            }

            enum Status: Equatable {
                case scheduled(targetDate: Date, remainingSeconds: Int)
                case snoozed(targetDate: Date, remainingSeconds: Int)
                case paused(remainingSeconds: Int?)
                case disabled
                case idle
                case scheduleBlocked
                case idleSuppressed
            }

            let mode: Mode
            let status: Status
            let phase: PomodoroPhase?
        }
    }

    enum RunState: Equatable {
        case tracking
        case manuallyPaused
        case breakRemindersDisabled
        case scheduleBlocked
        case pomodoroActive
        case presentingReminder
        case idleSuppressed
    }

    enum Intent: Equatable {
        case tick(Date)
        case hoverChanged(Bool)
        case setManualPause(Bool)
        case manualTrigger
        case completeBreak
        case snoozeReminder(duration: TimeInterval)
        case dismissReminder
        case autoDismiss
        case cancelReminder
        case scheduleTrigger(ScheduleReminderContent)
        case completeScheduleReminder
        case snoozeScheduleReminder(minutes: Int)
        case dismissScheduleReminder
        case pomodoroTrigger(PomodoroReminderContent)
        case pomodoroCountdownChanged(PomodoroCountdownContent?)
        case dismissPomodoroReminder
    }

    private let activityMonitor: IdleTimeProviding
    private let preferencesStore: PreferencesStore
    private let soundPlayer: SoundPlaying
    private let breakStatsStore: BreakStatsStore
    private let clock: Clock
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "reminder-engine")

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var autoDismissTask: Task<Void, Never>?
    @ObservationIgnored private var presentationTask: Task<Void, Never>?
    @ObservationIgnored private var hoverPreviewTask: Task<Void, Never>?
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var breakCompletionCountdownTask: Task<Void, Never>?
    @ObservationIgnored private var pomodoroCountdownTuckTask: Task<Void, Never>?
    @ObservationIgnored private var activeScheduleActions: DailyScheduleReminderActions?
    @ObservationIgnored private nonisolated(unsafe) var preferencesObserver: NSObjectProtocol?
    private var lastTickDate: Date?
    private var activePomodoroCountdownContent: PomodoroCountdownContent?

    private(set) var state = ReminderState()
    private(set) var overlayState = OverlayState()

    deinit {
        tickTask?.cancel()
        autoDismissTask?.cancel()
        presentationTask?.cancel()
        hoverPreviewTask?.cancel()
        settleTask?.cancel()
        breakCompletionCountdownTask?.cancel()
        pomodoroCountdownTuckTask?.cancel()
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

        if activePomodoroCountdownContent != nil {
            return .pomodoroActive
        }

        if !preferencesStore.preferences.breakReminderEnabled {
            return .breakRemindersDisabled
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
        overlayState.presentation == .reminderPending ||
            overlayState.presentation == .presenting ||
            overlayState.presentation == .dismissAnimating
    }

    var isBreakReminderPresenting: Bool {
        isReminderPresenting && overlayState.content == .breakReminder
    }

    var isBreakCompletionCountdownActive: Bool {
        if case .breakCompletionCountdown = overlayState.content {
            return true
        }

        return false
    }

    var isPomodoroCountdownActive: Bool {
        activePomodoroCountdownContent != nil
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

    func nextReminderPreview(at date: Date) -> NextReminderPreview {
        NextReminderPreview(
            breakRow: nextBreakPreview(at: date),
            pomodoroRow: nextPomodoroPreview(at: date)
        )
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

    func presentScheduleReminder(for item: DailyScheduleItem, actions: DailyScheduleReminderActions) {
        activeScheduleActions = actions
        send(.scheduleTrigger(ScheduleReminderContent(item: item)))
    }

    func presentPomodoroReminder(_ content: PomodoroReminderContent) {
        send(.pomodoroTrigger(content))
    }

    func updatePomodoroCountdown(_ content: PomodoroCountdownContent?) {
        send(.pomodoroCountdownChanged(content))
    }

    func snoozeReminder(duration: TimeInterval) {
        send(.snoozeReminder(duration: duration))
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
            if preferencesStore.preferences.breakReminderEnabled {
                beginBreakReminderPresentation(soundCue: .breakReminder)
            }
        case .completeBreak:
            beginBreakCompletionCountdown()
        case .snoozeReminder(let duration):
            snoozeBreakReminder(duration: duration)
        case .dismissReminder:
            finishReminder(with: .dismissed)
        case .autoDismiss:
            handleAutoDismiss()
        case .cancelReminder:
            finishReminder(with: .cancelled, animated: false)
        case .scheduleTrigger(let content):
            beginScheduleReminderPresentation(content)
        case .completeScheduleReminder:
            finishActiveScheduleReminder { actions in
                actions.complete()
            }
        case .snoozeScheduleReminder(let minutes):
            finishActiveScheduleReminder { actions in
                actions.snooze(minutes)
            }
        case .dismissScheduleReminder:
            finishActiveScheduleReminder { actions in
                actions.dismiss()
            }
        case .pomodoroTrigger(let content):
            beginPomodoroReminderPresentation(content)
        case .pomodoroCountdownChanged(let content):
            handlePomodoroCountdownChange(content)
        case .dismissPomodoroReminder:
            finishReminder(with: .dismissed)
        }
    }

    private func handleTick(now: Date) {
        state.scheduleState = currentScheduleState(at: now)

        if state.scheduleState.blocksAutomaticReminders {
            if state.activeSeconds > 0 {
                state.activeSeconds = 0
            }
            state.breakSnoozedUntilDate = nil

            if isBreakReminderPresenting {
                send(.cancelReminder)
            }

            clearBreakCompletionCountdown()

            lastTickDate = now
            return
        }

        if !preferencesStore.preferences.breakReminderEnabled {
            if state.activeSeconds > 0 {
                state.activeSeconds = 0
            }
            state.breakSnoozedUntilDate = nil

            if isBreakReminderPresenting {
                send(.cancelReminder)
            }

            clearBreakCompletionCountdown()

            lastTickDate = now
            return
        }

        guard !state.manualPause, !isReminderPresenting else {
            lastTickDate = now
            return
        }

        if let breakSnoozedUntilDate = state.breakSnoozedUntilDate {
            if now < breakSnoozedUntilDate {
                lastTickDate = now
                return
            }

            state.breakSnoozedUntilDate = nil
            if activityState(for: idleResetThreshold) == .active {
                logger.notice("Break reminder snooze expired")
                beginBreakReminderPresentation(soundCue: .breakReminder)
                return
            }
        }

        if isBreakCompletionCountdownActive {
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
            beginBreakReminderPresentation(soundCue: .breakReminder)
        }
    }

    private func nextBreakPreview(at date: Date) -> NextReminderPreview.Row {
        guard preferencesStore.preferences.breakReminderEnabled else {
            return NextReminderPreview.Row(mode: .breakReminder, status: .disabled, phase: nil)
        }

        if state.manualPause {
            return NextReminderPreview.Row(mode: .breakReminder, status: .paused(remainingSeconds: nil), phase: nil)
        }

        if currentScheduleState(at: date).blocksAutomaticReminders {
            return NextReminderPreview.Row(mode: .breakReminder, status: .scheduleBlocked, phase: nil)
        }

        if let snoozedUntilDate = state.breakSnoozedUntilDate,
           date < snoozedUntilDate {
            return NextReminderPreview.Row(
                mode: .breakReminder,
                status: .snoozed(
                    targetDate: snoozedUntilDate,
                    remainingSeconds: safeRemainingSeconds(until: snoozedUntilDate, at: date)
                ),
                phase: nil
            )
        }

        guard activityState(for: idleResetThreshold) == .active else {
            return NextReminderPreview.Row(mode: .breakReminder, status: .idleSuppressed, phase: nil)
        }

        let remaining = max(reminderInterval - state.activeSeconds, 0)
        let targetDate = date.addingTimeInterval(remaining)
        return NextReminderPreview.Row(
            mode: .breakReminder,
            status: .scheduled(
                targetDate: targetDate,
                remainingSeconds: Int(ceil(remaining))
            ),
            phase: nil
        )
    }

    private func nextPomodoroPreview(at date: Date) -> NextReminderPreview.Row {
        guard preferencesStore.preferences.pomodoroEnabled else {
            return NextReminderPreview.Row(mode: .pomodoro, status: .disabled, phase: nil)
        }

        guard let content = activePomodoroCountdownContent else {
            return NextReminderPreview.Row(mode: .pomodoro, status: .idle, phase: nil)
        }

        if let pausedRemainingSeconds = content.pausedRemainingSeconds {
            return NextReminderPreview.Row(
                mode: .pomodoro,
                status: .paused(remainingSeconds: max(pausedRemainingSeconds, 0)),
                phase: content.phase
            )
        }

        let remaining = pomodoroRemainingSeconds(at: date, content: content)
        return NextReminderPreview.Row(
            mode: .pomodoro,
            status: .scheduled(
                targetDate: date.addingTimeInterval(TimeInterval(remaining)),
                remainingSeconds: remaining
            ),
            phase: content.phase
        )
    }

    private func pomodoroRemainingSeconds(at date: Date, content: PomodoroCountdownContent) -> Int {
        let elapsed = max(date.timeIntervalSince(content.startedAt), 0)
        return max(Int(ceil(content.duration - elapsed)), 0)
    }

    private func safeRemainingSeconds(until targetDate: Date, at date: Date) -> Int {
        max(Int(ceil(targetDate.timeIntervalSince(date))), 0)
    }

    private func handleHoverChange(_ hovering: Bool) {
        if hovering {
            if overlayState.presentation == .reminderPending {
                promotePendingReminder()
            } else if overlayState.presentation == .hoverPreviewDismissing {
                hoverPreviewTask?.cancel()
                hoverPreviewTask = nil
                updatePresentation(.hoverPreview)
            } else if overlayState.presentation == .hidden,
                      isPersistentCountdownActive || preferencesStore.preferences.hoverPreviewEnabled {
                beginHoverPreview()
            }
            return
        }

        switch overlayState.presentation {
        case .hoverPreviewPending:
            hoverPreviewTask?.cancel()
            hoverPreviewTask = nil
            updatePresentation(.hidden)
        case .hoverPreview:
            dismissHoverPreview()
        default:
            break
        }
    }

    private func handleManualPauseChange(_ paused: Bool) {
        guard state.manualPause != paused else { return }
        state.manualPause = paused
        lastTickDate = clock.now

        if paused {
            if isBreakReminderPresenting {
                send(.cancelReminder)
            } else if isHoverPreviewActive {
                hideHoverPreviewImmediately()
            }
            state.breakSnoozedUntilDate = nil
            clearBreakCompletionCountdown()
        }

        logger.notice("Manual pause \(paused ? "enabled" : "disabled")")
    }

    private func beginBreakReminderPresentation(soundCue: ReminderSoundCue?) {
        guard preferencesStore.preferences.breakReminderEnabled else { return }
        guard overlayState.content == .breakReminder || !isReminderPresenting else { return }
        state.breakSnoozedUntilDate = nil
        beginReminderPresentation(content: .breakReminder, soundCue: soundCue, resetActiveSeconds: true)
        logger.notice("Reminder presentation began")
    }

    private func beginBreakCompletionCountdown() {
        guard isBreakReminderPresenting else {
            finishReminder(with: .completedBreak)
            return
        }

        let now = clock.now
        let elapsed = max(now.timeIntervalSince(overlayState.reminderStartDate), 0)
        let remaining = max(overlayState.reminderDuration - elapsed, 1)
        let content = BreakCompletionCountdownContent(startedAt: now, duration: remaining)

        autoDismissTask?.cancel()
        autoDismissTask = nil
        presentationTask?.cancel()
        presentationTask = nil
        hoverPreviewTask?.cancel()
        hoverPreviewTask = nil
        settleTask?.cancel()
        settleTask = nil
        breakCompletionCountdownTask?.cancel()

        state.breakSnoozedUntilDate = nil
        updateContent(.breakCompletionCountdown(content))
        updatePresentation(.hidden)
        lastTickDate = now
        breakStatsStore.recordIfCompleted(.completedBreak)
        scheduleBreakCompletionCountdownClear(for: content)
        logger.notice("Break completion countdown began for \(Int(remaining))s")
    }

    private func snoozeBreakReminder(duration: TimeInterval) {
        guard isBreakReminderPresenting else {
            finishReminder(with: .dismissed)
            return
        }

        let safeDuration = max(duration, 60)
        state.breakSnoozedUntilDate = clock.now.addingTimeInterval(safeDuration)
        finishReminder(with: .dismissed)
        logger.notice("Break reminder snoozed for \(Int(safeDuration))s")
    }

    private func beginScheduleReminderPresentation(_ content: ScheduleReminderContent) {
        beginReminderPresentation(content: .schedule(content), soundCue: nil, resetActiveSeconds: false)
        logger.notice("Schedule reminder presentation began for \(content.title, privacy: .public)")
    }

    private func beginPomodoroReminderPresentation(_ content: PomodoroReminderContent) {
        guard !isReminderPresenting || isPomodoroReminderPresenting else {
            logger.notice("Skipped pomodoro reminder because another reminder is presenting")
            return
        }

        let soundCue: ReminderSoundCue? = content.kind == .sessionStarted ? nil : .pomodoro
        beginReminderPresentation(content: .pomodoro(content), soundCue: soundCue, resetActiveSeconds: false)
        logger.notice("Pomodoro reminder presentation began")
    }

    private func handlePomodoroCountdownChange(_ content: PomodoroCountdownContent?) {
        activePomodoroCountdownContent = content
        pomodoroCountdownTuckTask?.cancel()
        pomodoroCountdownTuckTask = nil

        guard let content else {
            if case .pomodoroCountdown = overlayState.content {
                updatePresentation(.hidden)
                updateContent(.breakReminder)
            }
            return
        }

        guard !isReminderPresenting else { return }

        updateContent(.pomodoroCountdown(content))

        if overlayState.presentation == .hidden || isHoverPreviewActive {
            updatePresentation(.hoverPreview)
            schedulePomodoroCountdownTuck()
        }
    }

    private func beginReminderPresentation(
        content: OverlayContent,
        soundCue: ReminderSoundCue?,
        resetActiveSeconds: Bool
    ) {
        autoDismissTask?.cancel()
        presentationTask?.cancel()
        hoverPreviewTask?.cancel()
        hoverPreviewTask = nil
        settleTask?.cancel()
        pomodoroCountdownTuckTask?.cancel()
        pomodoroCountdownTuckTask = nil
        breakCompletionCountdownTask?.cancel()
        breakCompletionCountdownTask = nil

        if resetActiveSeconds {
            state.activeSeconds = 0
        }
        updateContent(content)
        updateReminderStartDate(clock.now)
        updatePresentation(.reminderPending)
        lastTickDate = clock.now

        if let soundCue {
            soundPlayer.playSound(soundCue)
        }

        schedulePendingPromotion()
    }

    private func schedulePendingPromotion() {
        presentationTask?.cancel()
        presentationTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: Self.reminderPresentationPreflightDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.promotePendingReminder()
            }
        }
    }

    private func promotePendingReminder() {
        guard overlayState.presentation == .reminderPending else { return }
        presentationTask?.cancel()
        presentationTask = nil
        updatePresentation(.presenting)
        scheduleAutoDismiss()
    }

    private func handleAutoDismiss() {
        if case .schedule = overlayState.content {
            activeScheduleActions?.dismiss()
        }

        finishReminder(with: .autoDismissed)
    }

    private func finishActiveScheduleReminder(
        action: (DailyScheduleReminderActions) -> Void
    ) {
        guard case .schedule = overlayState.content,
              let activeScheduleActions
        else {
            finishReminder(with: .dismissed)
            return
        }

        action(activeScheduleActions)
        finishReminder(with: .dismissed)
    }

    private func finishReminder(with outcome: ReminderOutcome, animated: Bool = true) {
        guard isReminderPresenting else {
            if isHoverPreviewActive {
                hideHoverPreviewImmediately()
            }
            if isBreakCompletionCountdownActive {
                clearBreakCompletionCountdown()
            }
            return
        }

        autoDismissTask?.cancel()
        autoDismissTask = nil
        presentationTask?.cancel()
        presentationTask = nil
        hoverPreviewTask?.cancel()
        hoverPreviewTask = nil
        settleTask?.cancel()
        settleTask = nil

        guard animated else {
            finalizeReminder(with: outcome)
            return
        }

        updatePresentation(.dismissAnimating)
        settleTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: Self.reminderDismissSettleDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.finalizeReminder(with: outcome)
            }
        }
    }

    private func finalizeReminder(with outcome: ReminderOutcome) {
        presentationTask?.cancel()
        presentationTask = nil
        hoverPreviewTask?.cancel()
        hoverPreviewTask = nil
        settleTask = nil
        updatePresentation(.hidden)

        if case .schedule = overlayState.content {
            activeScheduleActions = nil
        }

        if let activePomodoroCountdownContent {
            updateContent(.pomodoroCountdown(activePomodoroCountdownContent))
        } else if overlayState.content != .breakReminder {
            updateContent(.breakReminder)
        }
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

        if !preferencesStore.preferences.hoverPreviewEnabled,
           isHoverPreviewActive,
           !isPersistentCountdownActive {
            hideHoverPreviewImmediately()
        }

        if state.scheduleState.blocksAutomaticReminders || !preferencesStore.preferences.breakReminderEnabled {
            state.activeSeconds = 0
            state.breakSnoozedUntilDate = nil
            if isBreakReminderPresenting {
                send(.cancelReminder)
            }
            clearBreakCompletionCountdown()
        }

        if overlayState.presentation == .presenting {
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

    private var isHoverPreviewActive: Bool {
        overlayState.presentation == .hoverPreviewPending ||
            overlayState.presentation == .hoverPreview ||
            overlayState.presentation == .hoverPreviewDismissing
    }

    private var isPersistentCountdownActive: Bool {
        isBreakCompletionCountdownActive || activePomodoroCountdownContent != nil
    }

    private var isPomodoroReminderPresenting: Bool {
        guard isReminderPresenting,
              case .pomodoro = overlayState.content
        else {
            return false
        }

        return true
    }

    private func beginHoverPreview() {
        hoverPreviewTask?.cancel()
        updatePresentation(.hoverPreviewPending)
        hoverPreviewTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: Self.hoverPreviewPromotionDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.overlayState.presentation == .hoverPreviewPending else { return }
                self.hoverPreviewTask = nil
                self.updatePresentation(.hoverPreview)
            }
        }
    }

    private func dismissHoverPreview() {
        hoverPreviewTask?.cancel()
        updatePresentation(.hoverPreviewDismissing)
        hoverPreviewTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: Self.hoverPreviewDismissalDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.overlayState.presentation == .hoverPreviewDismissing else { return }
                self.hoverPreviewTask = nil
                self.updatePresentation(.hidden)
            }
        }
    }

    private func hideHoverPreviewImmediately() {
        hoverPreviewTask?.cancel()
        hoverPreviewTask = nil
        updatePresentation(.hidden)
    }

    private func schedulePomodoroCountdownTuck() {
        pomodoroCountdownTuckTask?.cancel()
        pomodoroCountdownTuckTask = nil

        guard preferencesStore.preferences.autoDismissEnabled else { return }

        let delay = max(TimeInterval(preferencesStore.preferences.autoDismissSeconds), 1)
        pomodoroCountdownTuckTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard case .pomodoroCountdown = self.overlayState.content,
                      self.overlayState.presentation == .hoverPreview
                else {
                    return
                }

                self.pomodoroCountdownTuckTask = nil
                self.updatePresentation(.hidden)
            }
        }
    }

    private func scheduleBreakCompletionCountdownClear(for content: BreakCompletionCountdownContent) {
        breakCompletionCountdownTask = Task { [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: .seconds(content.duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.clearBreakCompletionCountdown(matching: content)
            }
        }
    }

    private func clearBreakCompletionCountdown(matching expectedContent: BreakCompletionCountdownContent? = nil) {
        if let expectedContent {
            guard case .breakCompletionCountdown(let content) = overlayState.content,
                  content == expectedContent
            else {
                return
            }
        } else if !isBreakCompletionCountdownActive {
            return
        }

        breakCompletionCountdownTask?.cancel()
        breakCompletionCountdownTask = nil
        hoverPreviewTask?.cancel()
        hoverPreviewTask = nil
        updatePresentation(.hidden)
        if let activePomodoroCountdownContent {
            updateContent(.pomodoroCountdown(activePomodoroCountdownContent))
        } else {
            updateContent(.breakReminder)
        }
        lastTickDate = clock.now
        logger.notice("Break completion countdown cleared")
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

    private func updateContent(_ content: OverlayContent) {
        guard overlayState.content != content else { return }
        overlayState.content = content
    }

    private func currentScheduleState(at date: Date) -> SchedulePolicy.Evaluation {
        SchedulePolicy.evaluate(preferencesStore.preferences.schedule, at: date)
    }

    private func activityState(for resetThreshold: TimeInterval) -> ActivityState {
        guard resetThreshold < .greatestFiniteMagnitude else {
            return .active
        }

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
