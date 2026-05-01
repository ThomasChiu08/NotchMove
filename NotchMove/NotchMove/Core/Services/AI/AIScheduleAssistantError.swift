//
//  AIScheduleAssistantError.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

enum AIScheduleAssistantError: Error, Equatable, LocalizedError {
    case disabled
    case missingAPIKey(provider: String)
    case missingCredential(provider: String, field: String)
    case microphoneDenied
    case recordingFailed(String)
    case emptyTranscript
    case networkUnavailable
    case providerAuthenticationFailed(provider: String)
    case providerRequestFailed(provider: String, statusCode: Int, message: String)
    case providerResponseInvalid(provider: String, message: String)
    case invalidParserJSON(provider: String, message: String)
    case keychainFailed(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI Assistant is disabled."
        case .missingAPIKey(let provider):
            return "\(provider) API key is missing."
        case .missingCredential(let provider, let field):
            return "\(provider) \(field) is missing."
        case .microphoneDenied:
            return "Microphone access is denied."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .emptyTranscript:
            return "The transcript was empty."
        case .networkUnavailable:
            return "Network unavailable."
        case .providerAuthenticationFailed(let provider):
            return "\(provider) rejected the API key."
        case .providerRequestFailed(let provider, let statusCode, let message):
            return "\(provider) request failed (\(statusCode)): \(message)"
        case .providerResponseInvalid(let provider, let message):
            return "\(provider) returned an invalid response: \(message)"
        case .invalidParserJSON(let provider, let message):
            return "\(provider) returned invalid schedule JSON: \(message)"
        case .keychainFailed(let message):
            return "Keychain failed: \(message)"
        }
    }

    static func redactedProviderMessage(_ message: String, apiKey: String?) -> String {
        guard let apiKey, !apiKey.isEmpty else { return message }
        return message.replacingOccurrences(of: apiKey, with: "[redacted]")
    }

    static func redactedProviderMessage(_ message: String, secrets: [String]) -> String {
        secrets.reduce(message) { redacted, secret in
            let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSecret.isEmpty else { return redacted }
            return redacted.replacingOccurrences(of: trimmedSecret, with: "[redacted]")
        }
    }
}
