//
//  VoiceTextCleanupServiceTests.swift
//  NotchMoveTests
//
//  Created by Codex on 5/14/26.
//

import Foundation
import Testing
@testable import NotchMove

@MainActor
struct VoiceTextCleanupServiceTests {
    @Test func rawCleanupModePreservesTranscriptText() async {
        let service = VoiceTextCleanupService(
            preferences: AIProviderPreferences(defaults: UserDefaults(suiteName: "VoiceRaw-\(UUID().uuidString)")!)
        )

        let cleaned = await service.clean(
            text: " um please please send this ",
            context: VoiceTextCleanupContext(localeIdentifier: "en", appName: "Notes", personalTerms: []),
            mode: Preferences.VoiceCleanupMode.raw
        )

        #expect(cleaned == "um please please send this")
    }

    @Test func localCleanerRemovesCommonEnglishFillersAndRepeatedWords() {
        let cleaned = VoiceLocalTextCleaner.clean("um please please send this to Thomas")

        #expect(cleaned == "please send this to Thomas")
    }

    @Test func cleanCleanupModeUsesLocalCleaner() async {
        let service = VoiceTextCleanupService(
            preferences: AIProviderPreferences(defaults: UserDefaults(suiteName: "VoiceClean-\(UUID().uuidString)")!)
        )

        let cleaned = await service.clean(
            text: "um please please send this to Thomas",
            context: VoiceTextCleanupContext(localeIdentifier: "en", appName: "Notes", personalTerms: ["Thomas"]),
            mode: Preferences.VoiceCleanupMode.clean
        )

        #expect(cleaned == "please send this to Thomas")
    }


    @Test func localCleanerRemovesCommonChineseFillersAndKeepsMeaning() {
        let cleaned = VoiceLocalTextCleaner.clean("嗯，今天下午三点提醒我开会")

        #expect(cleaned == "今天下午三点提醒我开会")
    }
}
