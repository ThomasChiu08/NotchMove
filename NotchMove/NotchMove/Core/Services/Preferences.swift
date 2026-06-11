//
//  Preferences.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import CoreGraphics
import Foundation

struct Preferences: Equatable {
    enum VoiceCleanupMode: String, CaseIterable, Identifiable {
        case raw
        case clean
        case polished

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .raw: "voice.settings.cleanup_raw"
            case .clean: "voice.settings.cleanup_clean"
            case .polished: "voice.settings.cleanup_polished"
            }
        }
    }

    enum OverlayDisplayMode: Equatable, Hashable {
        case automatic
        case display(CGDirectDisplayID)
    }

    struct Schedule: Equatable {
        var isEnabled: Bool
        var startHour: Int
        var startMinute: Int
        var endHour: Int
        var endMinute: Int
        var weekdaysOnly: Bool

        var hasValidTimeRange: Bool {
            (startHour * 60 + startMinute) < (endHour * 60 + endMinute)
        }
    }

    var soundEnabled: Bool
    var launchAtLoginEnabled: Bool
    var hasSeenLaunchAtLoginPrompt: Bool
    var breakReminderEnabled: Bool
    var pomodoroEnabled: Bool
    var reminderIntervalMinutes: Int
    var pomodoroFocusMinutes: Int
    var pomodoroBreakMinutes: Int
    var sitAwareEnabled: Bool
    var schedule: Schedule
    var notchExpansionEnabled: Bool
    var hoverPreviewEnabled: Bool
    var autoDismissEnabled: Bool
    var autoDismissSeconds: Int
    var appLanguage: String
    var overlayDisplayMode: OverlayDisplayMode
    var voiceInputEnabled: Bool
    var voiceInputShortcutID: String
    var voiceCleanupMode: VoiceCleanupMode
    var voicePersonalTerms: [String]
    var aiGlobalHotkeyEnabled: Bool
    var aiGlobalHotkeyShortcutID: String

    static let defaults = Preferences(
        soundEnabled: true,
        launchAtLoginEnabled: false,
        hasSeenLaunchAtLoginPrompt: false,
        breakReminderEnabled: true,
        pomodoroEnabled: true,
        reminderIntervalMinutes: 30,
        pomodoroFocusMinutes: 25,
        pomodoroBreakMinutes: 5,
        sitAwareEnabled: true,
        schedule: Schedule(
            isEnabled: false,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: true
        ),
        notchExpansionEnabled: true,
        hoverPreviewEnabled: true,
        autoDismissEnabled: true,
        autoDismissSeconds: 60,
        appLanguage: "en",
        overlayDisplayMode: .automatic,
        voiceInputEnabled: false,
        voiceInputShortcutID: GlobalHotkeyShortcut.default.rawValue,
        voiceCleanupMode: .clean,
        voicePersonalTerms: [],
        aiGlobalHotkeyEnabled: false,
        aiGlobalHotkeyShortcutID: GlobalHotkeyShortcut.default.rawValue
    )
}
