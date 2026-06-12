//
//  TranscriptionProvider.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct TranscriptionContext: Equatable {
    var localeIdentifier: String
    var languageMode: String
}

protocol TranscriptionProvider {
    var displayName: String { get }
    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript
}
