//
//  APIKeyStore.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Security

protocol APIKeyStoring {
    func apiKey(for provider: AIProviderID) throws -> String?
    func saveAPIKey(_ apiKey: String, for provider: AIProviderID) throws
    func deleteAPIKey(for provider: AIProviderID) throws
}

struct KeychainAPIKeyStore: APIKeyStoring {
    private let service = "com.thomaschiu.developer.NotchMove.ai-api-key"

    func apiKey(for provider: AIProviderID) throws -> String? {
        var query = baseQuery(for: provider)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw AIScheduleAssistantError.keychainFailed(statusMessage(status))
        }

        guard let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8)
        else {
            throw AIScheduleAssistantError.keychainFailed("Stored key is not valid UTF-8.")
        }

        return apiKey
    }

    func saveAPIKey(_ apiKey: String, for provider: AIProviderID) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery(for: provider)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw AIScheduleAssistantError.keychainFailed(statusMessage(updateStatus))
        }

        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AIScheduleAssistantError.keychainFailed(statusMessage(addStatus))
        }
    }

    func deleteAPIKey(for provider: AIProviderID) throws {
        let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIScheduleAssistantError.keychainFailed(statusMessage(status))
        }
    }

    private func baseQuery(for provider: AIProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }

    private func statusMessage(_ status: OSStatus) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    }
}
