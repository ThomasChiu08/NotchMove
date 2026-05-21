//
//  VoiceTextCleanupServiceTests.swift
//  NotchMoveTests
//
//  Created by Codex on 5/14/26.
//

import Testing
@testable import NotchMove

@MainActor
struct VoiceTextCleanupServiceTests {
    @Test func localCleanerRemovesCommonEnglishFillersAndRepeatedWords() {
        let cleaned = VoiceLocalTextCleaner.clean("um please please send this to Thomas")

        #expect(cleaned == "please send this to Thomas")
    }

    @Test func localCleanerRemovesCommonChineseFillersAndKeepsMeaning() {
        let cleaned = VoiceLocalTextCleaner.clean("嗯，今天下午三点提醒我开会")

        #expect(cleaned == "今天下午三点提醒我开会")
    }
}
