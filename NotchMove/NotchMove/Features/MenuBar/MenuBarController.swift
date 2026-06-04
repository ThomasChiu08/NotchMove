//
//  MenuBarController.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import OSLog

enum StatusItemAppearance {
    static let length = NSStatusItem.squareLength
    static let fallbackTitle = "NM"
    static let accessibilityDescription = "NotchMove — sit-stand reminder"

    static func makeStatusBarImage() -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: "figure.walk",
            accessibilityDescription: accessibilityDescription
        ) else {
            return nil
        }

        image.isTemplate = true
        return image
    }

    @MainActor
    static func configure(_ statusItem: NSStatusItem) {
        statusItem.length = length

        guard let button = statusItem.button else { return }
        button.toolTip = accessibilityDescription
        button.setAccessibilityLabel(accessibilityDescription)

        if let image = makeStatusBarImage() {
            button.image = image
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.title = ""
            return
        }

        if let appIcon = NSApp.applicationIconImage.copy() as? NSImage,
           appIcon.size.width > 0,
           appIcon.size.height > 0 {
            button.image = appIcon
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.title = ""
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.title = fallbackTitle
    }
}

/// Manages the persistent `NSStatusItem` in the menu bar.
///
/// Always visible regardless of notch presence. On non-notch Macs the
/// "Remind me now" action still triggers the overlay — the
/// `NotchWindowController` already provides centred fallback positioning for
/// screens without a physical notch.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: StatusItemAppearance.length)
    private let reminderEngine: ReminderEngine
    private let pomodoroEngine: PomodoroEngine
    private let breakStatsStore: BreakStatsStore
    private let languageManager: LanguageManager
    private let preferencesStore: PreferencesStore
    private let onOpenDashboard: () -> Void
    private let menu = NSMenu()
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "menu-bar")

    // Dynamic items refreshed in menuWillOpen(_:)
    private let statusMenuItem = NSMenuItem()
    private let breakCountMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let soundMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let remindNowMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pomodoroStartMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pomodoroPauseMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pomodoroStopMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let dashboardMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: ",")
    private let quitMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "q")

    init(
        reminderEngine: ReminderEngine,
        pomodoroEngine: PomodoroEngine,
        breakStatsStore: BreakStatsStore,
        languageManager: LanguageManager,
        preferencesStore: PreferencesStore,
        onOpenDashboard: @escaping () -> Void
    ) {
        self.reminderEngine = reminderEngine
        self.pomodoroEngine = pomodoroEngine
        self.breakStatsStore = breakStatsStore
        self.languageManager = languageManager
        self.preferencesStore = preferencesStore
        self.onOpenDashboard = onOpenDashboard
        super.init()
        configureStatusButton()
        buildMenu()
    }

    // MARK: - Setup

    private func configureStatusButton() {
        StatusItemAppearance.configure(statusItem)
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

        // Pause / Resume
        pauseMenuItem.target = self
        pauseMenuItem.action = #selector(togglePause)
        menu.addItem(pauseMenuItem)

        // Manual trigger
        remindNowMenuItem.target = self
        remindNowMenuItem.action = #selector(remindNow)
        menu.addItem(remindNowMenuItem)

        menu.addItem(.separator())

        // Pomodoro controls
        pomodoroStartMenuItem.target = self
        pomodoroStartMenuItem.action = #selector(startPomodoro)
        menu.addItem(pomodoroStartMenuItem)

        pomodoroPauseMenuItem.target = self
        pomodoroPauseMenuItem.action = #selector(togglePomodoroPause)
        menu.addItem(pomodoroPauseMenuItem)

        pomodoroStopMenuItem.target = self
        pomodoroStopMenuItem.action = #selector(stopPomodoro)
        menu.addItem(pomodoroStopMenuItem)

        menu.addItem(.separator())

        // Sound toggle
        soundMenuItem.target = self
        soundMenuItem.action = #selector(toggleSound)
        menu.addItem(soundMenuItem)

        menu.addItem(.separator())

        // Dashboard
        dashboardMenuItem.target = self
        dashboardMenuItem.action = #selector(openDashboard)
        menu.addItem(dashboardMenuItem)

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

        let breakReminderEnabled = preferencesStore.preferences.breakReminderEnabled
        let remindersActive = breakReminderEnabled &&
            !reminderEngine.state.scheduleState.blocksAutomaticReminders &&
            !reminderEngine.state.manualPause &&
            !reminderEngine.isReminderPresenting

        // Next-reminder label
        if pomodoroEngine.isActive {
            statusMenuItem.title = pomodoroStatusTitle
        } else if !breakReminderEnabled {
            statusMenuItem.title = L("menu.reminders_disabled")
        } else if remindersActive {
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
        pauseMenuItem.isEnabled = breakReminderEnabled

        // Remind now
        remindNowMenuItem.title = L("menu.remind_now")
        remindNowMenuItem.isEnabled = breakReminderEnabled && !reminderEngine.isReminderPresenting

        refreshPomodoroItems()

        // Sound toggle
        soundMenuItem.title = L("menu.sound")
        soundMenuItem.state = preferencesStore.preferences.soundEnabled ? .on : .off

        // Settings & Quit
        dashboardMenuItem.title = L("menu.dashboard")
        quitMenuItem.title = L("menu.quit")
    }

    private func refreshPomodoroItems() {
        pomodoroStartMenuItem.title = L("menu.pomodoro_start")
        pomodoroStartMenuItem.isHidden = pomodoroEngine.isActive
        pomodoroStartMenuItem.isEnabled = preferencesStore.preferences.pomodoroEnabled && !reminderEngine.isReminderPresenting

        pomodoroPauseMenuItem.title = pomodoroEngine.isPaused ? L("menu.pomodoro_resume") : L("menu.pomodoro_pause")
        pomodoroPauseMenuItem.isHidden = !pomodoroEngine.isActive
        pomodoroPauseMenuItem.isEnabled = pomodoroEngine.isActive

        pomodoroStopMenuItem.title = L("menu.pomodoro_stop")
        pomodoroStopMenuItem.isHidden = !pomodoroEngine.isActive
        pomodoroStopMenuItem.isEnabled = pomodoroEngine.isActive
    }

    private var pomodoroStatusTitle: String {
        let remaining = formattedRemainingSeconds(pomodoroEngine.state.remainingSeconds)

        if pomodoroEngine.isPaused {
            return String(format: L("menu.pomodoro_paused_format"), remaining)
        }

        switch pomodoroEngine.state.phase {
        case .focus:
            return String(format: L("menu.pomodoro_focus_format"), remaining)
        case .rest:
            return String(format: L("menu.pomodoro_break_format"), remaining)
        }
    }

    private func formattedRemainingSeconds(_ seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
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

    @objc private func startPomodoro() {
        logger.notice("Pomodoro started from menu bar")
        pomodoroEngine.startFocusSession()
    }

    @objc private func togglePomodoroPause() {
        if pomodoroEngine.isPaused {
            logger.notice("Pomodoro resumed from menu bar")
            pomodoroEngine.resume()
        } else {
            logger.notice("Pomodoro paused from menu bar")
            pomodoroEngine.pause()
        }
    }

    @objc private func stopPomodoro() {
        logger.notice("Pomodoro stopped from menu bar")
        pomodoroEngine.stop()
    }

    @objc private func openDashboard() {
        logger.notice("Opening unified dashboard")
        onOpenDashboard()
    }

    @objc private func toggleSound() {
        let nextValue = !preferencesStore.preferences.soundEnabled
        preferencesStore.preferences.soundEnabled = nextValue
        logger.notice("Sound \(nextValue ? "enabled" : "disabled")")
    }
}
