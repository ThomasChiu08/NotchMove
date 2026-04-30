//
//  DailyScheduleTests.swift
//  NotchMoveTests
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Testing
@testable import NotchMove

@MainActor
struct DailyScheduleImportParserTests {
    @Test func parsesTextScheduleLines() {
        let calendar = makeDailyScheduleCalendar()
        let baseDate = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 8, minute: 0)

        let result = DailyScheduleImportParser().parse(
            """
            09:00-10:00 Product meeting
            14:30 Write code
            """,
            defaultDate: baseDate,
            calendar: calendar
        )

        #expect(result.errors.isEmpty)
        #expect(result.items.count == 2)
        #expect(result.items[0].title == "Product meeting")
        #expect(result.items[0].startDate == makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 0))
        #expect(result.items[0].endDate == makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 10, minute: 0))
        #expect(result.items[0].reminderLeadMinutes == 10)
        #expect(result.items[0].isReminderEnabled)
        #expect(result.items[1].title == "Write code")
        #expect(result.items[1].startDate == makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 14, minute: 30))
        #expect(result.items[1].endDate == nil)
    }

    @Test func reportsInvalidLinesWithoutThrowingAwayValidRows() {
        let calendar = makeDailyScheduleCalendar()
        let baseDate = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 8, minute: 0)

        let result = DailyScheduleImportParser().parse(
            """
            25:00 Invalid
            09:00
            10:00-09:00 Backwards
            11:00 Valid
            """,
            defaultDate: baseDate,
            calendar: calendar
        )

        #expect(result.items.map(\.title) == ["Valid"])
        #expect(result.errors.map(\.lineNumber) == [1, 2, 3])
        #expect(result.errors.map(\.reason) == [.invalidTime, .missingTitle, .endBeforeStart])
    }
}

@MainActor
struct DailyScheduleStoreTests {
    @Test func persistsCodableItemsInUserDefaults() {
        let context = makeDailyScheduleStoreContext(now: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 0))
        defer { context.cleanup() }

        let item = DailyScheduleItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Planning",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 10, minute: 0),
            endDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 11, minute: 0),
            notes: "Room A",
            reminderLeadMinutes: 15,
            isReminderEnabled: true
        )

        context.store.add(item)

        let restoredStore = DailyScheduleStore(
            defaults: context.defaults,
            calendar: context.calendar,
            dateProvider: { context.now }
        )

        #expect(restoredStore.items == [item])
    }

    @Test func itemsForTodayFiltersAndSortsByStartDate() {
        let now = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 0)
        let context = makeDailyScheduleStoreContext(now: now)
        defer { context.cleanup() }

        let tomorrow = DailyScheduleItem(
            title: "Tomorrow",
            startDate: makeDailyScheduleDate(year: 2026, month: 5, day: 1, hour: 9, minute: 0)
        )
        let laterToday = DailyScheduleItem(
            title: "Later",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 16, minute: 0)
        )
        let earlierToday = DailyScheduleItem(
            title: "Earlier",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 8, minute: 30)
        )

        context.store.add(tomorrow)
        context.store.add(laterToday)
        context.store.add(earlierToday)

        #expect(context.store.itemsForToday().map(\.title) == ["Earlier", "Later"])
    }

    @Test func replaceImportedItemsReplacesOnlyToday() {
        let now = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 0)
        let context = makeDailyScheduleStoreContext(now: now)
        defer { context.cleanup() }

        context.store.add(DailyScheduleItem(
            title: "Old Today",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 10, minute: 0)
        ))
        context.store.add(DailyScheduleItem(
            title: "Tomorrow",
            startDate: makeDailyScheduleDate(year: 2026, month: 5, day: 1, hour: 10, minute: 0)
        ))

        context.store.replaceImportedItems([
            DailyScheduleItem(
                title: "Imported Today",
                startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 14, minute: 0)
            )
        ])

        #expect(context.store.items.map(\.title) == ["Imported Today", "Tomorrow"])
    }

    @Test func markRemindedRecordsTodayState() {
        let now = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 0)
        let context = makeDailyScheduleStoreContext(now: now)
        defer { context.cleanup() }

        let item = context.store.add(DailyScheduleItem(
            title: "Standup",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 30)
        ))

        context.store.markReminded(item.id, at: now)

        #expect(context.store.items[0].hasReminded(on: now, calendar: context.calendar))
    }
}

@MainActor
struct DailyScheduleReminderEngineTests {
    @Test func firesAtLeadTimeAndAvoidsRepeatingForSameDay() {
        let now = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 50)
        let context = makeDailyScheduleReminderContext(now: now)
        defer { context.cleanup() }

        let item = context.store.add(DailyScheduleItem(
            title: "Design review",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 10, minute: 0),
            reminderLeadMinutes: 10
        ))

        let firedItems = context.engine.checkReminders(at: now)

        #expect(firedItems.map(\.id) == [item.id])
        #expect(context.soundPlayer.playCount == 1)
        #expect(context.presenter.presentedIDs == [item.id])
        #expect(context.store.items[0].hasReminded(on: now, calendar: context.calendar))

        context.engine.checkReminders(at: now.addingTimeInterval(30))

        #expect(context.soundPlayer.playCount == 1)
        #expect(context.presenter.presentedIDs == [item.id])
    }

    @Test func doesNotFireBeforeLeadTimeOrWhenDisabled() {
        let now = makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 49)
        let context = makeDailyScheduleReminderContext(now: now)
        defer { context.cleanup() }

        context.store.add(DailyScheduleItem(
            title: "Too early",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 10, minute: 0),
            reminderLeadMinutes: 10
        ))
        context.store.add(DailyScheduleItem(
            title: "Disabled",
            startDate: makeDailyScheduleDate(year: 2026, month: 4, day: 30, hour: 9, minute: 49),
            reminderLeadMinutes: 0,
            isReminderEnabled: false
        ))

        let firedItems = context.engine.checkReminders(at: now)

        #expect(firedItems.isEmpty)
        #expect(context.soundPlayer.playCount == 0)
        #expect(context.presenter.presentedIDs.isEmpty)
    }
}

@MainActor
private func makeDailyScheduleStoreContext(now: Date) -> DailyScheduleStoreTestContext {
    let suiteName = "NotchMoveDailyScheduleTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let calendar = makeDailyScheduleCalendar()
    let store = DailyScheduleStore(defaults: defaults, calendar: calendar, dateProvider: { now })

    return DailyScheduleStoreTestContext(
        suiteName: suiteName,
        defaults: defaults,
        calendar: calendar,
        now: now,
        store: store
    )
}

@MainActor
private func makeDailyScheduleReminderContext(now: Date) -> DailyScheduleReminderTestContext {
    let storeContext = makeDailyScheduleStoreContext(now: now)
    let soundPlayer = DailyScheduleTestSoundPlayer()
    let presenter = DailyScheduleTestPresenter()
    let clock = DailyScheduleTestClock(now: now)
    let engine = DailyScheduleReminderEngine(
        scheduleStore: storeContext.store,
        soundPlayer: soundPlayer,
        presenter: presenter,
        clock: clock,
        calendar: storeContext.calendar
    )

    return DailyScheduleReminderTestContext(
        storeContext: storeContext,
        soundPlayer: soundPlayer,
        presenter: presenter,
        clock: clock,
        engine: engine
    )
}

private func makeDailyScheduleCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makeDailyScheduleDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = makeDailyScheduleCalendar()
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

@MainActor
private struct DailyScheduleStoreTestContext {
    let suiteName: String
    let defaults: UserDefaults
    let calendar: Calendar
    let now: Date
    let store: DailyScheduleStore

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private struct DailyScheduleReminderTestContext {
    let storeContext: DailyScheduleStoreTestContext
    let soundPlayer: DailyScheduleTestSoundPlayer
    let presenter: DailyScheduleTestPresenter
    let clock: DailyScheduleTestClock
    let engine: DailyScheduleReminderEngine

    var store: DailyScheduleStore { storeContext.store }
    var calendar: Calendar { storeContext.calendar }

    func cleanup() {
        storeContext.cleanup()
    }
}

@MainActor
private final class DailyScheduleTestSoundPlayer: SoundPlaying {
    private(set) var playCount = 0

    func playReminderSound() {
        playCount += 1
    }
}

@MainActor
private final class DailyScheduleTestPresenter: DailyScheduleReminderPresenting {
    private(set) var presentedIDs: [DailyScheduleItem.ID] = []

    func presentReminder(for item: DailyScheduleItem) {
        presentedIDs.append(item.id)
    }
}

private final class DailyScheduleTestClock: Clock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func sleep(for duration: Duration) async throws {}
}
