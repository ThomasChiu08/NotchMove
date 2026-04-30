//
//  NotchWindowController.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import SwiftUI

final class NotchWindowController {
    private let panel: NotchWindow
    private let reminderEngine: ReminderEngine
    private let languageManager: LanguageManager
    private let preferencesStore: PreferencesStore
    private let overlayMetrics: NotchOverlayMetrics
    private let hostingView: NSHostingView<AnyView>
    private let screenProvider: ScreenProviding
    private let placementService: ScreenPlacementService
    private nonisolated(unsafe) var screenChangeObserver: NSObjectProtocol?
    private nonisolated(unsafe) var languageObserver: NSObjectProtocol?
    private nonisolated(unsafe) var notchLayoutObserver: NSObjectProtocol?

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = notchLayoutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

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
        let overlayMetrics = NotchOverlayMetrics(topInset: 38)
        self.overlayMetrics = overlayMetrics
        hostingView = NSHostingView(
            rootView: Self.makeRootView(
                reminderEngine: reminderEngine,
                overlayMetrics: overlayMetrics,
                locale: languageManager.locale
            )
        )
        hostingView.wantsLayer = true
        hostingView.layer?.drawsAsynchronously = true
        hostingView.layer?.allowsEdgeAntialiasing = true
        panel = NotchWindow()
        panel.contentView = hostingView

        languageObserver = NotificationCenter.default.addObserver(
            forName: LanguageManager.didChangeNotification,
            object: languageManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateHostingRootView()
                self?.applyCurrentPlacement(animated: false)
            }
        }

        notchLayoutObserver = NotificationCenter.default.addObserver(
            forName: PreferencesStore.notchLayoutDidChangeNotification,
            object: preferencesStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
            }
        }
    }

    func show() {
        applyCurrentPlacement(animated: false)
        panel.orderFrontRegardless()
        installScreenChangeObserver()
        observeReminderState()
    }

    // MARK: - State Observation

    private func observeReminderState() {
        withObservationTracking {
            _ = reminderEngine.overlayState.presentation
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
                self?.observeReminderState()
            }
        }
    }

    // MARK: - Screen Tracking

    private func applyCurrentPlacement(animated: Bool) {
        guard let screen = screenProvider.currentScreen(for: preferencesStore.preferences.overlayDisplayMode) else {
            return
        }

        let placement = placementService.placement(
            for: reminderEngine.overlayState.presentation,
            on: screen,
            notchExpansionEnabled: preferencesStore.preferences.notchExpansionEnabled
        )
        if overlayMetrics.topInset != placement.topInset {
            overlayMetrics.topInset = placement.topInset
        }

        guard panel.frame != placement.frame else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(placement.frame, display: true)
            }
        } else {
            panel.setFrame(placement.frame, display: true, animate: false)
        }
    }

    private func updateHostingRootView() {
        hostingView.rootView = Self.makeRootView(
            reminderEngine: reminderEngine,
            overlayMetrics: overlayMetrics,
            locale: languageManager.locale
        )
    }

    private static func makeRootView(
        reminderEngine: ReminderEngine,
        overlayMetrics: NotchOverlayMetrics,
        locale: Locale
    ) -> AnyView {
        AnyView(
            NotchView(reminderEngine: reminderEngine, overlayMetrics: overlayMetrics)
                .environment(\.locale, locale)
        )
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
