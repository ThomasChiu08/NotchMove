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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = NotchViewModel()
        let monitor = ActivityMonitor()
        let controller = NotchWindowController(viewModel: viewModel)

        let scheduler = ReminderScheduler(activityMonitor: monitor) { [weak viewModel] in
            viewModel?.triggerReminder()
        }

        viewModel.onReminderCompleted = { [weak scheduler] in
            scheduler?.resume()
        }

        monitor.start()
        scheduler.start()
        controller.show()

        self.activityMonitor = monitor
        self.reminderScheduler = scheduler
        self.notchWindowController = controller

        logger.notice("NotchMove launched — monitoring activity, reminder every \(scheduler.reminderInterval)s")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
