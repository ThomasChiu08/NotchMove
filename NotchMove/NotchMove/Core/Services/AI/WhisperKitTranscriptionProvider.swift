//
//  WhisperKitTranscriptionProvider.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation
import WhisperKit

struct WhisperKitTranscriptionProvider: TranscriptionProvider {
    let model: LocalSpeechModelID
    let modelFolderURL: URL

    var displayName: String { "Local WhisperKit" }

    init(model: LocalSpeechModelID, modelFolderURL: URL) {
        self.model = model
        self.modelFolderURL = modelFolderURL
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        let configuration = WhisperKitConfig(
            model: model.whisperKitVariant,
            modelFolder: modelFolderURL.path,
            verbose: false,
            prewarm: false,
            load: true,
            download: false
        )
        let pipe = try await WhisperKit(configuration)
        let language = whisperLanguageCode(for: context)
        let decodingOptions = DecodingOptions(
            verbose: false,
            language: language,
            withoutTimestamps: true,
            concurrentWorkerCount: 1
        )
        let results = try await pipe.transcribe(
            audioPath: recording.url.path,
            decodeOptions: decodingOptions
        )
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedLanguage = results.first { !$0.language.isEmpty }?.language

        return Transcript(
            text: text,
            language: detectedLanguage ?? language,
            duration: recording.duration
        )
    }

    private func whisperLanguageCode(for context: TranscriptionContext) -> String? {
        if context.languageMode != "auto" {
            return context.languageMode
        }

        if context.localeIdentifier.hasPrefix("zh") {
            return "zh"
        }

        if context.localeIdentifier.hasPrefix("ja") {
            return "ja"
        }

        if context.localeIdentifier.hasPrefix("en") {
            return "en"
        }

        return nil
    }
}
