//
//  NotchWindowController.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import OSLog
import SwiftUI

final class NotchWindowController {
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "notch-window")
    private let panel: NotchWindow
    private let reminderEngine: ReminderEngine
    private let languageManager: LanguageManager
    private let preferencesStore: PreferencesStore
    private let screenProvider: ScreenProviding
    private let placementService: ScreenPlacementService
    private var screenChangeObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?

    init(
        reminderEngine: ReminderEngine,
        languageManager: LanguageManager,
        preferencesStore: PreferencesStore,
        screenProvider: ScreenProviding = MainScreenProvider(),
        placementService: ScreenPlacementService = ScreenPlacementService()
    ) {
        self.reminderEngine = reminderEngine
        self.languageManager = languageManager
        self.preferencesStore = preferencesStore
        self.screenProvider = screenProvider
        self.placementService = placementService
        panel = NotchWindow()
        refreshHostingView(topInset: 38)

        languageObserver = NotificationCenter.default.addObserver(
            forName: LanguageManager.didChangeNotification,
            object: languageManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: false)
            }
        }
    }

    private func refreshHostingView(topInset: CGFloat) {
        panel.contentView = NSHostingView(
            rootView: NotchView(reminderEngine: reminderEngine, topInset: topInset)
                .environment(\.locale, languageManager.locale)
        )
    }

    func show() {
        applyCurrentPlacement(animated: false)
        panel.orderFrontRegardless()
        installScreenChangeObserver()
        observeReminderState()
        observePreferences()
    }

    func hide() {
        panel.orderOut(nil)
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }

    // MARK: - State Observation

    private func observeReminderState() {
        withObservationTracking {
            _ = reminderEngine.state.presentation
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
                self?.observeReminderState()
            }
        }
    }

    private func observePreferences() {
        withObservationTracking {
            _ = preferencesStore.preferences.notchExpansionEnabled
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
                self?.observePreferences()
            }
        }
    }

    // MARK: - Screen Tracking

    private func applyCurrentPlacement(animated: Bool) {
        guard let screen = screenProvider.currentScreen() else {
            logger.notice("No main screen available")
            return
        }

        let placement = placementService.placement(
            for: reminderEngine.state.presentation,
            on: screen,
            notchExpansionEnabled: preferencesStore.preferences.notchExpansionEnabled
        )
        refreshHostingView(topInset: placement.topInset)

        logger.notice("""
            Screen: frame=\(NSStringFromRect(screen.frame), privacy: .public) \
            hasNotch=\(screen.notchFrame != nil) \
            menuBar=\(screen.menuBarHeight)pt \
            state=\(String(describing: self.reminderEngine.state.presentation), privacy: .public)
            """)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
                panel.animator().setFrame(placement.frame, display: true)
            }
        } else {
            panel.setFrame(placement.frame, display: true, animate: false)
        }
    }

    private func installScreenChangeObserver() {
        guard screenChangeObserver == nil else { return }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: false)
            }
        }
    }
}
