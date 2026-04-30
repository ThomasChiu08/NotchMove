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
        let transcript = try await transcriptionProvider.transcribe(
            recording: recording,
            context: transcriptionContext
        )
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
        var result = try await parserProvider.parseSchedule(
            transcript: transcript,
            context: parseContext
        )
        result.transcriptText = transcript.text
        return result.validatedAgainstContext(parseContext)
    }

    private func makeTranscriptionProvider() throws -> any TranscriptionProvider {
        if let transcriptionProviderOverride {
            return transcriptionProviderOverride
        }

        guard preferences.transcriptionProviderID == AIProviderID.openAI.rawValue else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: preferences.transcriptionProviderID,
                message: "Unsupported transcription provider."
            )
        }

        guard let apiKey = try preferences.openAIAPIKey(), !apiKey.isEmpty else {
            throw AIScheduleAssistantError.missingAPIKey(provider: AIProviderID.openAI.displayName)
        }

        return OpenAITranscriptionProvider(
            apiKey: apiKey,
            model: preferences.transcriptionModel
        )
    }

    private func makeParserProvider() throws -> any ScheduleParserProvider {
        if let parserProviderOverride {
            return parserProviderOverride
        }

        guard preferences.parserProviderID == AIProviderID.openAI.rawValue else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: preferences.parserProviderID,
                message: "Unsupported parser provider."
            )
        }

        guard let apiKey = try preferences.openAIAPIKey(), !apiKey.isEmpty else {
            throw AIScheduleAssistantError.missingAPIKey(provider: AIProviderID.openAI.displayName)
        }

        return OpenAIScheduleParserProvider(
            apiKey: apiKey,
            model: preferences.parserModel
        )
    }
}
