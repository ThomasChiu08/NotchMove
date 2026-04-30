//
//  DashboardWindowController.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private let languageManager: LanguageManager
    private let reminderEngine: ReminderEngine
    private let scheduleStore: DailyScheduleStore
    private let preferencesStore: PreferencesStore
    private let breakStatsStore: BreakStatsStore
    private let loginItemManager: any LoginItemManaging
    private nonisolated(unsafe) var languageObserver: NSObjectProtocol?

    init(
        languageManager: LanguageManager,
        reminderEngine: ReminderEngine,
        scheduleStore: DailyScheduleStore,
        preferencesStore: PreferencesStore,
        breakStatsStore: BreakStatsStore,
        loginItemManager: any LoginItemManaging
    ) {
        self.languageManager = languageManager
        self.reminderEngine = reminderEngine
        self.scheduleStore = scheduleStore
        self.preferencesStore = preferencesStore
        self.breakStatsStore = breakStatsStore
        self.loginItemManager = loginItemManager
        super.init()

        languageObserver = NotificationCenter.default.addObserver(
            forName: LanguageManager.didChangeNotification,
            object: languageManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshWindowContent()
            }
        }
    }

    deinit {
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func openDashboard() {
        DispatchQueue.main.async { [weak self] in
            self?.presentWindow()
        }
    }

    private func presentWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: makeDashboardRootView())
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = languageManager.localizedString("dashboard.unified.title")
        newWindow.contentView = hostingView
        newWindow.contentMinSize = NSSize(width: 860, height: 560)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.level = .normal
        newWindow.center()

        window = newWindow
        self.hostingView = hostingView

        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    private func makeDashboardRootView() -> AnyView {
        AnyView(
            UnifiedDashboardView(
                languageManager: languageManager,
                loginItemManager: loginItemManager,
                reminderEngine: reminderEngine,
                scheduleStore: scheduleStore,
                preferencesStore: preferencesStore,
                breakStatsStore: breakStatsStore
            )
            .environment(\.locale, languageManager.locale)
        )
    }

    private func refreshWindowContent() {
        guard let window, let hostingView else { return }
        window.title = languageManager.localizedString("dashboard.unified.title")
        hostingView.rootView = makeDashboardRootView()
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
            self.hostingView = nil
        }
    }
}
