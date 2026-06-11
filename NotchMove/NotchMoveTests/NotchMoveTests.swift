///
//  NotchMoveTests.swift
//  NotchMoveTests
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import NotchMove

@MainActor
struct SchedulePolicyTests {
    @Test func disabledScheduleDoesNotBlockAutomaticReminders() {
        let schedule = Preferences.Schedule(
            isEnabled: false,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: true
        )

        #expect(
            SchedulePolicy.evaluate(
                schedule,
                at: makeDate(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
            ) == .disabled
        )
    }

    @Test func invalidScheduleRangeIsRejectedAtRuntime() {
        let schedule = Preferences.Schedule(
            isEnabled: true,
            startHour: 18,
            startMinute: 0,
            endHour: 9,
            endMinute: 0,
            weekdaysOnly: false
        )

        #expect(
            SchedulePolicy.evaluate(
                schedule,
                at: makeDate(year: 2026, month: 4, day: 20, hour: 10, minute: 0)
            ) == .invalid
        )
    }

    @Test func weekdaysOnlyBlocksWeekendReminders() {
        let schedule = Preferences.Schedule(
            isEnabled: true,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: true
        )

        #expect(
            SchedulePolicy.evaluate(
                schedule,
                at: makeDate(year: 2026, month: 4, day: 19, hour: 10, minute: 0)
            ) == .blocked
        )
    }
}

@MainActor
struct StatusItemAppearanceTests {
    @Test func statusItemAppearanceUsesFixedTemplateImageAndFallbackTitle() {
        #expect(StatusItemAppearance.length == NSStatusItem.squareLength)
        #expect(StatusItemAppearance.fallbackTitle == "NM")
        #expect(StatusItemAppearance.accessibilityDescription.contains("NotchMove"))

        let image = StatusItemAppearance.makeStatusBarImage()

        #expect(image != nil)
        #expect(image?.isTemplate == true)
    }
}

@MainActor
struct PreferencesStoreTests {
    @Test func restoreDefaultsResetsLanguageAndBehavior() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let store = PreferencesStore(settings: settings)

        store.preferences.soundEnabled = false
        store.preferences.launchAtLoginEnabled = false
        store.preferences.breakReminderEnabled = false
        store.preferences.pomodoroEnabled = false
        store.preferences.reminderIntervalMinutes = 60
        store.preferences.appLanguage = "ja"
        store.preferences.overlayDisplayMode = .display(CGDirectDisplayID(42))

        store.restoreDefaults()

        #expect(store.preferences == .defaults)
        #expect(settings.loadPreferences() == .defaults)
    }

    @Test func overlayDisplayPreferencePersistsAndClearsDisplayIDWhenAutomatic() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        var preferences = settings.loadPreferences()

        #expect(preferences.overlayDisplayMode == .automatic)

        preferences.overlayDisplayMode = .display(CGDirectDisplayID(123))
        settings.save(preferences)

        #expect(settings.loadPreferences().overlayDisplayMode == .display(CGDirectDisplayID(123)))

        preferences.overlayDisplayMode = .automatic
        settings.save(preferences)

        #expect(settings.loadPreferences().overlayDisplayMode == .automatic)
        #expect(defaults.object(forKey: AppSettings.Keys.overlayDisplayID) == nil)
    }

    @Test func launchAtLoginPreferencePersists() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        var preferences = settings.loadPreferences()

        #expect(!preferences.launchAtLoginEnabled)
        #expect(!preferences.hasSeenLaunchAtLoginPrompt)

        preferences.hasSeenLaunchAtLoginPrompt = true
        preferences.launchAtLoginEnabled = false
        settings.save(preferences)

        #expect(!settings.loadPreferences().launchAtLoginEnabled)
        #expect(settings.loadPreferences().hasSeenLaunchAtLoginPrompt)

        preferences.launchAtLoginEnabled = true
        settings.save(preferences)

        #expect(settings.loadPreferences().launchAtLoginEnabled)
        #expect(settings.loadPreferences().hasSeenLaunchAtLoginPrompt)
    }

    @Test func globalHotkeyPreferenceIsOptInAndPersistsShortcut() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        var preferences = settings.loadPreferences()

        #expect(!preferences.aiGlobalHotkeyEnabled)
        #expect(preferences.aiGlobalHotkeyShortcutID == GlobalHotkeyShortcut.default.rawValue)

        preferences.aiGlobalHotkeyEnabled = true
        preferences.aiGlobalHotkeyShortcutID = GlobalHotkeyShortcut.controlOptionA.rawValue
        settings.save(preferences)

        let loaded = settings.loadPreferences()
        #expect(loaded.aiGlobalHotkeyEnabled)
        #expect(loaded.aiGlobalHotkeyShortcutID == GlobalHotkeyShortcut.controlOptionA.rawValue)
    }

    @Test func voiceInputPreferencesAreOptInAndPersist() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        var preferences = settings.loadPreferences()

        #expect(!preferences.voiceInputEnabled)
        #expect(preferences.voiceInputShortcutID == GlobalHotkeyShortcut.default.rawValue)
        #expect(preferences.voiceCleanupMode == .clean)
        #expect(preferences.voicePersonalTerms.isEmpty)

        preferences.voiceInputEnabled = true
        preferences.voiceInputShortcutID = GlobalHotkeyShortcut.controlOptionM.rawValue
        preferences.voiceCleanupMode = .polished
        preferences.voicePersonalTerms = [" NotchMove ", "notchmove", "SwiftData"]
        settings.save(preferences)

        let loaded = settings.loadPreferences()
        #expect(loaded.voiceInputEnabled)
        #expect(loaded.voiceInputShortcutID == GlobalHotkeyShortcut.controlOptionM.rawValue)
        #expect(loaded.voiceCleanupMode == .polished)
        #expect(loaded.voicePersonalTerms == ["NotchMove", "SwiftData"])
    }

    @Test func reminderModeAndPomodoroPreferencesPersistAndRestoreDefaults() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        var preferences = settings.loadPreferences()

        #expect(preferences.breakReminderEnabled)
        #expect(preferences.pomodoroEnabled)
        #expect(preferences.pomodoroFocusMinutes == 25)
        #expect(preferences.pomodoroBreakMinutes == 5)

        preferences.breakReminderEnabled = false
        preferences.pomodoroEnabled = false
        preferences.pomodoroFocusMinutes = 45
        preferences.pomodoroBreakMinutes = 10
        settings.save(preferences)

        var loaded = settings.loadPreferences()
        #expect(!loaded.breakReminderEnabled)
        #expect(!loaded.pomodoroEnabled)
        #expect(loaded.pomodoroFocusMinutes == 45)
        #expect(loaded.pomodoroBreakMinutes == 10)

        let store = PreferencesStore(settings: settings)
        store.restoreDefaults()

        loaded = settings.loadPreferences()
        #expect(loaded.breakReminderEnabled == Preferences.defaults.breakReminderEnabled)
        #expect(loaded.pomodoroEnabled == Preferences.defaults.pomodoroEnabled)
        #expect(loaded.pomodoroFocusMinutes == Preferences.defaults.pomodoroFocusMinutes)
        #expect(loaded.pomodoroBreakMinutes == Preferences.defaults.pomodoroBreakMinutes)
    }

    @Test func postsTargetedNotificationsForRelevantPreferenceChanges() async {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(settings: AppSettings(defaults: defaults))
        let notchLayoutNotifications = NotificationCounter()
        let reminderRuntimeNotifications = NotificationCounter()

        let notchObserver = NotificationCenter.default.addObserver(
            forName: PreferencesStore.notchLayoutDidChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            Task { @MainActor in
                notchLayoutNotifications.increment()
            }
        }

        let reminderObserver = NotificationCenter.default.addObserver(
            forName: PreferencesStore.reminderRuntimeDidChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            Task { @MainActor in
                reminderRuntimeNotifications.increment()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(notchObserver)
            NotificationCenter.default.removeObserver(reminderObserver)
        }

        store.preferences.notchExpansionEnabled = false
        store.preferences.appLanguage = "ja"
        store.preferences.autoDismissSeconds = 90

        await flushAsyncWork()

        #expect(notchLayoutNotifications.count == 1)
        #expect(reminderRuntimeNotifications.count == 1)
    }

    @Test func globalHotkeyPreferenceChangesPostDedicatedNotification() async {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(settings: AppSettings(defaults: defaults))
        let globalHotkeyNotifications = NotificationCounter()

        let observer = NotificationCenter.default.addObserver(
            forName: PreferencesStore.aiGlobalHotkeyDidChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            Task { @MainActor in
                globalHotkeyNotifications.increment()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        store.preferences.aiGlobalHotkeyEnabled = true
        store.preferences.aiGlobalHotkeyShortcutID = GlobalHotkeyShortcut.controlOptionA.rawValue

        await flushAsyncWork()

        #expect(globalHotkeyNotifications.count == 2)
    }

    @Test func voiceInputPreferenceChangesPostDedicatedNotification() async {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(settings: AppSettings(defaults: defaults))
        let voiceInputNotifications = NotificationCounter()

        let observer = NotificationCenter.default.addObserver(
            forName: PreferencesStore.voiceInputDidChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            Task { @MainActor in
                voiceInputNotifications.increment()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        store.preferences.voiceInputEnabled = true
        store.preferences.voiceCleanupMode = .polished
        store.preferences.voicePersonalTerms = ["NotchMove"]

        await flushAsyncWork()

        #expect(voiceInputNotifications.count == 3)
    }

    @Test func reminderRuntimePreferenceChangesPostRuntimeNotifications() async {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(settings: AppSettings(defaults: defaults))
        let reminderRuntimeNotifications = NotificationCounter()

        let observer = NotificationCenter.default.addObserver(
            forName: PreferencesStore.reminderRuntimeDidChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            Task { @MainActor in
                reminderRuntimeNotifications.increment()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        store.preferences.breakReminderEnabled = false
        store.preferences.pomodoroEnabled = false
        store.preferences.reminderIntervalMinutes = 45
        store.preferences.sitAwareEnabled = false

        await flushAsyncWork()

        #expect(reminderRuntimeNotifications.count == 4)
    }

    @Test func overlayDisplayPreferencePostsLayoutNotification() async {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(settings: AppSettings(defaults: defaults))
        let notchLayoutNotifications = NotificationCounter()

        let observer = NotificationCenter.default.addObserver(
            forName: PreferencesStore.notchLayoutDidChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            Task { @MainActor in
                notchLayoutNotifications.increment()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        store.preferences.overlayDisplayMode = .display(CGDirectDisplayID(123))

        await flushAsyncWork()

        #expect(notchLayoutNotifications.count == 1)
    }
}

@MainActor
struct BreakStatsStoreTests {
    @Test func onlyCompletedBreakOutcomesIncrementStatistics() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = BreakStatsStore(defaults: defaults)

        store.recordIfCompleted(.dismissed)
        store.recordIfCompleted(.autoDismissed)
        store.recordIfCompleted(.cancelled)
        #expect(store.todayBreaks == 0)
        #expect(store.weekBreaks == 0)

        store.recordIfCompleted(.completedBreak)
        #expect(store.todayBreaks == 1)
        #expect(store.weekBreaks == 1)
    }
}

@MainActor
struct PomodoroEngineTests {
    @Test func enabledPomodoroStartsFocusSessionAndCountdown() {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makePomodoroContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.pomodoroEnabled = true
        context.preferencesStore.preferences.pomodoroFocusMinutes = 25
        context.engine.startFocusSession()

        #expect(context.engine.state.runState == .running)
        #expect(context.engine.state.phase == .focus)
        #expect(context.engine.state.remainingSeconds == 25 * 60)
        #expect(context.probe.reminders.isEmpty)
        #expect(context.probe.countdowns.compactMap { $0?.phase } == [.focus])
        #expect(context.probe.countdowns.compactMap { $0 }.last?.duration == TimeInterval(25 * 60))
    }

    @Test func focusCompletionStartsBreakAndRequestsOverlay() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makePomodoroContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.pomodoroFocusMinutes = 1
        context.preferencesStore.preferences.pomodoroBreakMinutes = 1

        context.engine.startFocusSession()

        #expect(context.engine.state.runState == .running)
        #expect(context.engine.state.phase == .focus)
        #expect(context.probe.reminders.isEmpty)
        #expect(context.probe.countdowns.compactMap { $0?.phase } == [.focus])
        #expect(context.probe.countdowns.compactMap { $0 }.last?.duration == 60)

        await flushAsyncWork()
        await context.clock.advance(by: .seconds(60))
        await flushAsyncWork()

        #expect(context.engine.state.runState == .running)
        #expect(context.engine.state.phase == .rest)
        #expect(context.engine.state.remainingSeconds == 60)
        #expect(context.probe.reminders.map(\.kind) == [.focusCompleted])
        #expect(context.probe.reminders.last?.nextPhaseDuration == 60)
        #expect(context.probe.countdowns.compactMap { $0?.phase } == [.focus, .rest])
    }

    @Test func pauseAndResumePreserveRemainingTime() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makePomodoroContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.pomodoroFocusMinutes = 1
        context.engine.startFocusSession()

        await flushAsyncWork()
        await context.clock.advance(by: .seconds(10))
        await flushAsyncWork()
        context.engine.pause()
        let pausedRemaining = context.engine.state.remainingSeconds
        #expect(context.probe.countdowns.compactMap { $0 }.last?.pausedRemainingSeconds == pausedRemaining)

        await context.clock.advance(by: .seconds(60))
        await flushAsyncWork()

        #expect(context.engine.state.runState == .paused)
        #expect(context.engine.state.remainingSeconds == pausedRemaining)

        context.engine.resume()
        #expect(context.probe.countdowns.compactMap { $0 }.last?.pausedRemainingSeconds == nil)
        await flushAsyncWork()
        await context.clock.advance(by: .seconds(Int64(pausedRemaining)))
        await flushAsyncWork()

        #expect(context.engine.state.phase == .rest)
        #expect(context.probe.reminders.map(\.kind) == [.focusCompleted])
    }

    @Test func completedBreakRecordsBreakAndClearsCountdown() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makePomodoroContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.pomodoroFocusMinutes = 1
        context.preferencesStore.preferences.pomodoroBreakMinutes = 1

        context.engine.startFocusSession()
        await flushAsyncWork()
        await context.clock.advance(by: .seconds(60))
        await flushAsyncWork()
        await context.clock.advance(by: .seconds(60))
        await flushAsyncWork()

        #expect(context.engine.state.runState == .idle)
        #expect(context.breakStatsStore.todayBreaks == 1)
        #expect(context.breakStatsStore.weekBreaks == 1)
        #expect(context.probe.reminders.map(\.kind) == [.focusCompleted, .breakCompleted])
        if let lastCountdown = context.probe.countdowns.last {
            #expect(lastCountdown == nil)
        } else {
            Issue.record("Expected cleared pomodoro countdown event")
        }
    }

    @Test func disabledPomodoroDoesNotStartSession() {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makePomodoroContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.pomodoroEnabled = false
        context.engine.startFocusSession()

        #expect(context.engine.state.runState == .idle)
        #expect(context.probe.reminders.isEmpty)
        #expect(context.probe.countdowns.isEmpty)
    }
}

@MainActor
struct ReminderEngineTests {
    @Test func manualPauseAndScheduleBlockingComposePredictably() {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 22, minute: 0))
        defer { context.cleanup() }

        context.preferencesStore.preferences.schedule = Preferences.Schedule(
            isEnabled: true,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: false
        )
        context.engine.send(.tick(context.clock.now))
        #expect(context.engine.runState == .scheduleBlocked)

        context.engine.send(.setManualPause(true))
        #expect(context.engine.runState == .manuallyPaused)

        context.engine.send(.setManualPause(false))
        #expect(context.engine.runState == .scheduleBlocked)
    }

    @Test func timedManualPauseReportsRemainingTimeAndAutoResumes() {
        let now = makeDate(year: 2026, month: 6, day: 11, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        let pauseUntilDate = now.addingTimeInterval(30 * 60)
        context.engine.send(.setTimedManualPause(until: pauseUntilDate))

        #expect(context.engine.state.manualPause)
        #expect(context.engine.state.manualPauseUntilDate == pauseUntilDate)
        #expect(context.engine.runState == .manuallyPaused)

        let preview = context.engine.nextReminderPreview(at: now.addingTimeInterval(5 * 60))
        #expect(preview.breakRow.status == .paused(remainingSeconds: 25 * 60))

        context.clock.now = pauseUntilDate.addingTimeInterval(1)
        context.engine.send(.tick(context.clock.now))

        #expect(!context.engine.state.manualPause)
        #expect(context.engine.state.manualPauseUntilDate == nil)
        #expect(context.engine.runState == .tracking)
    }

    @Test func automaticReminderStagesPendingThenPresentsAndPlaysSound() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 1
        context.idleProvider.idleSeconds = 0

        context.engine.send(.tick(now))
        context.clock.now = now.addingTimeInterval(60)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.engine.isReminderPresenting)
        #expect(context.soundPlayer.playCount == 1)
        #expect(context.soundPlayer.cues == [.breakReminder])

        await promotePendingReminder(in: context)

        #expect(context.engine.state.presentation == .presenting)

        context.engine.send(.hoverChanged(false))
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func manualTriggerStagesReminderBeforePresenting() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.engine.overlayState.presentation == .reminderPending)
        #expect(context.engine.isReminderPresenting)
        #expect(context.engine.overlayState.content == .breakReminder)
        #expect(context.soundPlayer.playCount == 1)
        #expect(context.soundPlayer.cues == [.breakReminder])

        await promotePendingReminder(in: context)

        #expect(context.engine.state.presentation == .presenting)
        #expect(context.engine.overlayState.presentation == .presenting)
    }

    @Test func sitAwareDisabledContinuesCountingDuringIdleTime() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 1
        context.preferencesStore.preferences.sitAwareEnabled = false
        context.idleProvider.idleSeconds = 600

        context.engine.send(.tick(now))
        context.clock.now = now.addingTimeInterval(60)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.state.presentation == .reminderPending)
        await promotePendingReminder(in: context)

        #expect(context.engine.state.presentation == .presenting)
        #expect(context.soundPlayer.playCount == 1)
    }

    @Test func disabledBreakRemindersBlockAutomaticAndManualBreakRemindersUntilReenabled() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 1
        context.preferencesStore.preferences.breakReminderEnabled = false
        context.idleProvider.idleSeconds = 0

        context.engine.send(.tick(now))
        context.clock.now = now.addingTimeInterval(60)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.runState == .breakRemindersDisabled)
        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.state.activeSeconds == 0)
        #expect(context.soundPlayer.playCount == 0)

        context.engine.send(.manualTrigger)
        #expect(context.engine.state.presentation == .hidden)
        #expect(context.soundPlayer.playCount == 0)

        context.preferencesStore.preferences.breakReminderEnabled = true
        await flushAsyncWork()
        context.clock.now = now.addingTimeInterval(120)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.soundPlayer.playCount == 1)

        await promotePendingReminder(in: context)
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func pomodoroCountdownTucksAndCanBeHoveredUntilCleared() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }
        let content = PomodoroCountdownContent(
            phase: .focus,
            startedAt: now,
            duration: 25 * 60,
            pausedRemainingSeconds: nil
        )

        context.engine.updatePomodoroCountdown(content)

        #expect(context.engine.isPomodoroCountdownActive)
        #expect(context.engine.state.presentation == .hoverPreview)
        if case .pomodoroCountdown(let activeContent) = context.engine.overlayState.content {
            #expect(activeContent == content)
        } else {
            Issue.record("Expected pomodoro countdown content")
        }

        await flushAsyncWork()
        await context.clock.advance(by: .seconds(60))
        await flushAsyncWork()

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.isPomodoroCountdownActive)

        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .hoverPreviewPending)

        await promoteHoverPreview(in: context)
        #expect(context.engine.state.presentation == .hoverPreview)

        context.engine.send(.hoverChanged(false))
        await settleHoverPreviewDismissal(in: context)

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.isPomodoroCountdownActive)

        context.engine.updatePomodoroCountdown(nil)
        #expect(!context.engine.isPomodoroCountdownActive)
        #expect(context.engine.overlayState.content == .breakReminder)
    }

    @Test func pomodoroCountdownRestoresAfterBreakReminderDismissal() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }
        let content = PomodoroCountdownContent(
            phase: .focus,
            startedAt: now,
            duration: 25 * 60,
            pausedRemainingSeconds: nil
        )

        context.engine.updatePomodoroCountdown(content)
        await flushAsyncWork()
        await context.clock.advance(by: .seconds(60))
        await flushAsyncWork()
        context.engine.send(.manualTrigger)

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.engine.overlayState.content == .breakReminder)

        await promotePendingReminder(in: context)
        context.engine.send(.dismissReminder)
        await settleReminderDismissal(in: context)

        #expect(context.engine.state.presentation == .hidden)
        if case .pomodoroCountdown(let restoredContent) = context.engine.overlayState.content {
            #expect(restoredContent == content)
        } else {
            Issue.record("Expected restored pomodoro countdown content")
        }
    }

    @Test func completedBreakIncrementsStatistics() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        context.engine.send(.completeBreak)

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.isBreakCompletionCountdownActive)
        #expect(context.breakStatsStore.todayBreaks == 1)
        #expect(context.breakStatsStore.weekBreaks == 1)
    }

    @Test func completedBreakCountdownCanBeHoveredAndThenTucksAgain() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.preferencesStore.preferences.hoverPreviewEnabled = false
        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        context.engine.send(.completeBreak)

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.isBreakCompletionCountdownActive)

        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .hoverPreviewPending)

        await promoteHoverPreview(in: context)
        #expect(context.engine.state.presentation == .hoverPreview)

        context.engine.send(.hoverChanged(false))
        #expect(context.engine.state.presentation == .hoverPreviewDismissing)

        await settleHoverPreviewDismissal(in: context)
        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.isBreakCompletionCountdownActive)
    }

    @Test func completedBreakCountdownClearsAfterRemainingDurationWithoutDoubleCounting() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        context.engine.send(.completeBreak)

        guard case .breakCompletionCountdown(let content) = context.engine.overlayState.content else {
            Issue.record("Expected break completion countdown content")
            return
        }

        await advanceClockAndFlush(context.clock, by: .seconds(content.duration))

        #expect(context.engine.state.presentation == .hidden)
        #expect(!context.engine.isBreakCompletionCountdownActive)
        #expect(context.engine.overlayState.content == .breakReminder)
        #expect(context.breakStatsStore.todayBreaks == 1)
        #expect(context.breakStatsStore.weekBreaks == 1)
    }

    @Test func autoDismissDoesNotIncrementStatistics() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        context.engine.send(.autoDismiss)
        await settleReminderDismissal(in: context)

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.breakStatsStore.todayBreaks == 0)
        #expect(context.breakStatsStore.weekBreaks == 0)
    }

    @Test func snoozedBreakReminderWaitsUntilSnoozeExpires() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        let snoozeStart = context.clock.now
        let snoozedUntil = snoozeStart.addingTimeInterval(10 * 60)
        context.engine.snoozeReminder(duration: 10 * 60)
        await settleReminderDismissal(in: context)

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.state.breakSnoozedUntilDate == snoozedUntil)

        context.clock.now = snoozeStart.addingTimeInterval(9 * 60)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.state.presentation == .hidden)

        context.clock.now = snoozedUntil
        context.engine.send(.tick(context.clock.now))

        #expect(context.soundPlayer.playCount == 2)
        #expect(context.engine.state.presentation == .reminderPending)

        await promotePendingReminder(in: context)

        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func skippedBreakReminderUsesFullIntervalBeforeRepeating() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 30
        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        context.engine.send(.dismissReminder)
        await settleReminderDismissal(in: context)
        let repeatStart = context.clock.now

        context.clock.now = repeatStart.addingTimeInterval(10 * 60)
        context.engine.send(.tick(context.clock.now))
        #expect(context.engine.state.presentation == .hidden)

        context.clock.now = repeatStart.addingTimeInterval(30 * 60)
        context.engine.send(.tick(context.clock.now))
        #expect(context.engine.state.presentation == .reminderPending)

        await promotePendingReminder(in: context)

        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func preferencesChangeToBlockedScheduleCancelsActiveReminder() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 22, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        #expect(context.engine.state.presentation == .presenting)

        context.preferencesStore.preferences.schedule = Preferences.Schedule(
            isEnabled: true,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: false
        )
        await flushAsyncWork()

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.engine.state.scheduleState == .blocked)
    }

    @Test func pendingReminderPromotionIsCancelledByDismiss() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        #expect(context.engine.state.presentation == .reminderPending)

        context.engine.send(.dismissReminder)
        #expect(context.engine.state.presentation == .dismissAnimating)

        await context.clock.advance(by: ReminderEngine.reminderPresentationPreflightDelay)
        await flushAsyncWork()
        #expect(context.engine.state.presentation != .presenting)

        await settleReminderDismissal(in: context)
        #expect(context.engine.state.presentation == .hidden)
    }

    @Test func pendingReminderPromotionIsCancelledBySnooze() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        #expect(context.engine.state.presentation == .reminderPending)

        context.engine.snoozeReminder(duration: 10 * 60)
        #expect(context.engine.state.breakSnoozedUntilDate == now.addingTimeInterval(10 * 60))

        await context.clock.advance(by: ReminderEngine.reminderPresentationPreflightDelay)
        await flushAsyncWork()
        #expect(context.engine.state.presentation != .presenting)

        await settleReminderDismissal(in: context)
        #expect(context.engine.state.presentation == .hidden)
    }

    @Test func hoverPreviewStagesEntryAndExit() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        context.engine.send(.hoverPreviewFitReady)

        #expect(context.engine.state.presentation == .hoverPreviewPending)
        #expect(!context.engine.isReminderPresenting)

        await flushAsyncWork()
        await context.clock.advance(by: .milliseconds(50))
        await flushAsyncWork()
        #expect(context.engine.state.presentation == .hoverPreviewPending)

        await context.clock.advance(by: .milliseconds(25))
        await flushAsyncWork()
        #expect(context.engine.state.presentation == .hoverPreview)

        context.engine.send(.hoverChanged(false))
        #expect(context.engine.state.presentation == .hoverPreviewDismissing)

        await flushAsyncWork()
        await context.clock.advance(by: .milliseconds(200))
        await flushAsyncWork()
        #expect(context.engine.state.presentation == .hoverPreviewDismissing)

        await context.clock.advance(by: .milliseconds(50))
        await flushAsyncWork()
        #expect(context.engine.state.presentation == .hidden)
    }

    @Test func hoverPreviewWaitsForFitReadyAfterPreheatElapsed() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        await advanceClockAndFlush(context.clock, by: ReminderEngine.hoverPreviewPromotionDelay)

        #expect(context.engine.state.presentation == .hoverPreviewPending)

        context.engine.send(.hoverPreviewFitReady)

        #expect(context.engine.state.presentation == .hoverPreview)
    }

    @Test func hoverPreviewFitReadyBeforePreheatStillWaitsForPromotionDelay() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        context.engine.send(.hoverPreviewFitReady)
        await advanceClockAndFlush(context.clock, by: .milliseconds(50))

        #expect(context.engine.state.presentation == .hoverPreviewPending)

        await advanceClockAndFlush(context.clock, by: .milliseconds(25))

        #expect(context.engine.state.presentation == .hoverPreview)
    }

    @Test func hoverPreviewFallbackPromotesWhenFitNeverArrives() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        await advanceClockAndFlush(context.clock, by: ReminderEngine.hoverPreviewPromotionDelay)

        #expect(context.engine.state.presentation == .hoverPreviewPending)

        await advanceClockAndFlush(
            context.clock,
            by: .milliseconds(110)
        )

        #expect(context.engine.state.presentation == .hoverPreview)
    }

    @Test func hoverPreviewReentryDuringDismissalRestoresPreview() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        await promoteHoverPreview(in: context)
        #expect(context.engine.state.presentation == .hoverPreview)

        context.engine.send(.hoverChanged(false))
        #expect(context.engine.state.presentation == .hoverPreviewDismissing)

        await context.clock.advance(by: .milliseconds(120))
        await flushAsyncWork()
        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .hoverPreview)

        await context.clock.advance(by: ReminderEngine.hoverPreviewDismissalDelay)
        await flushAsyncWork()
        #expect(context.engine.state.presentation == .hoverPreview)
    }

    @Test func hoverPreviewPromotionIsCancelledWhenPointerLeavesQuickly() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .hoverPreviewPending)

        context.engine.send(.hoverChanged(false))
        #expect(context.engine.state.presentation == .hidden)
        context.engine.send(.hoverPreviewFitReady)

        await advanceClockAndFlush(context.clock, by: ReminderEngine.hoverPreviewMaximumPreheatDelay)
        #expect(context.engine.state.presentation == .hidden)
    }

    @Test func hoverPromotesPendingReminderImmediately() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        #expect(context.engine.state.presentation == .reminderPending)

        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func scheduleReminderStagesWithoutPlayingBreakSound() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }
        let item = DailyScheduleItem(title: "Design review", startDate: now.addingTimeInterval(15 * 60))
        let actions = DailyScheduleReminderActions(
            complete: {},
            snooze: { _ in },
            dismiss: {}
        )

        context.engine.presentScheduleReminder(for: item, actions: actions)

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.soundPlayer.playCount == 0)
        if case .schedule(let content) = context.engine.overlayState.content {
            #expect(content.title == "Design review")
        } else {
            Issue.record("Expected schedule overlay content")
        }

        await promotePendingReminder(in: context)
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func pomodoroSessionStartStagesWithoutSound() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }
        let content = PomodoroReminderContent(
            kind: .sessionStarted,
            occurredAt: now,
            nextPhaseDuration: 25 * 60,
            focusDuration: 25 * 60,
            breakDuration: 5 * 60
        )

        context.engine.presentPomodoroReminder(content)

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.soundPlayer.cues.isEmpty)
        if case .pomodoro(let activeContent) = context.engine.overlayState.content {
            #expect(activeContent.kind == .sessionStarted)
            #expect(activeContent.focusDuration == 25 * 60)
            #expect(activeContent.breakDuration == 5 * 60)
        } else {
            Issue.record("Expected pomodoro overlay content")
        }

        await promotePendingReminder(in: context)
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func pomodoroCompletionUsesPomodoroSoundCue() async {
        let now = makeDate(year: 2026, month: 6, day: 2, hour: 9, minute: 25)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }
        let content = PomodoroReminderContent(
            kind: .focusCompleted,
            occurredAt: now,
            nextPhaseDuration: 5 * 60,
            focusDuration: 25 * 60,
            breakDuration: 5 * 60
        )

        context.engine.presentPomodoroReminder(content)

        #expect(context.engine.state.presentation == .reminderPending)
        #expect(context.soundPlayer.cues == [.pomodoro])

        await promotePendingReminder(in: context)
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func disablingHoverPreviewClearsPreviewImmediately() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .hoverPreviewPending)

        context.preferencesStore.preferences.hoverPreviewEnabled = false
        await flushAsyncWork()

        #expect(context.engine.state.presentation == .hidden)
    }

    @Test func autoDismissPreferenceChangeUpdatesOverlayDuration() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        #expect(context.engine.overlayState.reminderDuration == 60)

        context.preferencesStore.preferences.autoDismissSeconds = 90
        await flushAsyncWork()

        #expect(context.engine.overlayState.reminderDuration == 90)
    }

    @Test func nextReminderPreviewReportsTrackingBreakTargetTime() {
        let now = makeDate(year: 2026, month: 6, day: 3, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 30
        context.idleProvider.idleSeconds = 0

        context.engine.send(.tick(now))

        let preview = context.engine.nextReminderPreview(at: now)

        guard case .scheduled(let targetDate, let remainingSeconds) = preview.breakRow.status else {
            Issue.record("Expected scheduled break preview")
            return
        }

        let expectedRemaining = Int(ceil(context.engine.reminderInterval - context.engine.state.activeSeconds))
        #expect(remainingSeconds == expectedRemaining)
        #expect(targetDate == now.addingTimeInterval(TimeInterval(expectedRemaining)))
    }

    @Test func nextReminderPreviewPrefersSnoozedBreakTargetTime() async {
        let now = makeDate(year: 2026, month: 6, day: 3, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        await promotePendingReminder(in: context)
        let snoozeStart = context.clock.now
        context.engine.snoozeReminder(duration: 10 * 60)

        let preview = context.engine.nextReminderPreview(at: snoozeStart)

        guard case .snoozed(let targetDate, let remainingSeconds) = preview.breakRow.status else {
            Issue.record("Expected snoozed break preview")
            return
        }

        #expect(targetDate == snoozeStart.addingTimeInterval(10 * 60))
        #expect(remainingSeconds == 10 * 60)
    }

    @Test func nextReminderPreviewReportsBreakUnavailableStates() {
        let now = makeDate(year: 2026, month: 6, day: 3, hour: 22, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.breakReminderEnabled = false
        #expect(context.engine.nextReminderPreview(at: now).breakRow.status == .disabled)

        context.preferencesStore.preferences.breakReminderEnabled = true
        context.engine.send(.setManualPause(true))
        #expect(context.engine.nextReminderPreview(at: now).breakRow.status == .paused(remainingSeconds: nil))

        context.engine.send(.setManualPause(false))
        context.preferencesStore.preferences.schedule = Preferences.Schedule(
            isEnabled: true,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: false
        )
        #expect(context.engine.nextReminderPreview(at: now).breakRow.status == .scheduleBlocked)

        context.preferencesStore.preferences.schedule = Preferences.defaults.schedule
        context.idleProvider.idleSeconds = 600
        #expect(context.engine.nextReminderPreview(at: now).breakRow.status == .idleSuppressed)
    }

    @Test func nextReminderPreviewReportsPomodoroRunningPausedIdleAndDisabledStates() {
        let now = makeDate(year: 2026, month: 6, day: 3, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        #expect(context.engine.nextReminderPreview(at: now).pomodoroRow.status == .idle)

        let runningContent = PomodoroCountdownContent(
            phase: .focus,
            startedAt: now,
            duration: 25 * 60,
            pausedRemainingSeconds: nil
        )
        let previewDate = now.addingTimeInterval(60)
        context.engine.updatePomodoroCountdown(runningContent)

        let runningRow = context.engine.nextReminderPreview(at: previewDate).pomodoroRow
        guard case .scheduled(let targetDate, let remainingSeconds) = runningRow.status else {
            Issue.record("Expected scheduled pomodoro preview")
            return
        }

        #expect(runningRow.phase == .focus)
        #expect(remainingSeconds == 24 * 60)
        #expect(targetDate == now.addingTimeInterval(25 * 60))

        let pausedContent = PomodoroCountdownContent(
            phase: .rest,
            startedAt: previewDate,
            duration: 5 * 60,
            pausedRemainingSeconds: 4 * 60
        )
        context.engine.updatePomodoroCountdown(pausedContent)
        #expect(context.engine.nextReminderPreview(at: previewDate).pomodoroRow.status == .paused(remainingSeconds: 4 * 60))
        #expect(context.engine.nextReminderPreview(at: previewDate).pomodoroRow.phase == .rest)

        context.engine.updatePomodoroCountdown(nil)
        #expect(context.engine.nextReminderPreview(at: previewDate).pomodoroRow.status == .idle)

        context.preferencesStore.preferences.pomodoroEnabled = false
        #expect(context.engine.nextReminderPreview(at: previewDate).pomodoroRow.status == .disabled)
    }
}

@MainActor
struct TextInsertionServiceTests {
    @Test func pasteboardSnapshotRestoresOnlyWhenClipboardIsUnchanged() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("NotchMovePasteboardTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("voice text", forType: .string)
        let expectedChangeCount = pasteboard.changeCount

        #expect(snapshot.restoreIfUnchanged(to: pasteboard, expectedChangeCount: expectedChangeCount))
        #expect(pasteboard.string(forType: .string) == "original")

        pasteboard.clearContents()
        pasteboard.setString("voice text", forType: .string)
        let staleChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("user copied something else", forType: .string)

        #expect(!snapshot.restoreIfUnchanged(to: pasteboard, expectedChangeCount: staleChangeCount))
        #expect(pasteboard.string(forType: .string) == "user copied something else")
    }

    @Test func accessibilityElementHelperRejectsNonAccessibilityValues() {
        let nonAccessibilityValue = "focused text field" as CFString

        #expect(TextInsertionService.accessibilityElement(from: nil) == nil)
        #expect(TextInsertionService.accessibilityElement(from: nonAccessibilityValue) == nil)
    }
}

@MainActor
struct DiagnosticsReportServiceTests {
    @Test func diagnosticsReportOmitsStoredCredentialsAndAudioHistory() throws {
        let suiteName = "NotchMoveDiagnostics-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let preferencesStore = PreferencesStore(settings: settings)
        preferencesStore.preferences.voiceInputEnabled = true
        preferencesStore.preferences.voicePersonalTerms = ["Thomas", "NotchMove"]

        let aiPreferences = AIProviderPreferences(
            defaults: defaults,
            apiKeyStore: DiagnosticsInMemoryAPIKeyStore()
        )
        aiPreferences.isEnabled = true
        try aiPreferences.saveCredential(
            "sk-secret-diagnostic-test",
            fieldID: AICredentialField.apiKey.id,
            for: aiPreferences.selectedParserProvider
        )

        let notchHubStore = makeNotchHubStore(defaults: defaults)
        let service = DiagnosticsReportService(
            preferencesStore: preferencesStore,
            aiProviderPreferences: aiPreferences,
            breakStatsStore: BreakStatsStore(defaults: defaults),
            notchHubStore: notchHubStore,
            reminderEngine: nil,
            pomodoroEngine: nil,
            screens: []
        )

        let json = try service.makeJSONString()

        #expect(json.contains(#""voiceInputEnabled" : true"#))
        #expect(json.contains(#""voicePersonalTermsCount" : 2"#))
        #expect(!json.contains("sk-secret-diagnostic-test"))
        #expect(!json.localizedCaseInsensitiveContains("audioHistory"))
    }
}

@MainActor
struct NotchVisualStateTests {
    @Test func hoverPendingUsesMagneticCueWithoutRevealingContent() {
        let tucked = CGSize(width: 200, height: 38)
        let canvas = CGSize(width: 520, height: 118)

        let state = NotchVisualState(
            presentation: .hoverPreviewPending,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas
        )

        #expect(state.shellSize == tucked)
        #expect(state.shellScale == 1.012)
        #expect(state.shellOffsetY == 1)
        #expect(state.cornerRadius == 11)
        #expect(state.shadowOpacity > 0)
        #expect(state.rimOpacity > 0)
        #expect(state.contentOpacity == 0)
        #expect(state.contentBlurRadius > 0)
    }

    @Test func hoverPreviewExpandsShellAndRevealsContent() {
        let tucked = CGSize(width: 200, height: 38)
        let canvas = CGSize(width: 520, height: 118)

        let state = NotchVisualState(
            presentation: .hoverPreview,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas
        )

        #expect(state.shellSize == canvas)
        #expect(state.shellScale == 1)
        #expect(state.cornerRadius == 18)
        #expect(state.shadowRadius >= 12)
        #expect(state.contentOpacity == 1)
        #expect(state.contentScale == 1)
        #expect(state.contentOffsetY == 0)
        #expect(state.contentBlurRadius == 0)
    }

    @Test func hoverPreviewCanExpandShellBeforeRevealingContent() {
        let tucked = CGSize(width: 200, height: 38)
        let canvas = CGSize(width: 520, height: 118)

        let state = NotchVisualState(
            presentation: .hoverPreview,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas,
            revealHoverPreviewContent: false
        )

        #expect(state.shellSize == canvas)
        #expect(state.contentOpacity == 0)
        #expect(state.contentScale < 1)
        #expect(state.contentOffsetY < 0)
        #expect(state.contentBlurRadius > 0)
    }

    @Test func pomodoroCountdownHoverUsesLighterMotionThanStandardPreview() {
        let tucked = CGSize(width: 200, height: 38)
        let canvas = CGSize(width: 344, height: 96)

        let standard = NotchVisualState(
            presentation: .hoverPreview,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas
        )
        let pomodoro = NotchVisualState(
            presentation: .hoverPreview,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas,
            motionRole: .pomodoroCountdown
        )

        #expect(pomodoro.shellSize == canvas)
        #expect(pomodoro.cornerRadius < standard.cornerRadius)
        #expect(pomodoro.shadowOpacity < standard.shadowOpacity)
        #expect(pomodoro.shadowRadius < standard.shadowRadius)
        #expect(pomodoro.rimOpacity > standard.rimOpacity)
        #expect(pomodoro.contentOpacity == 1)
        #expect(pomodoro.contentBlurRadius == 0)
    }

    @Test func dismissingTucksShellAndHidesContentFirst() {
        let tucked = CGSize(width: 200, height: 38)
        let canvas = CGSize(width: 520, height: 118)

        let state = NotchVisualState(
            presentation: .hoverPreviewDismissing,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas
        )

        #expect(state.shellSize == tucked)
        #expect(state.shellScale < 1)
        #expect(state.cornerRadius == 10)
        #expect(state.contentOpacity == 0)
        #expect(state.contentOffsetY < 0)
        #expect(state.contentBlurRadius > 0)
    }

    @Test func dismissingCanHoldExpandedShellWhileContentIsHidden() {
        let tucked = CGSize(width: 200, height: 38)
        let canvas = CGSize(width: 520, height: 118)

        let state = NotchVisualState(
            presentation: .hoverPreviewDismissing,
            voiceOverlayVisible: false,
            tuckedSize: tucked,
            canvasSize: canvas,
            holdHoverPreviewShellExpanded: true
        )

        #expect(state.shellSize == canvas)
        #expect(state.contentOpacity == 0)
        #expect(state.cornerRadius == 18)
        #expect(state.shadowRadius > 1)
    }

    @Test func pomodoroCountdownHoverResolvesToCountdownContentRole() {
        let content = PomodoroCountdownContent(
            phase: .focus,
            startedAt: makeDate(year: 2026, month: 6, day: 5, hour: 9, minute: 0),
            duration: 25 * 60,
            pausedRemainingSeconds: nil
        )

        #expect(
            NotchOverlayContentRole.resolve(
                presentation: .hoverPreview,
                content: .pomodoroCountdown(content),
                voiceOverlayVisible: false
            ) == .pomodoroCountdown
        )
        #expect(
            NotchOverlayContentRole.resolve(
                presentation: .hoverPreview,
                content: .breakReminder,
                voiceOverlayVisible: false
            ) == .hoverPreview
        )
    }

    @Test func hoverPreviewContentMountsDuringPendingAndDismissingForMeasurement() {
        #expect(
            NotchOverlayContentRole.resolve(
                presentation: .hoverPreviewPending,
                content: .breakReminder,
                voiceOverlayVisible: false
            ) == .hoverPreview
        )
        #expect(
            NotchOverlayContentRole.resolve(
                presentation: .hoverPreviewDismissing,
                content: .breakReminder,
                voiceOverlayVisible: false
            ) == .hoverPreview
        )
    }
}

@MainActor
struct NotchOverlayMetricsTests {
    @Test func clearingCurrentFitRequestKeepsCachedFitForPendingPreheat() {
        let metrics = NotchOverlayMetrics(topInset: 38)

        metrics.requestContentFit(size: CGSize(width: 519.25, height: 117.25), displayScale: 2)
        metrics.clearContentFitRequest()

        #expect(metrics.contentFitRequest == nil)
        #expect(metrics.cachedContentFitRequest?.size == CGSize(width: 519.5, height: 117.5))
    }

    @Test func frozenHoverPreviewSizeIgnoresLaterFitChangesUntilCleared() {
        let metrics = NotchOverlayMetrics(topInset: 38)

        metrics.freezeHoverPreviewSize(CGSize(width: 519.25, height: 117.25), displayScale: 2)
        metrics.requestContentFit(size: CGSize(width: 640, height: 128), displayScale: 2)

        #expect(metrics.frozenHoverPreviewSize == CGSize(width: 519.5, height: 117.5))

        metrics.clearFrozenHoverPreviewSize()
        metrics.freezeHoverPreviewSize(CGSize(width: 640, height: 128), displayScale: 2)

        #expect(metrics.frozenHoverPreviewSize == CGSize(width: 640, height: 128))
    }
}

@MainActor
struct NotchOverlaySizingRoleResolverTests {
    @Test func pomodoroCountdownHoverUsesProminentCountdownSizing() {
        let content = PomodoroCountdownContent(
            phase: .focus,
            startedAt: makeDate(year: 2026, month: 6, day: 5, hour: 9, minute: 0),
            duration: 25 * 60,
            pausedRemainingSeconds: nil
        )

        #expect(
            NotchOverlaySizingRoleResolver.sizingRole(
                activePresentation: .hoverPreview,
                content: .pomodoroCountdown(content),
                voiceOverlayVisible: false
            ) == .prominentCountdown
        )
    }

    @Test func standardHoverPreviewStillUsesDualPreviewSizing() {
        #expect(
            NotchOverlaySizingRoleResolver.sizingRole(
                activePresentation: .hoverPreview,
                content: .breakReminder,
                voiceOverlayVisible: false
            ) == .dualPreview
        )
    }
}

@MainActor
struct NotchHubTests {
    @Test func widgetGroupsClassifySchemeADefaultOptionalAndAdvancedSets() {
        #expect(NotchHubWidgetID.widgets(in: .core) == [.live, .calendar, .notes])
        #expect(NotchHubWidgetID.widgets(in: .optional) == [.media])
        #expect(NotchHubWidgetID.widgets(in: .advanced) == [.shortcuts, .mirror, .tray])
        #expect(NotchHubWidgetID.coreDefaultWidgets == [.live, .calendar, .notes])
        #expect(NotchHubWidgetID.calendar.requiredPermission == nil)
    }

    @Test func presentationResolverKeepsVoiceAndReminderAheadOfHub() {
        #expect(
            NotchHubPresentationResolver.effectiveSurface(
                voiceOverlayVisible: true,
                reminderPresentation: .hidden,
                hubPresentation: .widget(.media),
                pomodoroActive: true,
                hoverPreviewEnabled: true
            ) == .voice
        )
        #expect(
            NotchHubPresentationResolver.effectiveSurface(
                voiceOverlayVisible: false,
                reminderPresentation: .presenting,
                hubPresentation: .widget(.media),
                pomodoroActive: false,
                hoverPreviewEnabled: true
            ) == .reminder
        )
        #expect(
            NotchHubPresentationResolver.effectiveSurface(
                voiceOverlayVisible: false,
                reminderPresentation: .hidden,
                hubPresentation: .widget(.media),
                pomodoroActive: true,
                hoverPreviewEnabled: true
            ) == .hub
        )
    }

    @Test func presentationResolverFallsBackToLiveHoverAndTuckedSurfaces() {
        #expect(
            NotchHubPresentationResolver.effectiveSurface(
                voiceOverlayVisible: false,
                reminderPresentation: .hidden,
                hubPresentation: .tucked,
                pomodoroActive: true,
                hoverPreviewEnabled: true
            ) == .liveStatus
        )
        #expect(
            NotchHubPresentationResolver.effectiveSurface(
                voiceOverlayVisible: false,
                reminderPresentation: .hoverPreview,
                hubPresentation: .tucked,
                pomodoroActive: false,
                hoverPreviewEnabled: true
            ) == .hoverPreview
        )
        #expect(
            NotchHubPresentationResolver.effectiveSurface(
                voiceOverlayVisible: false,
                reminderPresentation: .hidden,
                hubPresentation: .tucked,
                pomodoroActive: false,
                hoverPreviewEnabled: false
            ) == .tucked
        )
    }

    @Test func freshStoreUsesCoreFocusWidgetsByDefault() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        #expect(store.preferences.enabledWidgetIDs == [.live, .calendar, .notes])
        #expect(store.preferences.defaultWidgetID == .live)
        #expect(store.enabledWidgets == [.live, .calendar, .notes])

        store.setHubEnabled(true)
        store.open()

        #expect(store.presentation == .widget(.live))
    }

    @Test func storePreservesStoredLegacyWidgetSetDuringMigration() {
        let defaults = makeEphemeralDefaults()
        defaults.set(
            NotchHubWidgetID.allCases.map(\.rawValue),
            forKey: "notchHub.enabledWidgetIDs"
        )
        defaults.set(NotchHubWidgetID.media.rawValue, forKey: "notchHub.defaultWidgetID")

        let store = makeNotchHubStore(defaults: defaults)

        #expect(store.preferences.enabledWidgetIDs == Set(NotchHubWidgetID.allCases))
        #expect(store.preferences.defaultWidgetID == .media)
        #expect(store.enabledWidgets == NotchHubWidgetID.allCases)
    }

    @Test func invalidStoredWidgetsFallbackToLive() {
        let defaults = makeEphemeralDefaults()
        defaults.set(["missing-widget"], forKey: "notchHub.enabledWidgetIDs")
        defaults.set(NotchHubWidgetID.media.rawValue, forKey: "notchHub.defaultWidgetID")

        let store = makeNotchHubStore(defaults: defaults)

        #expect(store.preferences.enabledWidgetIDs == [.live])
        #expect(store.preferences.defaultWidgetID == .live)
    }

    @Test func defaultWidgetFallsBackToLiveWhenDisabled() {
        let defaults = makeEphemeralDefaults()
        defaults.set(
            [NotchHubWidgetID.live.rawValue, NotchHubWidgetID.notes.rawValue],
            forKey: "notchHub.enabledWidgetIDs"
        )
        defaults.set(NotchHubWidgetID.media.rawValue, forKey: "notchHub.defaultWidgetID")

        let store = makeNotchHubStore(defaults: defaults)

        #expect(store.preferences.enabledWidgetIDs == [.live, .notes])
        #expect(store.preferences.defaultWidgetID == .live)
    }

    @Test func defaultWidgetOptionsRequireSensitivePermissions() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        store.setWidget(.media, enabled: true)
        store.setWidget(.tray, enabled: true)

        #expect(store.defaultWidgetOptions == [.live, .calendar, .notes])

        store.setDefaultWidget(.media)
        #expect(store.preferences.defaultWidgetID == .live)

        store.setAppleEventsAllowed(true)
        #expect(store.defaultWidgetOptions == [.live, .media, .calendar, .notes])

        store.setDefaultWidget(.media)
        #expect(store.preferences.defaultWidgetID == .media)

        store.setAppleEventsAllowed(false)
        #expect(store.preferences.defaultWidgetID == .live)
        #expect(store.mediaStatus == MediaPlaybackStatus())

        store.setFileTrayAllowed(true)
        #expect(store.defaultWidgetOptions == [.live, .calendar, .notes, .tray])
    }

    @Test func liveWidgetRemainsRequiredFallbackAfterPreferenceMutation() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        store.preferences.enabledWidgetIDs = [.media]

        #expect(store.preferences.enabledWidgetIDs == [.live, .media])

        store.setWidget(.live, enabled: false)

        #expect(store.preferences.enabledWidgetIDs.contains(.live))
    }

    @Test func storePersistsNormalizedPreferencesAndShortcutNames() {
        let defaults = makeEphemeralDefaults()
        let scheduleStore = DailyScheduleStore(defaults: defaults)
        let store = makeNotchHubStore(defaults: defaults, scheduleStore: scheduleStore)

        store.preferences.isEnabled = true
        store.setWidget(.media, enabled: false)
        store.setDefaultWidget(.notes)
        store.addShortcut(named: "Clean Clipboard")
        store.addShortcut(named: " Clean Clipboard ")
        store.preferences.enabledWidgetIDs = []

        let restored = makeNotchHubStore(defaults: defaults, scheduleStore: scheduleStore)

        #expect(restored.preferences.isEnabled)
        #expect(restored.preferences.enabledWidgetIDs == [.live])
        #expect(restored.preferences.defaultWidgetID == .live)
        #expect(restored.preferences.shortcutNames == ["Clean Clipboard"])
    }

    @Test func storePersistsTriggerGestureAndTogglesPresentation() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        store.setHubEnabled(true)
        store.preferences.triggerGesture = .hoverAndClick
        store.open()

        #expect(store.presentation == .widget(.live))
        #expect(store.isExpanded)

        store.toggleHub()
        #expect(store.presentation == .tucked)

        let restored = makeNotchHubStore(defaults: defaults)
        #expect(restored.preferences.triggerGesture == .hoverAndClick)
    }

    @Test func focusOverviewSnapshotUsesLocalScheduleWithoutExternalCalendarProvider() {
        let defaults = makeEphemeralDefaults()
        let scheduleStore = DailyScheduleStore(defaults: defaults)
        let now = makeDate(year: 2026, month: 6, day: 8, hour: 10, minute: 0)
        let currentItem = scheduleStore.add(DailyScheduleItem(
            title: "Deep work",
            startDate: now.addingTimeInterval(-30 * 60),
            endDate: now.addingTimeInterval(30 * 60)
        ))
        scheduleStore.add(DailyScheduleItem(
            title: "Past standup",
            startDate: now.addingTimeInterval(-90 * 60),
            endDate: now.addingTimeInterval(-60 * 60)
        ))
        scheduleStore.add(DailyScheduleItem(
            title: "Disabled follow-up",
            startDate: now.addingTimeInterval(15 * 60),
            isReminderEnabled: false
        ))
        scheduleStore.add(DailyScheduleItem(
            title: "Later review",
            startDate: now.addingTimeInterval(60 * 60)
        ))

        let calendarProvider = MockCalendarProvider()
        calendarProvider.externalItems = [
            NotchHubCalendarItem(
                id: "external.soon",
                title: "External soon",
                startDate: now.addingTimeInterval(5 * 60),
                endDate: nil,
                source: .calendar
            )
        ]
        let store = makeNotchHubStore(
            defaults: defaults,
            scheduleStore: scheduleStore,
            calendarProvider: calendarProvider
        )

        let overview = store.focusOverviewSnapshot(at: now)

        #expect(overview.nextLocalScheduleItem == currentItem)
        #expect(calendarProvider.externalItemsCallCount == 0)
    }

    @Test func mediaRefreshDoesNotCallProviderUntilAppleEventsAllowed() async {
        let defaults = makeEphemeralDefaults()
        let mediaProvider = MockMediaProvider()
        let store = makeNotchHubStore(defaults: defaults, mediaProvider: mediaProvider)

        store.setHubEnabled(true)
        store.setWidget(.media, enabled: true)
        store.open()
        store.selectWidget(.media)
        await flushAsyncWork()

        #expect(store.presentation == .widget(.media))
        #expect(mediaProvider.currentStatusCallCount == 0)
        #expect(store.mediaStatus == MediaPlaybackStatus())

        await store.refreshMediaStatus()
        #expect(mediaProvider.currentStatusCallCount == 0)

        store.setAppleEventsAllowed(true)
        await flushAsyncWork()

        #expect(mediaProvider.currentStatusCallCount == 1)
        #expect(store.mediaStatus == mediaProvider.status)
    }

    @Test func calendarRefreshUsesExternalProviderOnlyAfterAccessAllowed() async {
        let defaults = makeEphemeralDefaults()
        let scheduleStore = DailyScheduleStore(defaults: defaults)
        let startDate = makeDate(year: 2026, month: 6, day: 8, hour: 14, minute: 0)
        scheduleStore.add(DailyScheduleItem(title: "Standup", startDate: startDate))

        let calendarProvider = MockCalendarProvider()
        calendarProvider.externalItems = [
            NotchHubCalendarItem(
                id: "event.focus",
                title: "External focus",
                startDate: startDate.addingTimeInterval(60 * 60),
                endDate: nil,
                source: .calendar
            )
        ]
        let store = makeNotchHubStore(
            defaults: defaults,
            scheduleStore: scheduleStore,
            calendarProvider: calendarProvider
        )

        store.setHubEnabled(true)
        store.setDefaultWidget(.calendar)
        store.open()
        await flushAsyncWork()

        #expect(calendarProvider.externalItemsCallCount == 0)
        #expect(store.upcomingCalendarItems.map(\.title) == ["Standup"])

        store.preferences.allowCalendarAccess = true
        await store.refreshCalendarItems()

        #expect(calendarProvider.externalItemsCallCount == 1)
        #expect(store.upcomingCalendarItems.map(\.title) == ["Standup", "External focus"])
    }

    @Test func calendarAccessSettingRequestsAccessExplicitlyAndCanTurnOff() async {
        let defaults = makeEphemeralDefaults()
        let calendarProvider = MockCalendarProvider()
        let store = makeNotchHubStore(defaults: defaults, calendarProvider: calendarProvider)

        store.setCalendarAccessAllowed(true)
        await flushAsyncWork()

        #expect(calendarProvider.didRequestAccess)
        #expect(store.preferences.allowCalendarAccess)

        store.setCalendarAccessAllowed(false)
        await flushAsyncWork()

        #expect(!store.preferences.allowCalendarAccess)
    }

    @Test func disablingHubCollapsesExpandedPresentation() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        store.setHubEnabled(true)
        store.open()

        #expect(store.presentation == .widget(.live))

        store.setHubEnabled(false)

        #expect(!store.preferences.isEnabled)
        #expect(store.presentation == .tucked)

        store.setHubEnabled(true)

        #expect(store.preferences.isEnabled)
        #expect(store.presentation == .tucked)
    }

    @Test func disablingActiveWidgetMovesExpandedPresentationToNormalizedSelection() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        store.setHubEnabled(true)
        store.setWidget(.media, enabled: true)
        store.selectWidget(.media)

        #expect(store.presentation == .widget(.media))

        store.setWidget(.media, enabled: false)

        #expect(!store.preferences.enabledWidgetIDs.contains(.media))
        #expect(store.selectedWidgetID != .media)
        #expect(store.preferences.enabledWidgetIDs.contains(store.selectedWidgetID))
        #expect(store.presentation == .widget(store.selectedWidgetID))
    }

    @Test func optionalAndAdvancedWidgetsAppearOnlyAfterUserEnablesThem() {
        let defaults = makeEphemeralDefaults()
        let store = makeNotchHubStore(defaults: defaults)

        #expect(store.enabledWidgets == [.live, .calendar, .notes])

        store.setWidget(.media, enabled: true)
        store.setWidget(.tray, enabled: true)

        #expect(store.enabledWidgets == [.live, .media, .calendar, .notes, .tray])
    }

    @Test func mediaCommandRequestsPermissionBeforeCallingProvider() async {
        let defaults = makeEphemeralDefaults()
        let mediaProvider = MockMediaProvider()
        let store = makeNotchHubStore(defaults: defaults, mediaProvider: mediaProvider)

        store.setHubEnabled(true)
        store.open()
        store.performMediaCommand(.playPause)
        await flushAsyncWork()

        #expect(store.presentation == .permissionPrompt(.appleEvents))
        #expect(mediaProvider.commands.isEmpty)

        store.preferences.allowAppleEvents = true
        store.presentation = .widget(.media)
        store.performMediaCommand(.playPause)
        await flushAsyncWork()

        #expect(mediaProvider.commands == [.playPause])
    }
}

@MainActor
struct ScreenPlacementServiceTests {
    @Test func hubExpandedUsesLargeInteractiveCanvasWithinScreenWidth() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .presenting,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .hubExpanded
        )

        #expect(placement.frame.width == 620)
        #expect(placement.frame.height == 318)
        #expect(placement.visibleSize == placement.frame.size)
        #expect(placement.frame.midX == screen.notchFrame?.midX)
    }

    @Test func hubExpandedShrinksForNarrowFallbackDisplays() {
        let screen = ScreenDescriptor(
            displayID: 9,
            localizedName: "Narrow Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 480, height: 640),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .presenting,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .hubExpanded
        )

        #expect(placement.frame.width == 400)
        #expect(placement.frame.minX >= screen.frame.minX)
        #expect(placement.frame.maxX <= screen.frame.maxX)
    }

    @Test func hiddenOverlayMatchesPhysicalNotchFrame() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hidden,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 200, height: 38))
    }

    @Test func hiddenFallbackStaysInsideMenuBarHeight() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .hidden,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 638)
        #expect(placement.frame.size == CGSize(width: 164, height: 24))
        #expect(placement.visibleSize == CGSize(width: 164, height: 24))
    }

    @Test func pendingReminderUsesExpandedCanvasWithTuckedVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .reminderPending,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 596)
        #expect(placement.frame.size == CGSize(width: 320, height: 96))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 200, height: 38))
    }

    @Test func pendingFallbackUsesExpandedCanvasWithTuckedVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .reminderPending,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 570)
        #expect(placement.frame.size == CGSize(width: 300, height: 96))
        #expect(placement.tuckedFrame == CGRect(x: 638, y: 876, width: 164, height: 24))
        #expect(placement.visibleSize == CGSize(width: 164, height: 24))
    }

    @Test func presentingReminderUsesNotchMidpointWhenAvailable() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .presenting,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 596)
        #expect(placement.frame.size == CGSize(width: 320, height: 96))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 320, height: 96))
    }

    @Test func dismissAnimatingUsesExpandedReminderCanvas() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .dismissAnimating,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 596)
        #expect(placement.frame.size == CGSize(width: 320, height: 96))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 200, height: 38))
    }

    @Test func dismissAnimatingUsesCollapsedCanvasWhenExpansionDisabled() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .dismissAnimating,
            on: screen,
            notchExpansionEnabled: false
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 612)
        #expect(placement.frame.size == CGSize(width: 288, height: 88))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 200, height: 38))
    }

    @Test func hoverPendingAndDismissingUsePreviewCanvasWithTuckedVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )
        let service = ScreenPlacementService()

        let pending = service.placement(
            for: .hoverPreviewPending,
            on: screen,
            notchExpansionEnabled: true
        )
        let dismissing = service.placement(
            for: .hoverPreviewDismissing,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(pending.frame.size == CGSize(width: 248, height: 72))
        #expect(pending.visibleSize == CGSize(width: 200, height: 38))
        #expect(dismissing.frame.size == pending.frame.size)
        #expect(dismissing.visibleSize == pending.visibleSize)
    }

    @Test func prominentCountdownHoverUsesLargerCanvas() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .prominentCountdown
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 584)
        #expect(placement.frame.size == CGSize(width: 344, height: 96))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 344, height: 96))
    }

    @Test func dualPreviewHoverUsesBaseCanvas() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 576)
        #expect(placement.frame.size == CGSize(width: 360, height: 96))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 360, height: 96))
    }

    @Test func dualPreviewHoverExpandsToFitMeasuredContent() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 520, height: 118)
        )

        #expect(placement.topInset == 38)
        #expect(placement.frame.origin.x == 496)
        #expect(placement.frame.size == CGSize(width: 520, height: 118))
        #expect(placement.tuckedFrame == CGRect(x: 656, y: 944, width: 200, height: 38))
        #expect(placement.visibleSize == CGSize(width: 520, height: 118))
    }

    @Test func dualPreviewPendingAndDismissingUseMeasuredCanvasWithTuckedVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )
        let service = ScreenPlacementService()

        let pending = service.placement(
            for: .hoverPreviewPending,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 520, height: 118)
        )
        let dismissing = service.placement(
            for: .hoverPreviewDismissing,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 520, height: 118)
        )

        #expect(pending.frame == CGRect(x: 496, y: 864, width: 520, height: 118))
        #expect(pending.visibleSize == CGSize(width: 200, height: 38))
        #expect(dismissing.frame == pending.frame)
        #expect(dismissing.visibleSize == pending.visibleSize)
    }

    @Test func dualPreviewHoverClampsMeasuredContentToAdaptiveMaximum() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 900, height: 180)
        )

        #expect(placement.frame.origin.x == 436)
        #expect(placement.frame.size == CGSize(width: 640, height: 128))
        #expect(placement.visibleSize == CGSize(width: 640, height: 128))
    }

    @Test func dualPreviewHoverClampsMeasuredContentInsideNarrowScreen() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 500, height: 800),
            notchFrame: CGRect(x: 190, y: 762, width: 120, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 600, height: 180)
        )

        #expect(placement.frame.origin.x == 40)
        #expect(placement.frame.size == CGSize(width: 420, height: 128))
        #expect(placement.frame.minX >= screen.frame.minX)
        #expect(placement.frame.maxX <= screen.frame.maxX)
        #expect(placement.visibleSize == CGSize(width: 420, height: 128))
    }

    @Test func dualPreviewHoverUsesMeasuredContentOnNonNotchedScreenWithoutOverflow() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: false,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 480, height: 112)
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 480)
        #expect(placement.frame.size == CGSize(width: 480, height: 112))
        #expect(placement.frame.minX >= screen.frame.minX)
        #expect(placement.frame.maxX <= screen.frame.maxX)
        #expect(placement.visibleSize == CGSize(width: 480, height: 112))
    }

    @Test func dualPreviewPendingOnNonNotchedScreenUsesFitCanvasWithoutExpandingVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreviewPending,
            on: screen,
            notchExpansionEnabled: false,
            sizingRole: .dualPreview,
            contentFitSize: CGSize(width: 480, height: 112)
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 480)
        #expect(placement.frame.size == CGSize(width: 480, height: 112))
        #expect(placement.tuckedFrame == CGRect(x: 638, y: 876, width: 164, height: 24))
        #expect(placement.visibleSize == CGSize(width: 164, height: 24))
    }

    @Test func contentFitRequestDoesNotAffectStandardHoverSizing() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .standard,
            contentFitSize: CGSize(width: 640, height: 128)
        )

        #expect(placement.frame.origin.x == 632)
        #expect(placement.frame.size == CGSize(width: 248, height: 72))
        #expect(placement.visibleSize == CGSize(width: 248, height: 72))
    }

    @Test func contentFitRequestDoesNotAffectPresentingReminderSizing() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .presenting,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .standard,
            contentFitSize: CGSize(width: 640, height: 128)
        )

        #expect(placement.frame.origin.x == 596)
        #expect(placement.frame.size == CGSize(width: 320, height: 96))
        #expect(placement.visibleSize == CGSize(width: 320, height: 96))
    }

    @Test func dualPreviewPendingAndDismissingKeepTuckedVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )
        let service = ScreenPlacementService()

        let pending = service.placement(
            for: .hoverPreviewPending,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview
        )
        let dismissing = service.placement(
            for: .hoverPreviewDismissing,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .dualPreview
        )

        #expect(pending.frame.size == CGSize(width: 360, height: 96))
        #expect(pending.visibleSize == CGSize(width: 200, height: 38))
        #expect(dismissing.frame.size == pending.frame.size)
        #expect(dismissing.visibleSize == pending.visibleSize)
    }

    @Test func prominentCountdownPendingAndDismissingKeepTuckedVisibleIsland() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 656, y: 944, width: 200, height: 38),
            menuBarHeight: 38
        )
        let service = ScreenPlacementService()

        let pending = service.placement(
            for: .hoverPreviewPending,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .prominentCountdown
        )
        let dismissing = service.placement(
            for: .hoverPreviewDismissing,
            on: screen,
            notchExpansionEnabled: true,
            sizingRole: .prominentCountdown
        )

        #expect(pending.frame.size == CGSize(width: 344, height: 96))
        #expect(pending.visibleSize == CGSize(width: 200, height: 38))
        #expect(dismissing.frame.size == pending.frame.size)
        #expect(dismissing.visibleSize == pending.visibleSize)
    }

    @Test func nonNotchedScreenFallsBackToScreenCenter() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: false
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 600)
        #expect(placement.frame.size == CGSize(width: 240, height: 64))
        #expect(placement.visibleSize == CGSize(width: 240, height: 64))
    }

    @Test func prominentCountdownNonNotchedScreenFallsBackToCenteredClampedCanvas() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: false,
            sizingRole: .prominentCountdown
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 564)
        #expect(placement.frame.size == CGSize(width: 312, height: 88))
        #expect(placement.visibleSize == CGSize(width: 312, height: 88))
    }

    @Test func dualPreviewNonNotchedScreenFallsBackToCenteredClampedCanvas() {
        let screen = ScreenDescriptor(
            displayID: 2,
            localizedName: "Studio Display",
            isBuiltIn: false,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            notchFrame: nil,
            menuBarHeight: 24
        )

        let placement = ScreenPlacementService().placement(
            for: .hoverPreview,
            on: screen,
            notchExpansionEnabled: false,
            sizingRole: .dualPreview
        )

        #expect(placement.topInset == 24)
        #expect(placement.frame.origin.x == 554)
        #expect(placement.frame.size == CGSize(width: 332, height: 88))
        #expect(placement.visibleSize == CGSize(width: 332, height: 88))
    }

    @Test func compactPresentingReminderKeepsMinimumUsableWidth() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 500, height: 800),
            notchFrame: CGRect(x: 190, y: 762, width: 120, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .presenting,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.frame.origin.x == 100)
        #expect(placement.frame.size == CGSize(width: 300, height: 96))
    }

    @Test func compactPresentingReminderCapsWideNotchScreens() {
        let screen = ScreenDescriptor(
            displayID: 1,
            localizedName: "Built-in Display",
            isBuiltIn: true,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            notchFrame: CGRect(x: 626, y: 944, width: 260, height: 38),
            menuBarHeight: 38
        )

        let placement = ScreenPlacementService().placement(
            for: .presenting,
            on: screen,
            notchExpansionEnabled: true
        )

        #expect(placement.frame.origin.x == 586)
        #expect(placement.frame.size == CGSize(width: 340, height: 96))
    }
}

@MainActor
struct ScreenSelectionServiceTests {
    @Test func automaticModePrefersBuiltInNotchScreenOverMainExternalScreen() {
        let external = makeScreen(displayID: 1, isBuiltIn: false, notchFrame: nil)
        let builtInNotch = makeScreen(
            displayID: 2,
            isBuiltIn: true,
            notchFrame: CGRect(x: 620, y: 860, width: 220, height: 38)
        )

        let selected = ScreenSelectionService().selectedScreen(
            for: .automatic,
            in: [external, builtInNotch],
            mainDisplayID: external.displayID
        )

        #expect(selected?.displayID == builtInNotch.displayID)
    }

    @Test func displayModeUsesPersistedDisplayIDWhenScreenIsAvailable() {
        let builtIn = makeScreen(displayID: 1, isBuiltIn: true)
        let external = makeScreen(displayID: 2, isBuiltIn: false)

        let selected = ScreenSelectionService().selectedScreen(
            for: .display(external.displayID),
            in: [builtIn, external],
            mainDisplayID: builtIn.displayID
        )

        #expect(selected?.displayID == external.displayID)
    }

    @Test func displayModeFallsBackToAutomaticWhenPersistedScreenIsUnavailable() {
        let builtIn = makeScreen(displayID: 1, isBuiltIn: true)
        let external = makeScreen(displayID: 2, isBuiltIn: false)

        let selected = ScreenSelectionService().selectedScreen(
            for: .display(CGDirectDisplayID(99)),
            in: [external, builtIn],
            mainDisplayID: external.displayID
        )

        #expect(selected?.displayID == builtIn.displayID)
    }

    @Test func automaticModeUsesMainScreenWhenNoBuiltInScreenExists() {
        let leftExternal = makeScreen(displayID: 1, isBuiltIn: false)
        let rightExternal = makeScreen(displayID: 2, isBuiltIn: false)

        let selected = ScreenSelectionService().selectedScreen(
            for: .automatic,
            in: [leftExternal, rightExternal],
            mainDisplayID: rightExternal.displayID
        )

        #expect(selected?.displayID == rightExternal.displayID)
    }
}

@MainActor
struct FileTrayStoreTests {
    @Test func fileTrayStoresSecurityScopedBookmarksAndRemovesItems() throws {
        let defaults = makeEphemeralDefaults()
        let store = FileTrayStore(defaults: defaults)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchmove-tray-\(UUID().uuidString).txt")
        try "tray".write(to: fileURL, atomically: true, encoding: .utf8)

        try store.add([fileURL])

        #expect(store.items.count == 1)
        #expect(store.items[0].displayName == fileURL.lastPathComponent)
        let resolvedURL = try store.resolvedURL(for: store.items[0])
        #expect(resolvedURL.lastPathComponent == fileURL.lastPathComponent)

        let restored = FileTrayStore(defaults: defaults)
        #expect(restored.items.count == 1)

        restored.remove(restored.items[0])
        #expect(restored.items.isEmpty)
    }
}

@MainActor
private func makeReminderContext(now: Date) -> ReminderTestContext {
    let suiteName = "NotchMoveTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let settings = AppSettings(defaults: defaults)
    let preferencesStore = PreferencesStore(settings: settings)
    let breakStatsStore = BreakStatsStore(defaults: defaults)
    let idleProvider = TestIdleProvider()
    let soundPlayer = TestSoundPlayer()
    let clock = TestClock(now: now)
    let engine = ReminderEngine(
        activityMonitor: idleProvider,
        preferencesStore: preferencesStore,
        soundPlayer: soundPlayer,
        breakStatsStore: breakStatsStore,
        clock: clock
    )

    return ReminderTestContext(
        suiteName: suiteName,
        defaults: defaults,
        preferencesStore: preferencesStore,
        breakStatsStore: breakStatsStore,
        idleProvider: idleProvider,
        soundPlayer: soundPlayer,
        clock: clock,
        engine: engine
    )
}

@MainActor
private func makePomodoroContext(now: Date) -> PomodoroTestContext {
    let suiteName = "NotchMoveTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let settings = AppSettings(defaults: defaults)
    let preferencesStore = PreferencesStore(settings: settings)
    let breakStatsStore = BreakStatsStore(defaults: defaults)
    let clock = TestClock(now: now)
    let probe = PomodoroTestProbe()
    let engine = PomodoroEngine(
        preferencesStore: preferencesStore,
        breakStatsStore: breakStatsStore,
        clock: clock,
        onReminder: { content in
            probe.reminders.append(content)
        },
        onCountdownChanged: { content in
            probe.countdowns.append(content)
        }
    )

    return PomodoroTestContext(
        suiteName: suiteName,
        defaults: defaults,
        preferencesStore: preferencesStore,
        breakStatsStore: breakStatsStore,
        clock: clock,
        probe: probe,
        engine: engine
    )
}

@MainActor
private func makeEphemeralDefaults() -> UserDefaults {
    let suiteName = "NotchMoveTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private func makeNotchHubStore(
    defaults: UserDefaults,
    scheduleStore: DailyScheduleStore? = nil,
    mediaProvider: MockMediaProvider = MockMediaProvider(),
    calendarProvider: MockCalendarProvider = MockCalendarProvider(),
    shortcutsProvider: MockShortcutRunner = MockShortcutRunner(),
    cameraPermissionProvider: MockCameraPermissionProvider = MockCameraPermissionProvider()
) -> NotchHubStore {
    NotchHubStore(
        defaults: defaults,
        dailyScheduleStore: scheduleStore ?? DailyScheduleStore(defaults: defaults),
        mediaProvider: mediaProvider,
        calendarProvider: calendarProvider,
        shortcutsProvider: shortcutsProvider,
        cameraPermissionProvider: cameraPermissionProvider
    )
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

private func flushAsyncWork() async {
    await Task.yield()
    await Task.yield()
    await Task.yield()
    try? await Task.sleep(for: .milliseconds(10))
    await Task.yield()
}

private func promotePendingReminder(in context: ReminderTestContext) async {
    await flushAsyncWork()
    await context.clock.advance(by: ReminderEngine.reminderPresentationPreflightDelay)
    await flushAsyncWork()
}

@MainActor
private func promoteHoverPreview(in context: ReminderTestContext) async {
    context.engine.send(.hoverPreviewFitReady)
    await flushAsyncWork()
    await context.clock.advance(by: ReminderEngine.hoverPreviewPromotionDelay)
    await flushAsyncWork()
}

private func settleReminderDismissal(in context: ReminderTestContext) async {
    await flushAsyncWork()
    await context.clock.advance(by: ReminderEngine.reminderDismissSettleDelay)
    await flushAsyncWork()
}

private func settleHoverPreviewDismissal(in context: ReminderTestContext) async {
    await flushAsyncWork()
    await context.clock.advance(by: ReminderEngine.hoverPreviewDismissalDelay)
    await flushAsyncWork()
}

private func advanceClockAndFlush(_ clock: TestClock, by duration: Duration) async {
    await flushAsyncWork()
    await clock.advance(by: duration)
    await flushAsyncWork()
}

private func makeScreen(
    displayID: CGDirectDisplayID,
    isBuiltIn: Bool,
    notchFrame: CGRect? = nil
) -> ScreenDescriptor {
    ScreenDescriptor(
        displayID: displayID,
        localizedName: isBuiltIn ? "Built-in Display" : "External Display",
        isBuiltIn: isBuiltIn,
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        notchFrame: notchFrame,
        menuBarHeight: notchFrame?.height ?? 24
    )
}

@MainActor
private struct PomodoroTestContext {
    let suiteName: String
    let defaults: UserDefaults
    let preferencesStore: PreferencesStore
    let breakStatsStore: BreakStatsStore
    let clock: TestClock
    let probe: PomodoroTestProbe
    let engine: PomodoroEngine

    func cleanup() {
        engine.stop()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class PomodoroTestProbe {
    var reminders: [PomodoroReminderContent] = []
    var countdowns: [PomodoroCountdownContent?] = []
}

@MainActor
private struct ReminderTestContext {
    let suiteName: String
    let defaults: UserDefaults
    let preferencesStore: PreferencesStore
    let breakStatsStore: BreakStatsStore
    let idleProvider: TestIdleProvider
    let soundPlayer: TestSoundPlayer
    let clock: TestClock
    let engine: ReminderEngine

    func cleanup() {
        engine.send(.cancelReminder)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class TestIdleProvider: IdleTimeProviding {
    var idleSeconds: TimeInterval = 0
}

@MainActor
private final class MockMediaProvider: MediaControlProviding {
    var status = MediaPlaybackStatus(
        app: .music,
        title: "Focus",
        artist: "NotchMove",
        playbackState: .paused
    )
    private(set) var currentStatusCallCount = 0
    private(set) var commands: [MediaControlCommand] = []

    func currentStatus() async -> MediaPlaybackStatus {
        currentStatusCallCount += 1
        return status
    }

    func perform(_ command: MediaControlCommand) async -> NotchHubActionResult {
        commands.append(command)
        return .success("ok")
    }
}

@MainActor
private final class MockCalendarProvider: CalendarEventProviding {
    var didRequestAccess = false
    var accessGranted = true
    var externalItems: [NotchHubCalendarItem] = []
    private(set) var externalItemsCallCount = 0

    func requestAccess() async -> Bool {
        didRequestAccess = true
        return accessGranted
    }

    func upcomingExternalItems(limit: Int) async -> [NotchHubCalendarItem] {
        externalItemsCallCount += 1
        return Array(externalItems.prefix(limit))
    }

    func localScheduleItems(from items: [DailyScheduleItem]) -> [NotchHubCalendarItem] {
        items.map {
            NotchHubCalendarItem(
                id: "local.\($0.id.uuidString)",
                title: $0.title,
                startDate: $0.startDate,
                endDate: $0.endDate,
                source: .localSchedule
            )
        }
    }
}

@MainActor
private final class MockShortcutRunner: ShortcutRunning {
    private(set) var shortcutNames: [String] = []

    func runShortcut(named name: String) async -> NotchHubActionResult {
        shortcutNames.append(name)
        return .success("ok")
    }
}

@MainActor
private final class MockCameraPermissionProvider: CameraPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus = .notDetermined
    var accessGranted = true

    func requestAccess() async -> Bool {
        authorizationStatus = accessGranted ? .authorized : .denied
        return accessGranted
    }
}

@MainActor
private final class TestSoundPlayer: SoundPlaying {
    private(set) var cues: [ReminderSoundCue] = []

    var playCount: Int {
        cues.count
    }

    func playSound(_ cue: ReminderSoundCue) {
        cues.append(cue)
    }
}

private final class TestClock: Clock, @unchecked Sendable {
    private struct Sleeper {
        let id: UUID
        let deadline: Date
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private nonisolated(unsafe) var storedNow: Date
    private nonisolated(unsafe) var sleepers: [Sleeper] = []

    nonisolated var now: Date {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedNow
        }
        set {
            let ready = setNow(newValue)
            resume(ready)
        }
    }

    init(now: Date) {
        storedNow = now
    }

    nonisolated func sleep(for duration: Duration) async throws {
        let id = UUID()
        let deadline = now.addingTimeInterval(duration.timeInterval)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else if storedNow >= deadline {
                    lock.unlock()
                    continuation.resume()
                } else {
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: {
            if let sleeper = removeSleeper(id: id) {
                sleeper.continuation.resume(throwing: CancellationError())
            }
        }
    }

    nonisolated func advance(by duration: Duration) async {
        let ready = setNow(now.addingTimeInterval(duration.timeInterval))
        resume(ready)
        await Task.yield()
    }

    private nonisolated func setNow(_ newValue: Date) -> [Sleeper] {
        lock.lock()
        storedNow = newValue
        var ready: [Sleeper] = []
        var waiting: [Sleeper] = []
        for sleeper in sleepers {
            if sleeper.deadline <= newValue {
                ready.append(sleeper)
            } else {
                waiting.append(sleeper)
            }
        }
        sleepers = waiting
        lock.unlock()
        return ready
    }

    private nonisolated func resume(_ sleepers: [Sleeper]) {
        for sleeper in sleepers {
            sleeper.continuation.resume()
        }
    }

    private nonisolated func removeSleeper(id: UUID) -> Sleeper? {
        lock.lock()
        defer { lock.unlock() }
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
        return sleepers.remove(at: index)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let durationComponents = components
        return TimeInterval(durationComponents.seconds) +
            TimeInterval(durationComponents.attoseconds) / 1_000_000_000_000_000_000
    }
}

private final class DiagnosticsInMemoryAPIKeyStore: APIKeyStoring {
    private var credentials: [String: String] = [:]

    func credential(_ fieldID: String, for provider: AIProviderID) throws -> String? {
        credentials["\(provider.rawValue).\(fieldID)"]
    }

    func saveCredential(_ value: String, fieldID: String, for provider: AIProviderID) throws {
        credentials["\(provider.rawValue).\(fieldID)"] = value
    }

    func deleteCredential(_ fieldID: String, for provider: AIProviderID) throws {
        credentials.removeValue(forKey: "\(provider.rawValue).\(fieldID)")
    }
}

@MainActor
private final class NotificationCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
