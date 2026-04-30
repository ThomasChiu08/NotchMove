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
    func presentReminder(for item: DailyScheduleItem)
}

@MainActor
final class DailyScheduleAlertPresenter: DailyScheduleReminderPresenting {
    private let languageManager: LanguageManager

    init(languageManager: LanguageManager) {
        self.languageManager = languageManager
    }

    func presentReminder(for item: DailyScheduleItem) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = languageManager.localizedString("dashboard.reminder.alert_title")
        alert.informativeText = String(
            format: languageManager.localizedString("dashboard.reminder.alert_message_format"),
            item.title
        )
        alert.addButton(withTitle: languageManager.localizedString("ok"))
        alert.runModal()
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
        let eligibleItems = scheduleStore.itemsForToday(referenceDate: now).filter { item in
            guard item.isReminderEnabled, !item.hasReminded(on: now, calendar: calendar) else { return false }
            let leadSeconds = TimeInterval(max(item.reminderLeadMinutes, 0) * 60)
            return now >= item.startDate.addingTimeInterval(-leadSeconds)
        }

        for item in eligibleItems {
            soundPlayer.playReminderSound()
            presenter.presentReminder(for: item)
            scheduleStore.markReminded(item.id, at: now)
            logger.notice("Daily schedule reminder fired for \(item.title, privacy: .public)")
        }

        return eligibleItems
    }
}
