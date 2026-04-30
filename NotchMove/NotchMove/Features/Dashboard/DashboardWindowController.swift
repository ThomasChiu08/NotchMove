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
    private let scheduleStore: DailyScheduleStore
    private nonisolated(unsafe) var languageObserver: NSObjectProtocol?

    init(languageManager: LanguageManager, scheduleStore: DailyScheduleStore) {
        self.languageManager = languageManager
        self.scheduleStore = scheduleStore
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
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = languageManager.localizedString("dashboard.title")
        newWindow.contentView = hostingView
        newWindow.contentMinSize = NSSize(width: 680, height: 460)
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
            DailyScheduleDashboardView(
                languageManager: languageManager,
                scheduleStore: scheduleStore
            )
            .environment(\.locale, languageManager.locale)
        )
    }

    private func refreshWindowContent() {
        guard let window, let hostingView else { return }
        window.title = languageManager.localizedString("dashboard.title")
        hostingView.rootView = makeDashboardRootView()
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
            self.hostingView = nil
        }
    }
}
