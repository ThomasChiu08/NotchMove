//
//  MainlandTranscriptionProviders.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import CryptoKit
import Foundation

struct DashScopeTranscriptionProvider: TranscriptionProvider {
    let apiKey: String
    let model: String
    let urlSession: URLSession

    var displayName: String { "DashScope" }

    init(apiKey: String, model: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.urlSession = urlSession
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        let fileData = try Data(contentsOf: recording.url)
        let dataURI = "data:\(recording.mimeType);base64,\(fileData.base64EncodedString())"

        var request = URLRequest(url: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DashScopeAudioRequest(
            model: model,
            messages: [
                DashScopeAudioMessage(
                    role: "user",
                    content: [
                        DashScopeAudioContent(inputAudio: DashScopeInputAudio(data: dataURI)),
                    ]
                ),
            ],
            stream: false,
            extraBody: DashScopeExtraBody(asrOptions: DashScopeASROptions(enableITN: true))
        ))

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            apiKey: apiKey
        )

        guard let text = try OpenAICompatibleChatResponseTextExtractor.outputText(from: data),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing transcription text."
            )
        }

        return Transcript(text: text, language: nil, duration: recording.duration)
    }
}

struct TencentCloudASRTranscriptionProvider: TranscriptionProvider {
    let secretID: String
    let secretKey: String
    let engineModelType: String
    let urlSession: URLSession

    var displayName: String { "Tencent Cloud ASR" }

    init(
        secretID: String,
        secretKey: String,
        engineModelType: String,
        urlSession: URLSession = .shared
    ) {
        self.secretID = secretID
        self.secretKey = secretKey
        self.engineModelType = engineModelType
        self.urlSession = urlSession
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        let fileData = try Data(contentsOf: recording.url)
        let payload = try JSONEncoder().encode(TencentSentenceRecognitionRequest(
            engSerViceType: engineModelType,
            sourceType: 1,
            voiceFormat: AudioFileDescriptor(recording: recording).providerFormat,
            data: fileData.base64EncodedString(),
            dataLen: fileData.count
        ))
        let timestamp = Int(Date().timeIntervalSince1970)

        var request = URLRequest(url: URL(string: "https://asr.tencentcloudapi.com")!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("SentenceRecognition", forHTTPHeaderField: "X-TC-Action")
        request.setValue("2019-06-14", forHTTPHeaderField: "X-TC-Version")
        request.setValue("ap-shanghai", forHTTPHeaderField: "X-TC-Region")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(
            tencentAuthorization(payload: payload, timestamp: timestamp),
            forHTTPHeaderField: "Authorization"
        )
        request.httpBody = payload

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            secrets: [secretID, secretKey]
        )

        let decoded = try JSONDecoder().decode(TencentSentenceRecognitionResponse.self, from: data)
        if let error = decoded.response.error {
            throw AIScheduleAssistantError.providerRequestFailed(
                provider: displayName,
                statusCode: 200,
                message: "\(error.code): \(error.message)"
            )
        }

        guard let result = decoded.response.result,
              !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing transcription result."
            )
        }

        return Transcript(text: result, language: nil, duration: recording.duration)
    }

    private func tencentAuthorization(payload: Data, timestamp: Int) -> String {
        let service = "asr"
        let host = "asr.tencentcloudapi.com"
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp)).yyyyMMddUTC
        let hashedPayload = SHA256Hash.hex(payload)
        let canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:\(host)\n"
        let signedHeaders = "content-type;host"
        let canonicalRequest = "POST\n/\n\n\(canonicalHeaders)\n\(signedHeaders)\n\(hashedPayload)"
        let credentialScope = "\(date)/\(service)/tc3_request"
        let stringToSign = """
        TC3-HMAC-SHA256
        \(timestamp)
        \(credentialScope)
        \(SHA256Hash.hex(Data(canonicalRequest.utf8)))
        """

        let secretDate = HMACSHA256.data(message: date, key: Data("TC3\(secretKey)".utf8))
        let secretService = HMACSHA256.data(message: service, key: secretDate)
        let secretSigning = HMACSHA256.data(message: "tc3_request", key: secretService)
        let signature = HMACSHA256.hex(message: stringToSign, key: secretSigning)

        return """
        TC3-HMAC-SHA256 Credential=\(secretID)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)
        """
    }
}

struct BaiduSpeechTranscriptionProvider: TranscriptionProvider {
    let apiKey: String
    let secretKey: String
    let devPID: String
    let urlSession: URLSession

    var displayName: String { "Baidu Speech" }

    init(apiKey: String, secretKey: String, devPID: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.devPID = devPID
        self.urlSession = urlSession
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        let token = try await accessToken()
        let fileData = try Data(contentsOf: recording.url)
        let body = BaiduSpeechRecognitionRequest(
            format: AudioFileDescriptor(recording: recording).providerFormat,
            rate: 16_000,
            devPID: Int(devPID) ?? 80001,
            channel: 1,
            cuid: "NotchMove-\(Host.current().localizedName ?? "mac")",
            token: token,
            len: fileData.count,
            speech: fileData.base64EncodedString()
        )

        var request = URLRequest(url: URL(string: "https://vop.baidu.com/pro_api")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            secrets: [apiKey, secretKey, token]
        )

        let decoded = try JSONDecoder().decode(BaiduSpeechRecognitionResponse.self, from: data)
        guard decoded.errNo == 0 else {
            throw AIScheduleAssistantError.providerRequestFailed(
                provider: displayName,
                statusCode: decoded.errNo,
                message: decoded.errMsg
            )
        }

        guard let text = decoded.result?.first,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing transcription result."
            )
        }

        return Transcript(text: text, language: nil, duration: recording.duration)
    }

    private func accessToken() async throws -> String {
        var components = URLComponents(string: "https://aip.baidubce.com/oauth/2.0/token")!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: apiKey),
            URLQueryItem(name: "client_secret", value: secretKey),
        ]

        let (data, response) = try await urlSession.data(from: components.url!)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            secrets: [apiKey, secretKey]
        )

        let decoded = try JSONDecoder().decode(BaiduAccessTokenResponse.self, from: data)
        guard let token = decoded.accessToken, !token.isEmpty else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: decoded.errorDescription ?? decoded.error ?? "Missing access token."
            )
        }

        return token
    }
}

struct IFlyTekTranscriptionProvider: TranscriptionProvider {
    let appID: String
    let apiKey: String
    let apiSecret: String
    let urlSession: URLSession

    var displayName: String { "iFlyTek" }

    init(appID: String, apiKey: String, apiSecret: String, urlSession: URLSession = .shared) {
        self.appID = appID
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.urlSession = urlSession
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        let audioData = try AudioFileDescriptor(recording: recording).pcmPayload()
        let url = signedWebSocketURL()
        let webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask.resume()

        do {
            try await sendAudio(audioData, to: webSocketTask)
            let text = try await receiveTranscript(from: webSocketTask)
            webSocketTask.cancel(with: .normalClosure, reason: nil)
            return Transcript(text: text, language: nil, duration: recording.duration)
        } catch {
            webSocketTask.cancel(with: .goingAway, reason: nil)
            throw error
        }
    }

    private func sendAudio(_ audioData: Data, to webSocketTask: URLSessionWebSocketTask) async throws {
        let chunkSize = 1_280
        var offset = 0
        var isFirstFrame = true
        var sentFinalFrame = false

        while offset < audioData.count {
            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData.subdata(in: offset..<end)
            let isLastFrame = end == audioData.count
            let status = isFirstFrame ? 0 : (isLastFrame ? 2 : 1)
            let frame = IFlyTekFrame(
                common: isFirstFrame ? IFlyTekCommon(appID: appID) : nil,
                business: isFirstFrame ? IFlyTekBusiness() : nil,
                data: IFlyTekData(
                    status: status,
                    format: "audio/L16;rate=16000",
                    encoding: "raw",
                    audio: chunk.base64EncodedString()
                )
            )
            try await webSocketTask.send(.data(try JSONEncoder().encode(frame)))
            offset = end
            isFirstFrame = false
            sentFinalFrame = status == 2
        }

        if !sentFinalFrame {
            let frame = IFlyTekFrame(
                common: audioData.isEmpty ? IFlyTekCommon(appID: appID) : nil,
                business: audioData.isEmpty ? IFlyTekBusiness() : nil,
                data: IFlyTekData(status: 2, format: "audio/L16;rate=16000", encoding: "raw", audio: "")
            )
            try await webSocketTask.send(.data(try JSONEncoder().encode(frame)))
        }
    }

    private func receiveTranscript(from webSocketTask: URLSessionWebSocketTask) async throws -> String {
        var transcript = ""

        while true {
            let message = try await webSocketTask.receive()
            let data: Data
            switch message {
            case .data(let messageData):
                data = messageData
            case .string(let text):
                data = Data(text.utf8)
            @unknown default:
                throw AIScheduleAssistantError.providerResponseInvalid(
                    provider: displayName,
                    message: "Unknown WebSocket message."
                )
            }

            let decoded = try JSONDecoder().decode(IFlyTekResponse.self, from: data)
            guard decoded.code == 0 else {
                throw AIScheduleAssistantError.providerRequestFailed(
                    provider: displayName,
                    statusCode: decoded.code,
                    message: decoded.message ?? "Recognition failed."
                )
            }

            if let words = decoded.data?.result?.ws {
                transcript += words.flatMap(\.cw).map(\.w).joined()
            }

            if decoded.data?.status == 2 {
                break
            }
        }

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing transcription result."
            )
        }

        return transcript
    }

    private func signedWebSocketURL() -> URL {
        let host = "iat-api.xfyun.cn"
        let path = "/v2/iat"
        let date = Date().rfc1123UTC
        let signatureOrigin = "host: \(host)\ndate: \(date)\nGET \(path) HTTP/1.1"
        let signature = HMACSHA256.base64(message: signatureOrigin, key: Data(apiSecret.utf8))
        let authorization = """
        api_key="\(apiKey)", algorithm="hmac-sha256", headers="host date request-line", signature="\(signature)"
        """

        var components = URLComponents(string: "wss://\(host)\(path)")!
        components.queryItems = [
            URLQueryItem(name: "authorization", value: Data(authorization.utf8).base64EncodedString()),
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "host", value: host),
        ]
        return components.url!
    }
}

struct VolcengineTranscriptionProvider: TranscriptionProvider {
    let apiKey: String
    let accessKey: String?
    let model: String
    let urlSession: URLSession

    var displayName: String { "Volcengine ASR" }

    init(apiKey: String, accessKey: String?, model: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.accessKey = accessKey
        self.model = model
        self.urlSession = urlSession
    }

    func transcribe(recording: AudioRecordingFile, context: TranscriptionContext) async throws -> Transcript {
        let fileData = try Data(contentsOf: recording.url)
        var request = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessKey, !accessKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-App-Key")
            request.setValue(accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        } else {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }

        request.setValue("volc.bigasr.auc_turbo", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")
        request.httpBody = try JSONEncoder().encode(VolcengineRecognitionRequest(
            user: VolcengineUser(uid: apiKey),
            audio: VolcengineAudio(data: fileData.base64EncodedString()),
            request: VolcengineRequest(modelName: model)
        ))

        let (data, response) = try await urlSession.data(for: request)
        try ProviderHTTP.validateResponse(
            data: data,
            response: response,
            provider: displayName,
            secrets: [apiKey, accessKey ?? ""]
        )

        if let httpResponse = response as? HTTPURLResponse,
           let statusCode = httpResponse.value(forHTTPHeaderField: "X-Api-Status-Code"),
           statusCode != "20000000" {
            throw AIScheduleAssistantError.providerRequestFailed(
                provider: displayName,
                statusCode: Int(statusCode) ?? 200,
                message: httpResponse.value(forHTTPHeaderField: "X-Api-Message") ?? "Recognition failed."
            )
        }

        let decoded = try JSONDecoder().decode(VolcengineRecognitionResponse.self, from: data)
        guard let text = decoded.result?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIScheduleAssistantError.providerResponseInvalid(
                provider: displayName,
                message: "Missing transcription result."
            )
        }

        return Transcript(text: text, language: nil, duration: recording.duration)
    }
}

private struct DashScopeAudioRequest: Encodable {
    var model: String
    var messages: [DashScopeAudioMessage]
    var stream: Bool
    var extraBody: DashScopeExtraBody

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case extraBody = "extra_body"
    }
}

private struct DashScopeAudioMessage: Encodable {
    var role: String
    var content: [DashScopeAudioContent]
}

private struct DashScopeAudioContent: Encodable {
    var type = "input_audio"
    var inputAudio: DashScopeInputAudio

    private enum CodingKeys: String, CodingKey {
        case type
        case inputAudio = "input_audio"
    }
}

private struct DashScopeInputAudio: Encodable {
    var data: String
}

private struct DashScopeExtraBody: Encodable {
    var asrOptions: DashScopeASROptions

    private enum CodingKeys: String, CodingKey {
        case asrOptions = "asr_options"
    }
}

private struct DashScopeASROptions: Encodable {
    var enableITN: Bool

    private enum CodingKeys: String, CodingKey {
        case enableITN = "enable_itn"
    }
}

private struct TencentSentenceRecognitionRequest: Encodable {
    var engSerViceType: String
    var sourceType: Int
    var voiceFormat: String
    var data: String
    var dataLen: Int

    private enum CodingKeys: String, CodingKey {
        case engSerViceType = "EngSerViceType"
        case sourceType = "SourceType"
        case voiceFormat = "VoiceFormat"
        case data = "Data"
        case dataLen = "DataLen"
    }
}

private struct TencentSentenceRecognitionResponse: Decodable {
    struct Body: Decodable {
        var result: String?
        var error: TencentError?

        private enum CodingKeys: String, CodingKey {
            case result = "Result"
            case error = "Error"
        }
    }

    var response: Body

    private enum CodingKeys: String, CodingKey {
        case response = "Response"
    }
}

private struct TencentError: Decodable {
    var code: String
    var message: String

    private enum CodingKeys: String, CodingKey {
        case code = "Code"
        case message = "Message"
    }
}

private struct BaiduAccessTokenResponse: Decodable {
    var accessToken: String?
    var error: String?
    var errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
        case errorDescription = "error_description"
    }
}

private struct BaiduSpeechRecognitionRequest: Encodable {
    var format: String
    var rate: Int
    var devPID: Int
    var channel: Int
    var cuid: String
    var token: String
    var len: Int
    var speech: String

    private enum CodingKeys: String, CodingKey {
        case format
        case rate
        case devPID = "dev_pid"
        case channel
        case cuid
        case token
        case len
        case speech
    }
}

private struct BaiduSpeechRecognitionResponse: Decodable {
    var errNo: Int
    var errMsg: String
    var result: [String]?

    private enum CodingKeys: String, CodingKey {
        case errNo = "err_no"
        case errMsg = "err_msg"
        case result
    }
}

private struct IFlyTekFrame: Encodable {
    var common: IFlyTekCommon?
    var business: IFlyTekBusiness?
    var data: IFlyTekData

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(common, forKey: .common)
        try container.encodeIfPresent(business, forKey: .business)
        try container.encode(data, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case common
        case business
        case data
    }
}

private struct IFlyTekCommon: Encodable {
    var appID: String

    private enum CodingKeys: String, CodingKey {
        case appID = "app_id"
    }
}

private struct IFlyTekBusiness: Encodable {
    var language = "zh_cn"
    var domain = "iat"
    var accent = "mandarin"
    var ptt = 1
}

private struct IFlyTekData: Encodable {
    var status: Int
    var format: String
    var encoding: String
    var audio: String
}

private struct IFlyTekResponse: Decodable {
    struct ResponseData: Decodable {
        var status: Int?
        var result: Result?
    }

    struct Result: Decodable {
        var ws: [WordSegment]
    }

    struct WordSegment: Decodable {
        var cw: [CandidateWord]
    }

    struct CandidateWord: Decodable {
        var w: String
    }

    var code: Int
    var message: String?
    var data: ResponseData?
}

private struct VolcengineRecognitionRequest: Encodable {
    var user: VolcengineUser
    var audio: VolcengineAudio
    var request: VolcengineRequest
}

private struct VolcengineUser: Encodable {
    var uid: String
}

private struct VolcengineAudio: Encodable {
    var data: String
}

private struct VolcengineRequest: Encodable {
    var modelName: String

    private enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
    }
}

private struct VolcengineRecognitionResponse: Decodable {
    struct Result: Decodable {
        var text: String?
    }

    var result: Result?
}

private struct AudioFileDescriptor {
    let recording: AudioRecordingFile

    var providerFormat: String {
        let ext = recording.url.pathExtension.lowercased()
        return ext.isEmpty ? "wav" : ext
    }

    func pcmPayload() throws -> Data {
        let data = try Data(contentsOf: recording.url)
        guard providerFormat == "wav" else {
            return data
        }

        let riffHeader = Data("RIFF".utf8)
        guard data.count > 44, data.prefix(4) == riffHeader else {
            return data
        }

        let marker = Data("data".utf8)
        guard let range = data.range(of: marker), range.upperBound + 4 <= data.count else {
            return Data(data.dropFirst(44))
        }

        let payloadStart = range.upperBound + 4
        guard payloadStart < data.count else { return Data() }
        return data.subdata(in: payloadStart..<data.count)
    }
}

private enum SHA256Hash {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private enum HMACSHA256 {
    static func data(message: String, key: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: SymmetricKey(data: key)
        ))
    }

    static func hex(message: String, key: Data) -> String {
        data(message: message, key: key).map { String(format: "%02x", $0) }.joined()
    }

    static func base64(message: String, key: Data) -> String {
        data(message: message, key: key).base64EncodedString()
    }
}

private extension Date {
    var yyyyMMddUTC: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    var rfc1123UTC: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: self)
    }
}
