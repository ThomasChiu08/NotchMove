//
//  DailyScheduleReminderEngine.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import AppKit
import Foundation
import Observation
import OSLog

@MainActor
protocol DailyScheduleReminderPresenting {
    func presentReminder(for item: DailyScheduleItem, actions: DailyScheduleReminderActions)
}

@MainActor
struct DailyScheduleReminderActions {
    let complete: @MainActor () -> Void
    let snooze: @MainActor (_ minutes: Int) -> Void
    let dismiss: @MainActor () -> Void
}

@MainActor
final class DailyScheduleAlertPresenter: DailyScheduleReminderPresenting {
    private let languageManager: LanguageManager

    init(languageManager: LanguageManager) {
        self.languageManager = languageManager
    }

    func presentReminder(for item: DailyScheduleItem, actions: DailyScheduleReminderActions) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = languageManager.localizedString("dashboard.reminder.alert_title")
        alert.informativeText = String(
            format: languageManager.localizedString("dashboard.reminder.alert_message_format"),
            item.title
        )
        alert.addButton(withTitle: languageManager.localizedString("ok"))
        alert.runModal()
        actions.complete()
    }
}

@MainActor
final class DailyScheduleNotchPresenter: DailyScheduleReminderPresenting {
    private let reminderEngine: ReminderEngine

    init(reminderEngine: ReminderEngine) {
        self.reminderEngine = reminderEngine
    }

    func presentReminder(for item: DailyScheduleItem, actions: DailyScheduleReminderActions) {
        reminderEngine.presentScheduleReminder(for: item, actions: actions)
    }
}

@MainActor
@Observable
final class DailyScheduleReminderEngine {
    enum Intent: Equatable {
        case tick(Date)
    }

    private let scheduleStore: DailyScheduleStore
    private let soundPlayer: SoundPlaying
    private let presenter: any DailyScheduleReminderPresenting
    private let clock: Clock
    private let calendar: Calendar
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "daily-schedule")

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var activeReminderIDs: Set<DailyScheduleItem.ID> = []

    init(
        scheduleStore: DailyScheduleStore,
        soundPlayer: SoundPlaying,
        presenter: any DailyScheduleReminderPresenting,
        clock: Clock = SystemClock(),
        calendar: Calendar = .current
    ) {
        self.scheduleStore = scheduleStore
        self.soundPlayer = soundPlayer
        self.presenter = presenter
        self.clock = clock
        self.calendar = calendar
    }

    deinit {
        tickTask?.cancel()
    }

    func start() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await self.clock.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.send(.tick(self.clock.now))
                }
            }
        }

        logger.notice("Daily schedule reminder engine started")
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    func send(_ intent: Intent) {
        switch intent {
        case .tick(let now):
            checkReminders(at: now)
        }
    }

    @discardableResult
    func checkReminders(at now: Date) -> [DailyScheduleItem] {
        guard activeReminderIDs.isEmpty else { return [] }

        let eligibleItems = scheduleStore.itemsForToday(referenceDate: now).filter { item in
            isEligibleForReminder(item, at: now)
        }

        guard let item = eligibleItems.first else { return [] }

        activeReminderIDs.insert(item.id)
        soundPlayer.playReminderSound()
        presenter.presentReminder(
            for: item,
            actions: DailyScheduleReminderActions(
                complete: { [weak self] in
                    self?.completeReminder(item.id)
                },
                snooze: { [weak self] minutes in
                    self?.snoozeReminder(item.id, minutes: minutes)
                },
                dismiss: { [weak self] in
                    self?.dismissReminder(item.id)
                }
            )
        )
        logger.notice("Daily schedule reminder fired for \(item.title, privacy: .public)")

        return [item]
    }

    private func isEligibleForReminder(_ item: DailyScheduleItem, at now: Date) -> Bool {
        guard item.isReminderEnabled,
              !item.hasReminded(on: now, calendar: calendar),
              !activeReminderIDs.contains(item.id)
        else {
            return false
        }

        if let snoozedUntilDate = item.snoozedUntilDate, now < snoozedUntilDate {
            return false
        }

        let leadSeconds = TimeInterval(max(item.reminderLeadMinutes, 0) * 60)
        let reminderWindowStart = item.startDate.addingTimeInterval(-leadSeconds)
        let reminderWindowEnd = item.endDate ?? item.startDate.addingTimeInterval(60 * 60)

        return now >= reminderWindowStart && now <= reminderWindowEnd
    }

    private func completeReminder(_ id: DailyScheduleItem.ID) {
        activeReminderIDs.remove(id)
        scheduleStore.markReminded(id, at: clock.now)
    }

    private func snoozeReminder(_ id: DailyScheduleItem.ID, minutes: Int) {
        activeReminderIDs.remove(id)
        let snoozeUntil = clock.now.addingTimeInterval(TimeInterval(max(minutes, 1) * 60))
        scheduleStore.snooze(id, until: snoozeUntil)
        logger.notice("Daily schedule reminder snoozed for \(minutes) minutes")
    }

    private func dismissReminder(_ id: DailyScheduleItem.ID) {
        activeReminderIDs.remove(id)
        scheduleStore.markReminded(id, at: clock.now)
    }
}
