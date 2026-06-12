//
//  SystemPrivacySettings.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import AppKit

enum SystemPrivacySettings {
    static func openMicrophone() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    static func openSpeechRecognition() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
    }

    static func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openPrivacyAndSecurity() {
        open("x-apple.systempreferences:com.apple.preference.security")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
