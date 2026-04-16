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

    private var activityMonitor: ActivityMonitor?
    private var reminderScheduler: ReminderScheduler?
    private var notchWindowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var settingsObserver: SettingsObserver?
    private let sessionCounter = SessionCounter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Default preferences — applied only when the key has never been set.
        UserDefaults.standard.register(defaults: [
            "soundEnabled": true,
            "reminderIntervalMinutes": 30,
            "sitAwareEnabled": true,
            "scheduleEnabled": false,
            "scheduleStartHour": 9,
            "scheduleStartMinute": 0,
            "scheduleEndHour": 18,
            "scheduleEndMinute": 0,
            "weekdaysOnly": true,
            "notchExpansionEnabled": true,
            "hoverPreviewEnabled": true,
            "autoDismissEnabled": true,
            "autoDismissSeconds": 60,
        ])

        let viewModel = NotchViewModel()
        let monitor = ActivityMonitor()
        let controller = NotchWindowController(viewModel: viewModel)

        let scheduler = ReminderScheduler(activityMonitor: monitor) { [weak viewModel] in
            viewModel?.triggerReminder()
            // Play sound if the user has not disabled it.
            if UserDefaults.standard.bool(forKey: "soundEnabled") {
                Task { @MainActor in
                    NSSound(named: "Funk")?.play()
                }
            }
        }

        viewModel.onReminderCompleted = { [weak scheduler, weak sessionCounter] in
            scheduler?.resume()
            sessionCounter?.recordBreak()
        }

        // Bridge UserDefaults → runtime components (applies persisted values immediately).
        let observer = SettingsObserver(
            scheduler: scheduler,
            viewModel: viewModel,
            windowController: controller
        )

        let settingsWindow = SettingsWindowController()

        monitor.start()
        scheduler.start()
        controller.show()

        self.activityMonitor = monitor
        self.reminderScheduler = scheduler
        self.notchWindowController = controller
        self.settingsObserver = observer
        self.settingsWindowController = settingsWindow
        self.menuBarController = MenuBarController(
            viewModel: viewModel,
            scheduler: scheduler,
            sessionCounter: sessionCounter,
            onOpenSettings: { [weak settingsWindow] in
                settingsWindow?.openSettings()
            }
        )

        logger.notice("NotchMove launched — monitoring activity, reminder every \(scheduler.reminderInterval)s")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
