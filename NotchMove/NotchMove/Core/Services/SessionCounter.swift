//
//  SessionCounter.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import Foundation

/// Tracks the number of completed stand-break reminders per day and per ISO week.
///
/// Counts are persisted in `UserDefaults` under date-keyed entries so they
/// naturally reset at midnight without any explicit cleanup job.
final class SessionCounter {
    private let defaults = UserDefaults.standard

    /// Number of completed breaks today.
    var todayBreaks: Int { defaults.integer(forKey: todayKey) }

    /// Number of completed breaks in the current ISO calendar week.
    var weekBreaks: Int { defaults.integer(forKey: weekKey) }

    /// Record one completed stand break.
    func recordBreak() {
        defaults.set(todayBreaks + 1, forKey: todayKey)
        defaults.set(weekBreaks + 1, forKey: weekKey)
    }

    // MARK: - Keys

    private var todayKey: String {
        "breaks_\(isoDate(.now))"
    }

    private var weekKey: String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: .now)
        let year = cal.component(.yearForWeekOfYear, from: .now)
        return String(format: "breaksWeek_%04d-W%02d", year, week)
    }

    private func isoDate(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
