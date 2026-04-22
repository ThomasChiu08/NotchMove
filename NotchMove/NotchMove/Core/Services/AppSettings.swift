//
//  AppSettings.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/21/26.
//

import Foundation

final class AppSettings {
    enum Keys {
        static let soundEnabled = "soundEnabled"
        static let reminderIntervalMinutes = "reminderIntervalMinutes"
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
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Keys.soundEnabled: Preferences.defaults.soundEnabled,
            Keys.reminderIntervalMinutes: Preferences.defaults.reminderIntervalMinutes,
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
        ])
    }

    func loadPreferences() -> Preferences {
        Preferences(
            soundEnabled: bool(forKey: Keys.soundEnabled, default: Preferences.defaults.soundEnabled),
            reminderIntervalMinutes: integer(
                forKey: Keys.reminderIntervalMinutes,
                default: Preferences.defaults.reminderIntervalMinutes
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
            appLanguage: defaults.string(forKey: Keys.appLanguage) ?? Preferences.defaults.appLanguage
        )
    }

    func save(_ preferences: Preferences) {
        defaults.set(preferences.soundEnabled, forKey: Keys.soundEnabled)
        defaults.set(preferences.reminderIntervalMinutes, forKey: Keys.reminderIntervalMinutes)
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
    }

    private func integer(forKey key: String, default defaultValue: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? defaultValue
    }

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
