//
//  SystemSoundPlayer.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import AppKit

@MainActor
struct SystemSoundPlayer: SoundPlaying {
    private let preferencesStore: PreferencesStore
    private let reminderSound: NSSound?

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
        reminderSound = NSSound(named: "Funk")
    }

    func playReminderSound() {
        guard preferencesStore.preferences.soundEnabled else { return }
        reminderSound?.stop()
        reminderSound?.play()
    }
}
