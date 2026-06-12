//
//  OpenAITranscriptionProvider.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct OpenAITranscriptionProvider: TranscriptionProvider {
    let apiKey: String
    let model: String
    let urlSession: URLSession

    var displayName: String { "OpenAI" }

    init(
        apiKey: String,
        model: String = AIProviderPreferences.defaultTranscriptionModel,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.urlSession = urlSession
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(
            recording: recording,
            context: context,
            boundary: boundary
        )

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            apiKey: apiKey
        )

        do {
            let responseBody = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
            return Transcript(
                text: responseBody.text,
                language: responseBody.language,
                duration: responseBody.duration ?? recording.duration
            )
        } catch {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: error.localizedDescription
            )
        }
    }

    private func multipartBody(
        recording: AudioRecordingFile,
        context: TranscriptionContext,
        boundary: String
    ) throws -> Data {
        var data = Data()
        data.appendMultipartField(name: "model", value: model, boundary: boundary)
        data.appendMultipartField(name: "response_format", value: "json", boundary: boundary)

        if context.languageMode != "auto" {
            data.appendMultipartField(name: "language", value: context.languageMode, boundary: boundary)
        }

        let fileData = try Data(contentsOf: recording.url)
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n")
        data.append("Content-Type: \(recording.mimeType)\r\n\r\n")
        data.append(fileData)
        data.append("\r\n")
        data.append("--\(boundary)--\r\n")
        return data
    }
}

private struct OpenAITranscriptionResponse: Decodable {
    var text: String
    var language: String?
    var duration: TimeInterval?
}

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
