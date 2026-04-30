//
//  SettingsWindowController.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/17/26.
//

import AppKit
import SwiftUI

/// Manages a single-instance Settings window for this accessory (LSUIElement) app.
///
/// Accessory apps have no dock icon, so `NSApp.activate(ignoringOtherApps:)`
/// is required to bring the window to the front. The open call is dispatched
/// asynchronously to avoid racing with the status-item menu dismissal.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private let languageManager: LanguageManager
    private let preferencesStore: PreferencesStore
    private let breakStatsStore: BreakStatsStore
    private let loginItemManager: any LoginItemManaging
    private nonisolated(unsafe) var languageObserver: NSObjectProtocol?

    init(
        languageManager: LanguageManager,
        preferencesStore: PreferencesStore,
        breakStatsStore: BreakStatsStore,
        loginItemManager: any LoginItemManaging
    ) {
        self.languageManager = languageManager
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

    func openSettings() {
        // Defer to next run-loop tick so the status-item menu finishes
        // closing before we activate the app and show the window.
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

        let hostingView = NSHostingView(rootView: makeSettingsRootView())

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = languageManager.localizedString("settings.title")
        newWindow.contentView = hostingView
        newWindow.contentMinSize = NSSize(width: 420, height: 520)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        // Explicit normal level — accessory apps can default to odd levels.
        newWindow.level = .normal
        newWindow.center()

        window = newWindow
        self.hostingView = hostingView

        // Activate first, then show — ensures the app owns the key window.
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    /// Builds the SwiftUI root view with locale environment injected.
    private func makeSettingsRootView() -> AnyView {
        AnyView(
            SettingsView(
                languageManager: languageManager,
                loginItemManager: loginItemManager,
                preferencesStore: preferencesStore,
                breakStatsStore: breakStatsStore
            )
                .environment(\.locale, languageManager.locale)
        )
    }

    /// Replaces the hosting view content and updates the window title
    /// when the user switches language.
    private func refreshWindowContent() {
        guard let window, let hostingView else { return }
        window.title = languageManager.localizedString("settings.title")
        hostingView.rootView = makeSettingsRootView()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
            self.hostingView = nil
        }
    }
}
