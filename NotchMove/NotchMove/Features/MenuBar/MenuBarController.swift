//
//  MenuBarController.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import OSLog

/// Manages the persistent `NSStatusItem` in the menu bar.
///
/// Always visible regardless of notch presence. On non-notch Macs the
/// "Remind me now" action still calls `viewModel.triggerReminder()` — the
/// `NotchWindowController` already provides centred fallback positioning for
/// screens without a physical notch.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let viewModel: NotchViewModel
    private let scheduler: ReminderScheduler
    private let sessionCounter: SessionCounter
    private let onOpenSettings: () -> Void
    private let menu = NSMenu()
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "menu-bar")

    // Dynamic items refreshed in menuWillOpen(_:)
    private let statusMenuItem = NSMenuItem()
    private let breakCountMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let soundMenuItem = NSMenuItem(title: "Sound on reminder", action: nil, keyEquivalent: "")

    init(
        viewModel: NotchViewModel,
        scheduler: ReminderScheduler,
        sessionCounter: SessionCounter,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.scheduler = scheduler
        self.sessionCounter = sessionCounter
        self.onOpenSettings = onOpenSettings
        super.init()
        configureStatusButton()
        buildMenu()
    }

    // MARK: - Setup

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "NotchMove — sit-stand reminder")
        statusItem.menu = menu
        menu.delegate = self
    }

    private func buildMenu() {
        // Row 0: next-reminder status (disabled label)
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        // Row 1: break count (disabled label)
        breakCountMenuItem.isEnabled = false
        menu.addItem(breakCountMenuItem)

        menu.addItem(.separator())

        // Row 3: Pause / Resume
        pauseMenuItem.target = self
        pauseMenuItem.action = #selector(togglePause)
        menu.addItem(pauseMenuItem)

        // Row 4: Manual trigger
        let remindNow = NSMenuItem(title: "Remind me now", action: #selector(remindNow), keyEquivalent: "")
        remindNow.target = self
        menu.addItem(remindNow)

        menu.addItem(.separator())

        // Row 6: Sound toggle
        soundMenuItem.target = self
        soundMenuItem.action = #selector(toggleSound)
        menu.addItem(soundMenuItem)

        menu.addItem(.separator())

        // Settings
        let settings = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit NotchMove", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            self.refreshDynamicItems()
        }
    }

    // MARK: - Dynamic refresh

    private func refreshDynamicItems() {
        let remindersActive = scheduler.isEnabled && !scheduler.isPaused

        // Next-reminder label
        if remindersActive {
            let mins = scheduler.minutesRemaining
            statusMenuItem.title = mins <= 1 ? "Next reminder: < 1 min" : "Next reminder: \(mins) min"
        } else if !scheduler.isEnabled {
            statusMenuItem.title = "Reminders paused"
        } else {
            // isPaused == true: a reminder is currently showing
            statusMenuItem.title = "Stand-up reminder active"
        }

        // Break count label
        let today = sessionCounter.todayBreaks
        let week = sessionCounter.weekBreaks
        switch (today, week) {
        case (0, _):
            breakCountMenuItem.title = "No breaks yet today"
        case (1, _):
            breakCountMenuItem.title = "1 break today · \(week) this week"
        default:
            breakCountMenuItem.title = "\(today) breaks today · \(week) this week"
        }

        // Pause/Resume label
        pauseMenuItem.title = scheduler.isEnabled ? "Pause reminders" : "Resume reminders"

        // Sound toggle checkmark
        soundMenuItem.state = UserDefaults.standard.bool(forKey: "soundEnabled") ? .on : .off
    }

    // MARK: - Actions

    @objc private func togglePause() {
        scheduler.isEnabled.toggle()
        logger.notice("Reminders \(self.scheduler.isEnabled ? "enabled" : "disabled")")
    }

    @objc private func remindNow() {
        logger.notice("Manual reminder triggered from menu bar")
        viewModel.triggerReminder()
        if UserDefaults.standard.bool(forKey: "soundEnabled") {
            NSSound(named: "Funk")?.play()
        }
    }

    @objc private func openSettings() {
        logger.notice("Opening settings window")
        onOpenSettings()
    }

    @objc private func toggleSound() {
        let current = UserDefaults.standard.bool(forKey: "soundEnabled")
        UserDefaults.standard.set(!current, forKey: "soundEnabled")
        logger.notice("Sound \(!current ? "enabled" : "disabled")")
    }
}
