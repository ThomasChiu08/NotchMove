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
    private let breakReminderSound: NSSound?
    private let scheduleReminderSound: NSSound?
    private let pomodoroSound: NSSound?

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
        breakReminderSound = NSSound(named: "Funk")
        scheduleReminderSound = NSSound(named: "Funk")
        pomodoroSound = NSSound(named: "Glass") ?? NSSound(named: "Ping")
    }

    func playSound(_ cue: ReminderSoundCue) {
        guard preferencesStore.preferences.soundEnabled else { return }
        let sound = sound(for: cue)
        sound?.stop()
        sound?.play()
    }

    private func sound(for cue: ReminderSoundCue) -> NSSound? {
        switch cue {
        case .breakReminder:
            breakReminderSound
        case .scheduleReminder:
            scheduleReminderSound
        case .pomodoro:
            pomodoroSound
        }
    }
}
