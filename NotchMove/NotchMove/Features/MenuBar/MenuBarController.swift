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
/// "Remind me now" action still triggers the overlay — the
/// `NotchWindowController` already provides centred fallback positioning for
/// screens without a physical notch.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reminderEngine: ReminderEngine
    private let breakStatsStore: BreakStatsStore
    private let languageManager: LanguageManager
    private let preferencesStore: PreferencesStore
    private let onOpenDashboard: () -> Void
    private let onOpenSettings: () -> Void
    private let menu = NSMenu()
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "menu-bar")

    // Dynamic items refreshed in menuWillOpen(_:)
    private let statusMenuItem = NSMenuItem()
    private let breakCountMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let soundMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let remindNowMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let dashboardMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let settingsMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: ",")
    private let quitMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "q")

    init(
        reminderEngine: ReminderEngine,
        breakStatsStore: BreakStatsStore,
        languageManager: LanguageManager,
        preferencesStore: PreferencesStore,
        onOpenDashboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.reminderEngine = reminderEngine
        self.breakStatsStore = breakStatsStore
        self.languageManager = languageManager
        self.preferencesStore = preferencesStore
        self.onOpenDashboard = onOpenDashboard
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
        remindNowMenuItem.target = self
        remindNowMenuItem.action = #selector(remindNow)
        menu.addItem(remindNowMenuItem)

        menu.addItem(.separator())

        // Row 6: Sound toggle
        soundMenuItem.target = self
        soundMenuItem.action = #selector(toggleSound)
        menu.addItem(soundMenuItem)

        menu.addItem(.separator())

        // Dashboard
        dashboardMenuItem.target = self
        dashboardMenuItem.action = #selector(openDashboard)
        menu.addItem(dashboardMenuItem)

        // Settings
        settingsMenuItem.target = self
        settingsMenuItem.action = #selector(openSettings)
        menu.addItem(settingsMenuItem)

        menu.addItem(.separator())

        // Quit
        quitMenuItem.action = #selector(NSApplication.terminate(_:))
        menu.addItem(quitMenuItem)
    }

    /// Convenience to fetch a localized string through the LanguageManager.
    private func L(_ key: String) -> String {
        languageManager.localizedString(key)
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            self.refreshDynamicItems()
        }
    }

    // MARK: - Dynamic refresh

    private func refreshDynamicItems() {
        breakStatsStore.refresh()

        let remindersActive = !reminderEngine.state.scheduleState.blocksAutomaticReminders &&
            !reminderEngine.state.manualPause &&
            !reminderEngine.isReminderPresenting

        // Next-reminder label
        if remindersActive {
            let mins = reminderEngine.minutesRemaining
            if mins <= 1 {
                statusMenuItem.title = L("menu.next_reminder_soon")
            } else {
                statusMenuItem.title = String(format: L("menu.next_reminder"), "\(mins)")
            }
        } else if reminderEngine.isReminderPresenting {
            statusMenuItem.title = L("menu.reminder_active")
        } else {
            statusMenuItem.title = L("menu.reminders_paused")
        }

        // Break count label
        let today = breakStatsStore.todayBreaks
        let week = breakStatsStore.weekBreaks
        switch (today, week) {
        case (0, _):
            breakCountMenuItem.title = L("menu.no_breaks")
        case (1, _):
            breakCountMenuItem.title = String(format: L("menu.one_break_format"), week)
        default:
            breakCountMenuItem.title = String(format: L("menu.breaks_format"), today, week)
        }

        // Pause/Resume label
        pauseMenuItem.title = reminderEngine.state.manualPause ? L("menu.resume") : L("menu.pause")

        // Remind now
        remindNowMenuItem.title = L("menu.remind_now")

        // Sound toggle
        soundMenuItem.title = L("menu.sound")
        soundMenuItem.state = preferencesStore.preferences.soundEnabled ? .on : .off

        // Settings & Quit
        dashboardMenuItem.title = L("menu.dashboard")
        settingsMenuItem.title = L("menu.settings")
        quitMenuItem.title = L("menu.quit")
    }

    // MARK: - Actions

    @objc private func togglePause() {
        let shouldPause = !reminderEngine.state.manualPause
        reminderEngine.send(.setManualPause(shouldPause))
        logger.notice("Manual pause \(shouldPause ? "enabled" : "disabled")")
    }

    @objc private func remindNow() {
        logger.notice("Manual reminder triggered from menu bar")
        reminderEngine.send(.manualTrigger)
    }

    @objc private func openSettings() {
        logger.notice("Opening settings window")
        onOpenSettings()
    }

    @objc private func openDashboard() {
        logger.notice("Opening daily schedule dashboard")
        onOpenDashboard()
    }

    @objc private func toggleSound() {
        let nextValue = !preferencesStore.preferences.soundEnabled
        preferencesStore.preferences.soundEnabled = nextValue
        logger.notice("Sound \(nextValue ? "enabled" : "disabled")")
    }
}
