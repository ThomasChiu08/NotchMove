//
//  DailyScheduleItem.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct DailyScheduleItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var reminderLeadMinutes: Int
    var isReminderEnabled: Bool
    var lastRemindedDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        reminderLeadMinutes: Int = 10,
        isReminderEnabled: Bool = true,
        lastRemindedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.reminderLeadMinutes = reminderLeadMinutes
        self.isReminderEnabled = isReminderEnabled
        self.lastRemindedDate = lastRemindedDate
    }

    var hasRemindedToday: Bool {
        guard let lastRemindedDate else { return false }
        return Calendar.current.isDateInToday(lastRemindedDate)
    }

    func hasReminded(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let lastRemindedDate else { return false }
        return calendar.isDate(lastRemindedDate, inSameDayAs: date)
    }
}
