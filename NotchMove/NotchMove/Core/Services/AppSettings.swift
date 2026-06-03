//
//  AppSettings.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/21/26.
//

import CoreGraphics
import Foundation

final class AppSettings {
    enum Keys {
        static let soundEnabled = "soundEnabled"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let hasSeenLaunchAtLoginPrompt = "hasSeenLaunchAtLoginPrompt"
        static let breakReminderEnabled = "breakReminderEnabled"
        static let pomodoroEnabled = "pomodoroEnabled"
        static let reminderIntervalMinutes = "reminderIntervalMinutes"
        static let pomodoroFocusMinutes = "pomodoroFocusMinutes"
        static let pomodoroBreakMinutes = "pomodoroBreakMinutes"
        static let sitAwareEnabled = "sitAwareEnabled"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleStartHour = "scheduleStartHour"
        static let scheduleStartMinute = "scheduleStartMinute"
        static let scheduleEndHour = "scheduleEndHour"
        static let scheduleEndMinute = "scheduleEndMinute"
        static let weekdaysOnly = "weekdaysOnly"
        static let notchExpansionEnabled = "notchExpansionEnabled"
        static let hoverPreviewEnabled = "hoverPreviewEnabled"
        static let autoDismissEnabled = "autoDismissEnabled"
        static let autoDismissSeconds = "autoDismissSeconds"
        static let appLanguage = "appLanguage"
        static let overlayDisplayMode = "overlayDisplayMode"
        static let overlayDisplayID = "overlayDisplayID"
        static let aiGlobalHotkeyEnabled = "aiGlobalHotkeyEnabled"
        static let aiGlobalHotkeyShortcutID = "aiGlobalHotkeyShortcutID"
    }

    private enum OverlayDisplayModeValue {
        static let automatic = "automatic"
        static let display = "display"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Keys.soundEnabled: Preferences.defaults.soundEnabled,
            Keys.launchAtLoginEnabled: Preferences.defaults.launchAtLoginEnabled,
            Keys.hasSeenLaunchAtLoginPrompt: Preferences.defaults.hasSeenLaunchAtLoginPrompt,
            Keys.breakReminderEnabled: Preferences.defaults.breakReminderEnabled,
            Keys.pomodoroEnabled: Preferences.defaults.pomodoroEnabled,
            Keys.reminderIntervalMinutes: Preferences.defaults.reminderIntervalMinutes,
            Keys.pomodoroFocusMinutes: Preferences.defaults.pomodoroFocusMinutes,
            Keys.pomodoroBreakMinutes: Preferences.defaults.pomodoroBreakMinutes,
            Keys.sitAwareEnabled: Preferences.defaults.sitAwareEnabled,
            Keys.scheduleEnabled: Preferences.defaults.schedule.isEnabled,
            Keys.scheduleStartHour: Preferences.defaults.schedule.startHour,
            Keys.scheduleStartMinute: Preferences.defaults.schedule.startMinute,
            Keys.scheduleEndHour: Preferences.defaults.schedule.endHour,
            Keys.scheduleEndMinute: Preferences.defaults.schedule.endMinute,
            Keys.weekdaysOnly: Preferences.defaults.schedule.weekdaysOnly,
            Keys.notchExpansionEnabled: Preferences.defaults.notchExpansionEnabled,
            Keys.hoverPreviewEnabled: Preferences.defaults.hoverPreviewEnabled,
            Keys.autoDismissEnabled: Preferences.defaults.autoDismissEnabled,
            Keys.autoDismissSeconds: Preferences.defaults.autoDismissSeconds,
            Keys.appLanguage: Preferences.defaults.appLanguage,
            Keys.overlayDisplayMode: OverlayDisplayModeValue.automatic,
            Keys.aiGlobalHotkeyEnabled: Preferences.defaults.aiGlobalHotkeyEnabled,
            Keys.aiGlobalHotkeyShortcutID: Preferences.defaults.aiGlobalHotkeyShortcutID,
        ])
    }

    func loadPreferences() -> Preferences {
        Preferences(
            soundEnabled: bool(forKey: Keys.soundEnabled, default: Preferences.defaults.soundEnabled),
            launchAtLoginEnabled: bool(
                forKey: Keys.launchAtLoginEnabled,
                default: Preferences.defaults.launchAtLoginEnabled
            ),
            hasSeenLaunchAtLoginPrompt: bool(
                forKey: Keys.hasSeenLaunchAtLoginPrompt,
                default: Preferences.defaults.hasSeenLaunchAtLoginPrompt
            ),
            breakReminderEnabled: bool(
                forKey: Keys.breakReminderEnabled,
                default: Preferences.defaults.breakReminderEnabled
            ),
            pomodoroEnabled: bool(
                forKey: Keys.pomodoroEnabled,
                default: Preferences.defaults.pomodoroEnabled
            ),
            reminderIntervalMinutes: integer(
                forKey: Keys.reminderIntervalMinutes,
                default: Preferences.defaults.reminderIntervalMinutes
            ),
            pomodoroFocusMinutes: integer(
                forKey: Keys.pomodoroFocusMinutes,
                default: Preferences.defaults.pomodoroFocusMinutes
            ),
            pomodoroBreakMinutes: integer(
                forKey: Keys.pomodoroBreakMinutes,
                default: Preferences.defaults.pomodoroBreakMinutes
            ),
            sitAwareEnabled: bool(forKey: Keys.sitAwareEnabled, default: Preferences.defaults.sitAwareEnabled),
            schedule: Preferences.Schedule(
                isEnabled: bool(forKey: Keys.scheduleEnabled, default: Preferences.defaults.schedule.isEnabled),
                startHour: integer(forKey: Keys.scheduleStartHour, default: Preferences.defaults.schedule.startHour),
                startMinute: integer(forKey: Keys.scheduleStartMinute, default: Preferences.defaults.schedule.startMinute),
                endHour: integer(forKey: Keys.scheduleEndHour, default: Preferences.defaults.schedule.endHour),
                endMinute: integer(forKey: Keys.scheduleEndMinute, default: Preferences.defaults.schedule.endMinute),
                weekdaysOnly: bool(forKey: Keys.weekdaysOnly, default: Preferences.defaults.schedule.weekdaysOnly)
            ),
            notchExpansionEnabled: bool(
                forKey: Keys.notchExpansionEnabled,
                default: Preferences.defaults.notchExpansionEnabled
            ),
            hoverPreviewEnabled: bool(
                forKey: Keys.hoverPreviewEnabled,
                default: Preferences.defaults.hoverPreviewEnabled
            ),
            autoDismissEnabled: bool(
                forKey: Keys.autoDismissEnabled,
                default: Preferences.defaults.autoDismissEnabled
            ),
            autoDismissSeconds: integer(
                forKey: Keys.autoDismissSeconds,
                default: Preferences.defaults.autoDismissSeconds
            ),
            appLanguage: defaults.string(forKey: Keys.appLanguage) ?? Preferences.defaults.appLanguage,
            overlayDisplayMode: loadOverlayDisplayMode(),
            aiGlobalHotkeyEnabled: bool(
                forKey: Keys.aiGlobalHotkeyEnabled,
                default: Preferences.defaults.aiGlobalHotkeyEnabled
            ),
            aiGlobalHotkeyShortcutID: loadGlobalHotkeyShortcutID()
        )
    }

    func save(_ preferences: Preferences) {
        defaults.set(preferences.soundEnabled, forKey: Keys.soundEnabled)
        defaults.set(preferences.launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        defaults.set(preferences.hasSeenLaunchAtLoginPrompt, forKey: Keys.hasSeenLaunchAtLoginPrompt)
        defaults.set(preferences.breakReminderEnabled, forKey: Keys.breakReminderEnabled)
        defaults.set(preferences.pomodoroEnabled, forKey: Keys.pomodoroEnabled)
        defaults.set(preferences.reminderIntervalMinutes, forKey: Keys.reminderIntervalMinutes)
        defaults.set(preferences.pomodoroFocusMinutes, forKey: Keys.pomodoroFocusMinutes)
        defaults.set(preferences.pomodoroBreakMinutes, forKey: Keys.pomodoroBreakMinutes)
        defaults.set(preferences.sitAwareEnabled, forKey: Keys.sitAwareEnabled)
        defaults.set(preferences.schedule.isEnabled, forKey: Keys.scheduleEnabled)
        defaults.set(preferences.schedule.startHour, forKey: Keys.scheduleStartHour)
        defaults.set(preferences.schedule.startMinute, forKey: Keys.scheduleStartMinute)
        defaults.set(preferences.schedule.endHour, forKey: Keys.scheduleEndHour)
        defaults.set(preferences.schedule.endMinute, forKey: Keys.scheduleEndMinute)
        defaults.set(preferences.schedule.weekdaysOnly, forKey: Keys.weekdaysOnly)
        defaults.set(preferences.notchExpansionEnabled, forKey: Keys.notchExpansionEnabled)
        defaults.set(preferences.hoverPreviewEnabled, forKey: Keys.hoverPreviewEnabled)
        defaults.set(preferences.autoDismissEnabled, forKey: Keys.autoDismissEnabled)
        defaults.set(preferences.autoDismissSeconds, forKey: Keys.autoDismissSeconds)
        defaults.set(preferences.appLanguage, forKey: Keys.appLanguage)
        save(preferences.overlayDisplayMode)
        defaults.set(preferences.aiGlobalHotkeyEnabled, forKey: Keys.aiGlobalHotkeyEnabled)
        defaults.set(normalizedGlobalHotkeyShortcutID(preferences.aiGlobalHotkeyShortcutID), forKey: Keys.aiGlobalHotkeyShortcutID)
    }

    private func loadOverlayDisplayMode() -> Preferences.OverlayDisplayMode {
        guard defaults.string(forKey: Keys.overlayDisplayMode) == OverlayDisplayModeValue.display,
              let rawDisplayID = defaults.object(forKey: Keys.overlayDisplayID) as? Int,
              rawDisplayID > 0
        else {
            return .automatic
        }

        return .display(CGDirectDisplayID(rawDisplayID))
    }

    private func save(_ mode: Preferences.OverlayDisplayMode) {
        switch mode {
        case .automatic:
            defaults.set(OverlayDisplayModeValue.automatic, forKey: Keys.overlayDisplayMode)
            defaults.removeObject(forKey: Keys.overlayDisplayID)
        case .display(let displayID):
            defaults.set(OverlayDisplayModeValue.display, forKey: Keys.overlayDisplayMode)
            defaults.set(Int(displayID), forKey: Keys.overlayDisplayID)
        }
    }

    private func loadGlobalHotkeyShortcutID() -> String {
        normalizedGlobalHotkeyShortcutID(
            defaults.string(forKey: Keys.aiGlobalHotkeyShortcutID) ?? Preferences.defaults.aiGlobalHotkeyShortcutID
        )
    }

    private func normalizedGlobalHotkeyShortcutID(_ shortcutID: String) -> String {
        GlobalHotkeyShortcut(rawValue: shortcutID)?.rawValue ?? Preferences.defaults.aiGlobalHotkeyShortcutID
    }

    private func integer(forKey key: String, default defaultValue: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? defaultValue
    }

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
