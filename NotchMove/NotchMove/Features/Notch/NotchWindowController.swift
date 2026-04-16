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
    private let viewModel: NotchViewModel
    private var screenChangeObserver: NSObjectProtocol?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        panel = NotchWindow()
        panel.contentView = NSHostingView(rootView: NotchView(viewModel: viewModel))
    }

    func show() {
        updateTopInset()
        repositionForCurrentScreen()
        panel.orderFrontRegardless()
        installScreenChangeObserver()
        observeState()
    }

    private func updateTopInset() {
        guard let screen = NSScreen.main else { return }
        viewModel.topInset = screen.notchFrame?.height ?? screen.menuBarHeight
    }

    func hide() {
        panel.orderOut(nil)
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }

    func triggerReminder() {
        viewModel.triggerReminder()
    }

    // MARK: - State Observation

    private func observeState() {
        withObservationTracking {
            _ = viewModel.state
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleStateChange()
                self?.observeState()
            }
        }
    }

    private func handleStateChange() {
        guard let screen = NSScreen.main else { return }
        let target = frameForState(viewModel.state, on: screen)
        logger.notice("State → \(String(describing: self.viewModel.state), privacy: .public), frame → \(NSStringFromRect(target), privacy: .public)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
            panel.animator().setFrame(target, display: true)
        }
    }

    // MARK: - Frame Calculation

    private func frameForState(_ state: NotchViewModel.State, on screen: NSScreen) -> CGRect {
        let centerX: CGFloat
        let topY = screen.frame.maxY

        if let notch = screen.notchFrame {
            centerX = notch.midX
        } else {
            centerX = screen.frame.midX
        }

        let size = sizeForState(state, on: screen)
        let x = centerX - size.width / 2
        let y = topY - size.height
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func sizeForState(_ state: NotchViewModel.State, on screen: NSScreen) -> CGSize {
        let notchWidth = screen.notchFrame?.width ?? 200
        let baseHeight = screen.notchFrame?.height ?? screen.menuBarHeight

        switch state {
        case .dormant, .dismissed:
            return CGSize(width: notchWidth + 8, height: baseHeight + 24)
        case .hovering:
            return CGSize(width: notchWidth + 60, height: baseHeight + 60)
        case .reminding:
            return CGSize(width: 380, height: 160)
        }
    }

    // MARK: - Screen Tracking

    private func repositionForCurrentScreen() {
        guard let screen = NSScreen.main else {
            logger.notice("No main screen available")
            return
        }

        logger.notice("""
            Screen: frame=\(NSStringFromRect(screen.frame), privacy: .public) \
            hasNotch=\(screen.hasNotch) \
            menuBar=\(screen.menuBarHeight)pt
            """)

        let target = frameForState(viewModel.state, on: screen)
        panel.setFrame(target, display: true, animate: false)
    }

    private func installScreenChangeObserver() {
        guard screenChangeObserver == nil else { return }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionForCurrentScreen()
            }
        }
    }
}
