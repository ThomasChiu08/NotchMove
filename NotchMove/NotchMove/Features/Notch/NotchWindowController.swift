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
    private let voiceInputSession: VoiceInputSessionController
    private let languageManager: LanguageManager
    private let preferencesStore: PreferencesStore
    private let onOpenDashboard: () -> Void
    private let onOpenSettings: () -> Void
    private let overlayMetrics: NotchOverlayMetrics
    private let hostingView: NotchHostingView
    private let screenProvider: ScreenProviding
    private let placementService: ScreenPlacementService
    private var interactiveFrame: CGRect?
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
        voiceInputSession: VoiceInputSessionController,
        languageManager: LanguageManager,
        preferencesStore: PreferencesStore,
        onOpenDashboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        screenProvider: ScreenProviding = MainScreenProvider(),
        placementService: ScreenPlacementService = ScreenPlacementService()
    ) {
        self.reminderEngine = reminderEngine
        self.voiceInputSession = voiceInputSession
        self.languageManager = languageManager
        self.preferencesStore = preferencesStore
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
        self.screenProvider = screenProvider
        self.placementService = placementService
        let overlayMetrics = NotchOverlayMetrics(topInset: 38)
        self.overlayMetrics = overlayMetrics
        hostingView = NotchHostingView(
            rootView: Self.makeRootView(
                reminderEngine: reminderEngine,
                voiceInputSession: voiceInputSession,
                overlayMetrics: overlayMetrics,
                locale: languageManager.locale,
                onOpenDashboard: onOpenDashboard,
                onOpenSettings: onOpenSettings
            )
        )
        hostingView.wantsLayer = true
        hostingView.layer?.drawsAsynchronously = true
        hostingView.layer?.allowsEdgeAntialiasing = true
        panel = NotchWindow()
        hostingView.interactiveFrameProvider = { [weak self] in
            self?.interactiveFrame
        }
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
        observeVoiceInputState()
        observeOverlayContentFit()
    }

    // MARK: - State Observation

    private func observeReminderState() {
        withObservationTracking {
            _ = reminderEngine.overlayState.presentation
            _ = reminderEngine.overlayState.content
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
                self?.observeReminderState()
            }
        }
    }

    private func observeVoiceInputState() {
        withObservationTracking {
            _ = voiceInputSession.phase
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
                self?.observeVoiceInputState()
            }
        }
    }

    // MARK: - Screen Tracking

    private func applyCurrentPlacement(animated: Bool) {
        guard let screen = screenProvider.currentScreen(for: preferencesStore.preferences.overlayDisplayMode) else {
            return
        }

        let sizingRole = activeSizingRole
        let placement = placementService.placement(
            for: activePresentation,
            on: screen,
            notchExpansionEnabled: preferencesStore.preferences.notchExpansionEnabled,
            sizingRole: sizingRole,
            contentFitSize: contentFitSize(for: sizingRole)
        )
        clearStaleContentFitRequestIfNeeded(sizingRole: sizingRole)
        updateOverlayMetrics(with: placement)
        updateInteractiveFrame(with: placement)

        guard panel.frame != placement.frame else { return }
        panel.setFrame(placement.frame, display: true, animate: false)
    }

    private var activeSizingRole: OverlaySizingRole {
        if isHoverPreviewPresentation {
            if case .breakCompletionCountdown = reminderEngine.overlayState.content {
                return .standard
            }

            return .dualPreview
        }

        if case .pomodoroCountdown = reminderEngine.overlayState.content {
            return .prominentCountdown
        }

        return .standard
    }

    private func observeOverlayContentFit() {
        withObservationTracking {
            _ = overlayMetrics.contentFitRequest
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyCurrentPlacement(animated: true)
                self?.observeOverlayContentFit()
            }
        }
    }

    private func contentFitSize(for sizingRole: OverlaySizingRole) -> CGSize? {
        guard activePresentation == .hoverPreview,
              sizingRole == .dualPreview
        else {
            return nil
        }

        return overlayMetrics.contentFitRequest?.size
    }

    private func clearStaleContentFitRequestIfNeeded(sizingRole: OverlaySizingRole) {
        guard activePresentation != .hoverPreview || sizingRole != .dualPreview else { return }
        overlayMetrics.clearContentFitRequest()
    }

    private var isHoverPreviewPresentation: Bool {
        switch activePresentation {
        case .hoverPreviewPending, .hoverPreview, .hoverPreviewDismissing:
            true
        case .hidden, .reminderPending, .presenting, .dismissAnimating:
            false
        }
    }

    private func updateOverlayMetrics(with placement: OverlayPlacement) {
        if overlayMetrics.topInset != placement.topInset {
            overlayMetrics.topInset = placement.topInset
        }

        if overlayMetrics.tuckedSize != placement.tuckedFrame.size {
            overlayMetrics.tuckedSize = placement.tuckedFrame.size
        }

        if overlayMetrics.canvasSize != placement.frame.size {
            overlayMetrics.canvasSize = placement.frame.size
        }
    }

    private func updateInteractiveFrame(with placement: OverlayPlacement) {
        let size = placement.visibleSize
        let origin = CGPoint(
            x: max((placement.frame.width - size.width) / 2, 0),
            y: max(placement.frame.height - size.height, 0)
        )
        interactiveFrame = CGRect(origin: origin, size: size)
    }

    private func updateHostingRootView() {
        hostingView.rootView = Self.makeRootView(
            reminderEngine: reminderEngine,
            voiceInputSession: voiceInputSession,
            overlayMetrics: overlayMetrics,
            locale: languageManager.locale,
            onOpenDashboard: onOpenDashboard,
            onOpenSettings: onOpenSettings
        )
    }

    private var activePresentation: ReminderState.PresentationPhase {
        voiceInputSession.isOverlayVisible ? .presenting : reminderEngine.overlayState.presentation
    }

    private static func makeRootView(
        reminderEngine: ReminderEngine,
        voiceInputSession: VoiceInputSessionController,
        overlayMetrics: NotchOverlayMetrics,
        locale: Locale,
        onOpenDashboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> AnyView {
        AnyView(
            NotchView(
                reminderEngine: reminderEngine,
                voiceInputSession: voiceInputSession,
                overlayMetrics: overlayMetrics,
                onOpenDashboard: onOpenDashboard,
                onOpenSettings: onOpenSettings
            )
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

private final class NotchHostingView: NSHostingView<AnyView> {
    var interactiveFrameProvider: (() -> CGRect?)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let interactiveFrame = interactiveFrameProvider?(),
              interactiveFrame.contains(point)
        else {
            return nil
        }

        return super.hitTest(point)
    }
}
