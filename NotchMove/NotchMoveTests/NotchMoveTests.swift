//
//  NotchMoveTests.swift
//  NotchMoveTests
//
//  Created by Thomas Chiu on 4/16/26.
//

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
struct PreferencesStoreTests {
    @Test func restoreDefaultsResetsLanguageAndBehavior() {
        let suiteName = "NotchMoveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let store = PreferencesStore(settings: settings)

        store.preferences.soundEnabled = false
        store.preferences.reminderIntervalMinutes = 60
        store.preferences.appLanguage = "ja"

        store.restoreDefaults()

        #expect(store.preferences == .defaults)
        #expect(settings.loadPreferences() == .defaults)
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

    @Test func automaticReminderTransitionsToPresentingAndPlaysSound() {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 1
        context.idleProvider.idleSeconds = 0

        context.engine.send(.tick(now))
        context.clock.now = now.addingTimeInterval(60)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.state.presentation == .presenting)
        #expect(context.soundPlayer.playCount == 1)
    }

    @Test func completedBreakIncrementsStatistics() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        context.engine.send(.completeBreak)
        await flushAsyncWork()

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.breakStatsStore.todayBreaks == 1)
        #expect(context.breakStatsStore.weekBreaks == 1)
    }

    @Test func autoDismissDoesNotIncrementStatistics() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        context.engine.send(.autoDismiss)
        await flushAsyncWork()

        #expect(context.engine.state.presentation == .hidden)
        #expect(context.breakStatsStore.todayBreaks == 0)
        #expect(context.breakStatsStore.weekBreaks == 0)
    }

    @Test func preferencesChangeToBlockedScheduleCancelsActiveReminder() async {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 22, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
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

    @Test func disablingHoverPreviewClearsPreviewImmediately() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.hoverChanged(true))
        #expect(context.engine.state.presentation == .hoverPreview)

        context.preferencesStore.preferences.hoverPreviewEnabled = false
        await flushAsyncWork()

        #expect(context.engine.state.presentation == .hidden)
    }
}

@MainActor
struct ScreenPlacementServiceTests {
    @Test func presentingReminderUsesNotchMidpointWhenAvailable() {
        let screen = ScreenDescriptor(
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
        #expect(placement.frame.origin.x == 566)
        #expect(placement.frame.size == CGSize(width: 380, height: 160))
    }

    @Test func nonNotchedScreenFallsBackToScreenCenter() {
        let screen = ScreenDescriptor(
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
        #expect(placement.frame.origin.x == 590)
        #expect(placement.frame.size == CGSize(width: 260, height: 84))
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
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class TestIdleProvider: IdleTimeProviding {
    var idleSeconds: TimeInterval = 0
}

@MainActor
private final class TestSoundPlayer: SoundPlaying {
    private(set) var playCount = 0

    func playReminderSound() {
        playCount += 1
    }
}

private final class TestClock: Clock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func sleep(for duration: Duration) async throws {}
}
