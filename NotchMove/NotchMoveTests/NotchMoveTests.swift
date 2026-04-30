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
        store.preferences.launchAtLoginEnabled = false
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

        #expect(preferences.launchAtLoginEnabled)

        preferences.launchAtLoginEnabled = false
        settings.save(preferences)

        #expect(!settings.loadPreferences().launchAtLoginEnabled)

        preferences.launchAtLoginEnabled = true
        settings.save(preferences)

        #expect(settings.loadPreferences().launchAtLoginEnabled)
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

    @Test func intervalAndSitAwareChangesPostReminderRuntimeNotifications() async {
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

        store.preferences.reminderIntervalMinutes = 45
        store.preferences.sitAwareEnabled = false

        await flushAsyncWork()

        #expect(reminderRuntimeNotifications.count == 2)
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

    @Test func automaticReminderPresentsImmediatelyAndPlaysSound() {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 1
        context.idleProvider.idleSeconds = 0

        context.engine.send(.tick(now))
        context.clock.now = now.addingTimeInterval(60)
        context.engine.send(.tick(context.clock.now))

        #expect(context.engine.state.presentation == .presenting)
        #expect(context.engine.isReminderPresenting)
        #expect(context.soundPlayer.playCount == 1)

        context.engine.send(.hoverChanged(false))
        #expect(context.engine.state.presentation == .presenting)
    }

    @Test func sitAwareDisabledContinuesCountingDuringIdleTime() {
        let now = makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0)
        let context = makeReminderContext(now: now)
        defer { context.cleanup() }

        context.preferencesStore.preferences.reminderIntervalMinutes = 1
        context.preferencesStore.preferences.sitAwareEnabled = false
        context.idleProvider.idleSeconds = 600

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

    @Test func autoDismissPreferenceChangeUpdatesOverlayDuration() async {
        let context = makeReminderContext(now: makeDate(year: 2026, month: 4, day: 20, hour: 9, minute: 0))
        defer { context.cleanup() }

        context.engine.send(.manualTrigger)
        #expect(context.engine.overlayState.reminderDuration == 60)

        context.preferencesStore.preferences.autoDismissSeconds = 90
        await flushAsyncWork()

        #expect(context.engine.overlayState.reminderDuration == 90)
    }
}

@MainActor
struct ScreenPlacementServiceTests {
    @Test func tuckedReminderMatchesPhysicalNotchFrame() {
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
        #expect(placement.frame == CGRect(x: 656, y: 944, width: 200, height: 38))
    }

    @Test func tuckedFallbackStaysInsideMenuBarHeight() {
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
        #expect(placement.frame.origin.x == 638)
        #expect(placement.frame.size == CGSize(width: 164, height: 24))
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

@MainActor
private final class NotificationCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
