//
//  OpenAIHTTP.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

enum OpenAIHTTP {
    static func validateResponse(
        data: Data,
        response: URLResponse,
        provider: String,
        apiKey: String
    ) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIScheduleAssistantError.networkUnavailable
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            let redactedMessage = AIScheduleAssistantError.redactedProviderMessage(
                message,
                apiKey: apiKey
            )

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw AIScheduleAssistantError.providerAuthenticationFailed(provider: provider)
            }

            throw AIScheduleAssistantError.providerRequestFailed(
                provider: provider,
                statusCode: httpResponse.statusCode,
                message: redactedMessage
            )
        }
    }

    static func decodeErrorMessage(from data: Data) -> String {
        guard let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8) ?? "Unknown provider error."
        }

        return errorResponse.error.message
    }
}

private struct OpenAIErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        var message: String
    }

    var error: ErrorBody
}
