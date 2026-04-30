//
//  PreferencesStore.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import Foundation

@MainActor
@Observable
final class PreferencesStore {
    static let notchLayoutDidChangeNotification = Notification.Name("PreferencesStoreNotchLayoutDidChange")
    static let reminderRuntimeDidChangeNotification = Notification.Name("PreferencesStoreReminderRuntimeDidChange")

    private let settings: AppSettings

    var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            settings.save(preferences)
            postRelevantNotifications(from: oldValue, to: preferences)
        }
    }

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        settings.registerDefaults()
        self.preferences = settings.loadPreferences()
    }

    func restoreDefaults() {
        preferences = .defaults
    }

    private func postRelevantNotifications(from oldValue: Preferences, to newValue: Preferences) {
        if oldValue.notchExpansionEnabled != newValue.notchExpansionEnabled ||
            oldValue.overlayDisplayMode != newValue.overlayDisplayMode {
            NotificationCenter.default.post(name: Self.notchLayoutDidChangeNotification, object: self)
        }

        if oldValue.schedule != newValue.schedule ||
            oldValue.hoverPreviewEnabled != newValue.hoverPreviewEnabled ||
            oldValue.autoDismissEnabled != newValue.autoDismissEnabled ||
            oldValue.autoDismissSeconds != newValue.autoDismissSeconds {
            NotificationCenter.default.post(name: Self.reminderRuntimeDidChangeNotification, object: self)
        }
    }
}
