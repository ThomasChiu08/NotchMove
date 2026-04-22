//
//  AppDelegate.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "lifecycle")
    private let settings = AppSettings()
    private lazy var preferencesStore = PreferencesStore(settings: settings)
    private lazy var breakStatsStore = BreakStatsStore(defaults: settings.defaults)
    private lazy var languageManager = LanguageManager(preferencesStore: preferencesStore)

    private var activityMonitor: ActivityMonitor?
    private var reminderEngine: ReminderEngine?
    private var notchWindowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let monitor = ActivityMonitor()
        let engine = ReminderEngine(
            activityMonitor: monitor,
            preferencesStore: preferencesStore,
            soundPlayer: SystemSoundPlayer(preferencesStore: preferencesStore),
            breakStatsStore: breakStatsStore
        )
        let controller = NotchWindowController(
            reminderEngine: engine,
            languageManager: languageManager,
            preferencesStore: preferencesStore
        )
        let settingsWindow = SettingsWindowController(
            languageManager: languageManager,
            preferencesStore: preferencesStore,
            breakStatsStore: breakStatsStore
        )

        monitor.start()
        engine.start()
        controller.show()

        self.activityMonitor = monitor
        self.reminderEngine = engine
        self.notchWindowController = controller
        self.settingsWindowController = settingsWindow
        self.menuBarController = MenuBarController(
            reminderEngine: engine,
            breakStatsStore: breakStatsStore,
            languageManager: languageManager,
            preferencesStore: preferencesStore,
            onOpenSettings: { [weak settingsWindow] in
                settingsWindow?.openSettings()
            }
        )

        logger.notice("NotchMove launched — monitoring activity, reminder every \(engine.reminderInterval)s")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
