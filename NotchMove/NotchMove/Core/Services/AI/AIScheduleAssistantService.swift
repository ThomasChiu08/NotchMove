//
//  AIScheduleAssistantService.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

@MainActor
final class AIScheduleAssistantService {
    enum Progress {
        case transcribing
        case parsing
    }

    private let preferences: AIProviderPreferences
    private let transcriptionProviderOverride: (any TranscriptionProvider)?
    private let parserProviderOverride: (any ScheduleParserProvider)?
    private let dateProvider: () -> Date

    init(
        preferences: AIProviderPreferences,
        transcriptionProvider: (any TranscriptionProvider)? = nil,
        parserProvider: (any ScheduleParserProvider)? = nil,
        dateProvider: @escaping () -> Date = { .now }
    ) {
        self.preferences = preferences
        self.transcriptionProviderOverride = transcriptionProvider
        self.parserProviderOverride = parserProvider
        self.dateProvider = dateProvider
    }

    func createDrafts(
        from recording: AudioRecordingFile,
        existingScheduleItems: [DailyScheduleItem],
        localeIdentifier: String,
        appLanguage: String,
        timeZone: TimeZone = .current,
        progress: ((Progress) -> Void)? = nil
    ) async throws -> ScheduleParseResult {
        defer {
            try? recording.deleteTemporaryFile()
        }

        guard preferences.isEnabled || transcriptionProviderOverride != nil else {
            throw AIScheduleAssistantError.disabled
        }

        let transcriptionProvider = try makeTranscriptionProvider()
        let parserProvider = try makeParserProvider()
        let transcriptionContext = TranscriptionContext(
            localeIdentifier: localeIdentifier,
            languageMode: preferences.languageMode
        )

        progress?(.transcribing)
        try Task.checkCancellation()
        let transcript = try await transcriptionProvider.transcribe(
            recording: recording,
            context: transcriptionContext
        )
        try Task.checkCancellation()
        guard !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIScheduleAssistantError.emptyTranscript
        }

        let parseContext = ScheduleParseContext(
            currentDate: dateProvider(),
            timeZone: timeZone,
            localeIdentifier: localeIdentifier,
            appLanguage: appLanguage,
            defaultReminderLeadMinutes: preferences.defaultReminderLeadMinutes,
            existingScheduleItems: existingScheduleItems
        )
        progress?(.parsing)
        try Task.checkCancellation()
        var result = try await parserProvider.parseSchedule(
            transcript: transcript,
            context: parseContext
        )
        try Task.checkCancellation()
        result.transcriptText = transcript.text
        return result.validatedAgainstContext(parseContext)
    }

    private func makeTranscriptionProvider() throws -> any TranscriptionProvider {
        if let transcriptionProviderOverride {
            return transcriptionProviderOverride
        }

        return try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)
    }

    private func makeParserProvider() throws -> any ScheduleParserProvider {
        if let parserProviderOverride {
            return parserProviderOverride
        }

        return try AIProviderFactory.makeParserProvider(preferences: preferences)
    }
}
