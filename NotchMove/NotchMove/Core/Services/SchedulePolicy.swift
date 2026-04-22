//
//  SchedulePolicy.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/21/26.
//

import Foundation

struct SchedulePolicy {
    enum Evaluation: Equatable {
        case disabled
        case allowed
        case blocked
        case invalid

        var blocksAutomaticReminders: Bool {
            switch self {
            case .blocked, .invalid:
                true
            case .disabled, .allowed:
                false
            }
        }
    }

    static func evaluate(
        _ schedule: Preferences.Schedule,
        at date: Date,
        calendar: Calendar = .current
    ) -> Evaluation {
        guard schedule.isEnabled else { return .disabled }
        guard schedule.hasValidTimeRange else { return .invalid }

        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let hour = components.hour,
              let minute = components.minute,
              let weekday = components.weekday else {
            return .invalid
        }

        if schedule.weekdaysOnly {
            let isWeekend = weekday == 1 || weekday == 7
            if isWeekend {
                return .blocked
            }
        }

        let currentMinutes = hour * 60 + minute
        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute
        return currentMinutes >= startMinutes && currentMinutes < endMinutes ? .allowed : .blocked
    }
}
