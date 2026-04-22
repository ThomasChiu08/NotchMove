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
    private let settings: AppSettings

    var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            settings.save(preferences)
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
}
