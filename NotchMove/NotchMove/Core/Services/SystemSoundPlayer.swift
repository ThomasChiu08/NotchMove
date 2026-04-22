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

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
    }

    func playReminderSound() {
        guard preferencesStore.preferences.soundEnabled else { return }
        NSSound(named: "Funk")?.play()
    }
}
