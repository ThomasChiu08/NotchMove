//
//  AppleSpeechTranscriptionProvider.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation
import Speech

enum AppleSpeechAuthorizationState: Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unknown
}

struct AppleSpeechTranscriptionProvider: TranscriptionProvider {
    static let automaticLocaleID = "auto"
    static let providerDisplayName = "Apple Speech"

    let preferredLocaleIdentifier: String

    var displayName: String { Self.providerDisplayName }

    init(preferredLocaleIdentifier: String = Self.automaticLocaleID) {
        self.preferredLocaleIdentifier = preferredLocaleIdentifier
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        try await Self.requestSpeechAuthorizationIfNeeded()

        let locale = Self.resolvedLocale(
            preferredLocaleIdentifier: preferredLocaleIdentifier,
            context: context
        )
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw AIScheduleAssistantError.speechRecognitionUnavailable(locale: locale.identifier)
        }
        guard recognizer.isAvailable else {
            throw AIScheduleAssistantError.speechRecognitionUnavailable(locale: locale.identifier)
        }

        let request = SFSpeechURLRecognitionRequest(url: recording.url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.addsPunctuation = true

        if Self.supportsOnDeviceRecognition(recognizer) {
            request.requiresOnDeviceRecognition = true
        }

        let text = try await recognize(request: request, recognizer: recognizer)
        return Transcript(
            text: text,
            language: locale.identifier,
            duration: recording.duration
        )
    }

    static func authorizationState() -> AppleSpeechAuthorizationState {
        authorizationState(from: SFSpeechRecognizer.authorizationStatus())
    }

    static func requestAuthorizationState() async -> AppleSpeechAuthorizationState {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return authorizationState(from: status)
    }

    static func configuredLocaleIdentifiers() -> [AIModelDefinition] {
        [
            AIModelDefinition(id: automaticLocaleID, displayName: "Automatic"),
            AIModelDefinition(id: "en-US", displayName: "English (US)"),
            AIModelDefinition(id: "zh-CN", displayName: "简体中文"),
            AIModelDefinition(id: "zh-TW", displayName: "繁體中文"),
            AIModelDefinition(id: "ja-JP", displayName: "日本語"),
        ]
    }

    static func resolvedLocale(
        preferredLocaleIdentifier: String,
        context: TranscriptionContext
    ) -> Locale {
        if preferredLocaleIdentifier != automaticLocaleID {
            return Locale(identifier: preferredLocaleIdentifier)
        }

        let identifier = context.languageMode == "auto" ? context.localeIdentifier : context.languageMode
        if identifier.hasPrefix("zh-Hant") || identifier.hasPrefix("zh-TW") {
            return Locale(identifier: "zh-TW")
        }

        if identifier.hasPrefix("zh") {
            return Locale(identifier: "zh-CN")
        }

        if identifier.hasPrefix("ja") {
            return Locale(identifier: "ja-JP")
        }

        if identifier.hasPrefix("en") {
            return Locale(identifier: "en-US")
        }

        return Locale(identifier: identifier)
    }

    private static func requestSpeechAuthorizationIfNeeded() async throws {
        switch authorizationState() {
        case .authorized:
            return
        case .notDetermined:
            try await authorizationStateAfterRequest().throwIfNotAuthorized()
        case .denied:
            throw AIScheduleAssistantError.speechRecognitionDenied
        case .restricted:
            throw AIScheduleAssistantError.speechRecognitionRestricted
        case .unknown:
            throw AIScheduleAssistantError.speechRecognitionUnavailable(locale: "system")
        }
    }

    private static func authorizationStateAfterRequest() async -> AppleSpeechAuthorizationState {
        await requestAuthorizationState()
    }

    private static func authorizationState(
        from status: SFSpeechRecognizerAuthorizationStatus
    ) -> AppleSpeechAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .authorized:
            .authorized
        @unknown default:
            .unknown
        }
    }

    private func recognize(
        request: SFSpeechURLRecognitionRequest,
        recognizer: SFSpeechRecognizer
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var bestText = ""
            var didResume = false

            func resume(_ result: Result<String, Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            _ = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    bestText = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if result.isFinal {
                        resume(.success(bestText))
                    }
                }

                if let error {
                    if !bestText.isEmpty {
                        resume(.success(bestText))
                    } else {
                        resume(.failure(AIScheduleAssistantError.speechRecognitionFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }

    private static func supportsOnDeviceRecognition(_ recognizer: SFSpeechRecognizer) -> Bool {
        let selector = NSSelectorFromString("supportsOnDeviceRecognition")
        guard recognizer.responds(to: selector) else { return false }
        return (recognizer.value(forKey: "supportsOnDeviceRecognition") as? Bool) == true
    }
}

private extension AppleSpeechAuthorizationState {
    func throwIfNotAuthorized() throws {
        switch self {
        case .authorized:
            return
        case .notDetermined, .denied:
            throw AIScheduleAssistantError.speechRecognitionDenied
        case .restricted:
            throw AIScheduleAssistantError.speechRecognitionRestricted
        case .unknown:
            throw AIScheduleAssistantError.speechRecognitionUnavailable(locale: "system")
        }
    }
}
