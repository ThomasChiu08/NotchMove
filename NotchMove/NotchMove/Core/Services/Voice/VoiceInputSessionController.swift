//
//  VoiceInputSessionController.swift
//  NotchMove
//
//  Created by Codex on 5/14/26.
//

import AppKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class VoiceInputSessionController {
    enum Phase: Equatable {
        case idle
        case recording(startedAt: Date)
        case processing
        case inserted(TextInsertionOutcome)
        case failed(String)
    }

    private let preferences: AIProviderPreferences
    private let languageManager: LanguageManager
    private let captureService: AudioCaptureService
    private let insertionService: TextInsertionService
    private let cleanupService: VoiceTextCleanupService
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "voice-input")

    @ObservationIgnored private var processingTask: Task<Void, Never>?
    @ObservationIgnored private var resetTask: Task<Void, Never>?

    private(set) var phase: Phase = .idle
    private(set) var lastRawTranscript = ""
    private(set) var lastCleanedText = ""

    init(
        preferences: AIProviderPreferences,
        languageManager: LanguageManager,
        captureService: AudioCaptureService = AudioCaptureService(),
        insertionService: TextInsertionService = TextInsertionService(),
        cleanupService: VoiceTextCleanupService? = nil
    ) {
        self.preferences = preferences
        self.languageManager = languageManager
        self.captureService = captureService
        self.insertionService = insertionService
        self.cleanupService = cleanupService ?? VoiceTextCleanupService(preferences: preferences)
    }

    var isOverlayVisible: Bool {
        switch phase {
        case .idle:
            false
        case .recording, .processing, .inserted, .failed:
            true
        }
    }

    var isRecording: Bool {
        if case .recording = phase { return true }
        return false
    }

    func beginPushToTalk() {
        guard case .idle = phase else { return }
        resetTask?.cancel()
        processingTask?.cancel()

        processingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await captureService.startRecording()
                phase = .recording(startedAt: .now)
                logger.notice("Voice input recording started")
            } catch {
                fail(error)
            }
        }
    }

    func endPushToTalk() {
        guard case .recording(let startedAt) = phase else { return }

        if Date().timeIntervalSince(startedAt) < 0.25 {
            captureService.cancelRecording()
            phase = .idle
            return
        }

        do {
            let recording = try captureService.stopRecording()
            phase = .processing
            processingTask = Task { @MainActor [weak self] in
                await self?.process(recording)
            }
        } catch {
            fail(error)
        }
    }

    func toggleFromMenu() {
        if isRecording {
            endPushToTalk()
        } else if case .idle = phase {
            beginPushToTalk()
        }
    }

    func cancel() {
        processingTask?.cancel()
        resetTask?.cancel()
        captureService.cancelRecording()
        phase = .idle
    }

    func undoLastInsertion() {
        insertionService.undoLastInsertion()
        phase = .idle
    }

    private func process(_ recording: AudioRecordingFile) async {
        defer {
            try? recording.deleteTemporaryFile()
        }

        do {
            let provider = try makeTranscriptionProvider()
            let transcript = try await provider.transcribe(
                recording: recording,
                context: TranscriptionContext(
                    localeIdentifier: languageManager.locale.identifier,
                    languageMode: preferences.languageMode
                )
            )
            let transcriptText = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcriptText.isEmpty else {
                throw AIScheduleAssistantError.emptyTranscript
            }

            lastRawTranscript = transcriptText
            let cleanedText = await cleanupService.clean(
                text: transcriptText,
                context: VoiceTextCleanupContext(
                    localeIdentifier: languageManager.locale.identifier,
                    appName: NSWorkspace.shared.frontmostApplication?.localizedName,
                    personalTerms: []
                )
            )
            lastCleanedText = cleanedText

            let outcome = await insertionService.insert(cleanedText)
            phase = .inserted(outcome)
            scheduleReset(after: outcome.didReachTargetApp ? 2.4 : 5.0)
            logger.notice("Voice input completed with outcome: \(String(describing: outcome), privacy: .public)")
        } catch {
            fail(AIProviderFactory.redactedProviderError(error, preferences: preferences))
        }
    }

    private func makeTranscriptionProvider() throws -> any TranscriptionProvider {
        guard preferences.isEnabled else {
            return AppleSpeechTranscriptionProvider(
                preferredLocaleIdentifier: AppleSpeechTranscriptionProvider.automaticLocaleID
            )
        }

        return try AIProviderFactory.makeTranscriptionProvider(preferences: preferences)
    }

    private func fail(_ error: Error) {
        captureService.cancelRecording()
        let message = VoiceInputErrorMessage.userMessage(for: error)
        phase = .failed(message)
        scheduleReset(after: 5.0)
        logger.error("Voice input failed: \(message, privacy: .public)")
    }

    private func scheduleReset(after seconds: TimeInterval) {
        resetTask?.cancel()
        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.phase = .idle
        }
    }
}

enum VoiceInputErrorMessage {
    static func userMessage(for error: Error) -> String {
        guard let assistantError = error as? AIScheduleAssistantError else {
            return error.localizedDescription
        }

        switch assistantError {
        case .disabled:
            return "Enable AI Assistant and choose a transcription provider in Settings."
        case .missingAPIKey(let provider):
            return "\(provider) API key is missing."
        case .missingCredential(let provider, let field):
            return "\(provider) \(field) is missing."
        case .microphoneDenied:
            return "Microphone access is denied."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .emptyTranscript:
            return "No speech was detected."
        case .networkUnavailable:
            return "Network unavailable."
        case .providerAuthenticationFailed(let provider):
            return "\(provider) rejected the API key."
        case .providerRequestFailed(let provider, let statusCode, let message):
            return "\(provider) request failed (\(statusCode)): \(message)"
        case .providerResponseInvalid(let provider, let message):
            return "\(provider) returned an invalid response: \(message)"
        case .invalidParserJSON(let provider, let message):
            return "\(provider) cleanup failed: \(message)"
        case .localModelUnavailable(let model):
            return "Download and verify the local WhisperKit \(model) model first."
        case .speechRecognitionDenied:
            return "Speech Recognition access is denied."
        case .speechRecognitionRestricted:
            return "Speech Recognition is restricted on this Mac."
        case .speechRecognitionUnavailable(let locale):
            return "Apple Speech is unavailable for \(locale)."
        case .speechRecognitionFailed(let message):
            return "Apple Speech failed: \(message)"
        case .keychainFailed(let message):
            return "Keychain failed: \(message)"
        }
    }
}
