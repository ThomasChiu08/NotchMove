//
//  DailyScheduleImportParser.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct DailyScheduleImportResult: Equatable {
    var items: [DailyScheduleItem]
    var errors: [DailyScheduleImportError]
}

struct DailyScheduleImportError: Error, Identifiable, Equatable {
    enum Reason: Equatable {
        case invalidTime
        case missingTitle
        case endBeforeStart

        var localizationKey: String {
            switch self {
            case .invalidTime:
                "dashboard.import.error.invalid_time"
            case .missingTitle:
                "dashboard.import.error.missing_title"
            case .endBeforeStart:
                "dashboard.import.error.end_before_start"
            }
        }
    }

    let lineNumber: Int
    let line: String
    let reason: Reason

    var id: Int { lineNumber }
}

struct DailyScheduleImportParser {
    func parse(
        _ text: String,
        defaultDate: Date = .now,
        calendar: Calendar = .current
    ) -> DailyScheduleImportResult {
        var items: [DailyScheduleItem] = []
        var errors: [DailyScheduleImportError] = []

        for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            switch parseLine(line, lineNumber: lineNumber, defaultDate: defaultDate, calendar: calendar) {
            case .success(let item):
                items.append(item)
            case .failure(let error):
                errors.append(error)
            }
        }

        return DailyScheduleImportResult(
            items: items.sorted { $0.startDate < $1.startDate },
            errors: errors
        )
    }

    private func parseLine(
        _ line: String,
        lineNumber: Int,
        defaultDate: Date,
        calendar: Calendar
    ) -> Result<DailyScheduleItem, DailyScheduleImportError> {
        guard let start = parseTimePrefix(in: line) else {
            return .failure(error(lineNumber: lineNumber, line: line, reason: .invalidTime))
        }

        var remainder = start.remainder.trimmingCharacters(in: .whitespaces)
        var endDate: Date?

        if remainder.first == "-" {
            remainder.removeFirst()
            remainder = remainder.trimmingCharacters(in: .whitespaces)

            guard let end = parseTimePrefix(in: remainder) else {
                return .failure(error(lineNumber: lineNumber, line: line, reason: .invalidTime))
            }

            guard let parsedEndDate = date(
                on: defaultDate,
                hour: end.hour,
                minute: end.minute,
                calendar: calendar
            ) else {
                return .failure(error(lineNumber: lineNumber, line: line, reason: .invalidTime))
            }

            endDate = parsedEndDate
            remainder = end.remainder.trimmingCharacters(in: .whitespaces)
        }

        let title = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return .failure(error(lineNumber: lineNumber, line: line, reason: .missingTitle))
        }

        guard let startDate = date(on: defaultDate, hour: start.hour, minute: start.minute, calendar: calendar) else {
            return .failure(error(lineNumber: lineNumber, line: line, reason: .invalidTime))
        }

        if let endDate, endDate <= startDate {
            return .failure(error(lineNumber: lineNumber, line: line, reason: .endBeforeStart))
        }

        return .success(DailyScheduleItem(title: title, startDate: startDate, endDate: endDate))
    }

    private func parseTimePrefix(in text: String) -> (hour: Int, minute: Int, remainder: String)? {
        guard text.count >= 5 else { return nil }

        let characters = Array(text.prefix(5))
        guard characters[0].isNumber,
              characters[1].isNumber,
              characters[2] == ":",
              characters[3].isNumber,
              characters[4].isNumber
        else {
            return nil
        }

        let hourText = String(characters[0...1])
        let minuteText = String(characters[3...4])
        guard let hour = Int(hourText),
              let minute = Int(minuteText),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }

        let remainderStart = text.index(text.startIndex, offsetBy: 5)
        return (hour, minute, String(text[remainderStart...]))
    }

    private func date(on date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components)
    }

    private func error(
        lineNumber: Int,
        line: String,
        reason: DailyScheduleImportError.Reason
    ) -> DailyScheduleImportError {
        DailyScheduleImportError(lineNumber: lineNumber, line: line, reason: reason)
    }
}
