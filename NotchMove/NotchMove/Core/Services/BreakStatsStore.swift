//
//  BreakStatsStore.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import Foundation

struct BreakDaySummary: Identifiable, Equatable {
    let date: Date
    let count: Int

    var id: Date { date }
}

@MainActor
@Observable
final class BreakStatsStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let dateProvider: @Sendable () -> Date

    private(set) var todayBreaks: Int = 0
    private(set) var weekBreaks: Int = 0

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        dateProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.dateProvider = dateProvider
        refresh()
    }

    func refresh() {
        let date = dateProvider()
        todayBreaks = defaults.integer(forKey: todayBreaksKey(for: date))
        weekBreaks = defaults.integer(forKey: weekBreaksKey(for: date))
    }

    func recordIfCompleted(_ outcome: ReminderOutcome) {
        guard outcome == .completedBreak else { return }
        recordCompletedBreak()
    }

    func reset() {
        let date = dateProvider()
        defaults.set(0, forKey: todayBreaksKey(for: date))
        defaults.set(0, forKey: weekBreaksKey(for: date))
        refresh()
    }

    func breaks(on date: Date) -> Int {
        defaults.integer(forKey: todayBreaksKey(for: date))
    }

    func weekBreaksByDay(referenceDate: Date? = nil) -> [BreakDaySummary] {
        let date = referenceDate ?? dateProvider()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return [BreakDaySummary(date: date, count: breaks(on: date))]
        }

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else {
                return nil
            }

            return BreakDaySummary(date: day, count: breaks(on: day))
        }
    }

    private func todayBreaksKey(for date: Date) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "breaks_%04d-%02d-%02d", year, month, day)
    }

    private func weekBreaksKey(for date: Date) -> String {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "breaksWeek_%04d-W%02d", year, week)
    }

    private func recordCompletedBreak() {
        let date = dateProvider()
        let todayKey = todayBreaksKey(for: date)
        let weekKey = weekBreaksKey(for: date)
        defaults.set(defaults.integer(forKey: todayKey) + 1, forKey: todayKey)
        defaults.set(defaults.integer(forKey: weekKey) + 1, forKey: weekKey)
        refresh()
    }
}
