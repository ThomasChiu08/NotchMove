//
//  LocalSpeechModelStore.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Foundation
import Observation
import WhisperKit

enum LocalSpeechModelID: String, CaseIterable, Identifiable {
    case tiny
    case base
    case small

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny:
            "tiny"
        case .base:
            "base"
        case .small:
            "small"
        }
    }

    var approximateDiskUsage: String {
        switch self {
        case .tiny:
            "~80 MB"
        case .base:
            "~150 MB"
        case .small:
            "~470 MB"
        }
    }

    var whisperKitVariant: String {
        rawValue
    }
}

enum LocalSpeechModelState: Equatable {
    case notDownloaded
    case downloading(progress: Double?)
    case verifying
    case ready(URL)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .downloading, .verifying:
            true
        case .notDownloaded, .ready, .failed:
            false
        }
    }
}

@MainActor
@Observable
final class LocalSpeechModelStore {
    private enum Keys {
        static let modelPathPrefix = "aiAssistant.localSpeechModelPath."
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private var states: [LocalSpeechModelID: LocalSpeechModelState] = [:]

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager

        for model in LocalSpeechModelID.allCases {
            refreshState(for: model)
        }
    }

    func state(for model: LocalSpeechModelID) -> LocalSpeechModelState {
        states[model] ?? verifiedState(for: model)
    }

    func refreshState(for model: LocalSpeechModelID) {
        states[model] = verifiedState(for: model)
    }

    func readyModelFolderURL(for model: LocalSpeechModelID) throws -> URL {
        let state = verifiedState(for: model)
        states[model] = state

        if case .ready(let url) = state {
            return url
        }

        throw AIScheduleAssistantError.localModelUnavailable(model: model.displayName)
    }

    func verify(_ model: LocalSpeechModelID) {
        states[model] = .verifying
        states[model] = verifiedState(for: model)
    }

    func download(_ model: LocalSpeechModelID) async {
        states[model] = .downloading(progress: nil)

        do {
            let folderURL = try await WhisperKit.download(
                variant: model.whisperKitVariant
            )

            setModelFolderURL(folderURL, for: model)
            states[model] = .verifying
            states[model] = verifiedState(for: model)
        } catch {
            states[model] = .failed(error.localizedDescription)
        }
    }

    func delete(_ model: LocalSpeechModelID) throws {
        if let folderURL = storedModelFolderURL(for: model),
           fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
        }

        defaults.removeObject(forKey: modelPathKey(for: model))
        states[model] = .notDownloaded
    }

    private func verifiedState(for model: LocalSpeechModelID) -> LocalSpeechModelState {
        guard let folderURL = storedModelFolderURL(for: model),
              fileManager.fileExists(atPath: folderURL.path)
        else {
            return .notDownloaded
        }

        let requiredComponents = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
        let hasRequiredComponents = requiredComponents.allSatisfy {
            modelComponentExists(named: $0, in: folderURL)
        }

        if hasRequiredComponents {
            return .ready(folderURL)
        }

        return .failed("Downloaded model is missing required Core ML files.")
    }

    private func modelComponentExists(named name: String, in folderURL: URL) -> Bool {
        let compiledModelURL = folderURL.appendingPathComponent("\(name).mlmodelc")
        let packageModelURL = folderURL.appendingPathComponent("\(name).mlpackage")

        return fileManager.fileExists(atPath: compiledModelURL.path)
            || fileManager.fileExists(atPath: packageModelURL.path)
    }

    private func storedModelFolderURL(for model: LocalSpeechModelID) -> URL? {
        guard let path = defaults.string(forKey: modelPathKey(for: model)),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    private func setModelFolderURL(_ url: URL, for model: LocalSpeechModelID) {
        defaults.set(url.path, forKey: modelPathKey(for: model))
    }

    private func modelPathKey(for model: LocalSpeechModelID) -> String {
        "\(Keys.modelPathPrefix)\(model.rawValue)"
    }
}
