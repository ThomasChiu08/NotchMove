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

        let hostingView = NSHostingView(rootView: SettingsView())

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "NotchMove Settings"
        newWindow.contentView = hostingView
        newWindow.contentMinSize = NSSize(width: 420, height: 520)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        // Explicit normal level — accessory apps can default to odd levels.
        newWindow.level = .normal
        newWindow.center()

        window = newWindow

        // Activate first, then show — ensures the app owns the key window.
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
        }
    }
}
