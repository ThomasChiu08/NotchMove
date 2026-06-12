//
//  AudioCaptureService.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import AVFoundation
import Foundation

struct AudioRecordingFile: Equatable {
    var url: URL
    var startedAt: Date
    var duration: TimeInterval
    var mimeType: String

    func deleteTemporaryFile() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

@MainActor
final class AudioCaptureService: NSObject {
    private var recorder: AVAudioRecorder?
    private var activeURL: URL?
    private var startedAt: Date?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func startRecording() async throws {
        guard !isRecording else { return }
        guard await requestMicrophoneAccess() else {
            throw AIScheduleAssistantError.microphoneDenied
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchmove-ai-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw AIScheduleAssistantError.recordingFailed("Recorder did not start.")
            }

            self.recorder = recorder
            self.activeURL = url
            self.startedAt = .now
        } catch let error as AIScheduleAssistantError {
            throw error
        } catch {
            throw AIScheduleAssistantError.recordingFailed(error.localizedDescription)
        }
    }

    func stopRecording() throws -> AudioRecordingFile {
        guard let recorder, let activeURL, let startedAt else {
            throw AIScheduleAssistantError.recordingFailed("No active recording.")
        }

        recorder.stop()
        self.recorder = nil
        self.activeURL = nil
        self.startedAt = nil

        return AudioRecordingFile(
            url: activeURL,
            startedAt: startedAt,
            duration: Date().timeIntervalSince(startedAt),
            mimeType: "audio/wav"
        )
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil

        if let activeURL {
            try? FileManager.default.removeItem(at: activeURL)
        }

        activeURL = nil
        startedAt = nil
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
