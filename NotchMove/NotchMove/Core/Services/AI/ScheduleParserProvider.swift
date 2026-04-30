//
//  ScheduleParserProvider.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct ScheduleParseContext: Equatable {
    var currentDate: Date
    var timeZone: TimeZone
    var localeIdentifier: String
    var appLanguage: String
    var defaultReminderLeadMinutes: Int
    var existingScheduleItems: [DailyScheduleItem]
}

protocol ScheduleParserProvider {
    var displayName: String { get }
    func parseSchedule(transcript: Transcript, context: ScheduleParseContext) async throws -> ScheduleParseResult
}
