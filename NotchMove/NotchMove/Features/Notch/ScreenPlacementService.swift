//
//  ScreenPlacementService.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import AppKit
import CoreGraphics

protocol ScreenProviding {
    func currentScreen(for mode: Preferences.OverlayDisplayMode) -> ScreenDescriptor?
    func availableScreens() -> [ScreenDescriptor]
}

struct ScreenDescriptor: Equatable {
    let displayID: CGDirectDisplayID
    let localizedName: String
    let isBuiltIn: Bool
    let frame: CGRect
    let notchFrame: CGRect?
    let menuBarHeight: CGFloat
}

struct OverlayPlacement: Equatable {
    let frame: CGRect
    let tuckedFrame: CGRect
    let topInset: CGFloat
}

struct ScreenPlacementService {
    private enum Sizing {
        static let fallbackTuckedWidth: CGFloat = 164
        static let previewExtraWidth: CGFloat = 48
        static let reminderCollapsedExtraWidth: CGFloat = 88
        static let reminderExpandedExtraWidth: CGFloat = 120
        static let previewMinWidth: CGFloat = 240
        static let previewMaxWidth: CGFloat = 280
        static let reminderCollapsedMinWidth: CGFloat = 280
        static let reminderCollapsedMaxWidth: CGFloat = 320
        static let reminderExpandedMinWidth: CGFloat = 300
        static let reminderExpandedMaxWidth: CGFloat = 340
        static let previewMinHeight: CGFloat = 64
        static let reminderCollapsedMinHeight: CGFloat = 88
        static let reminderExpandedMinHeight: CGFloat = 96
    }

    func placement(
        for presentation: ReminderState.PresentationPhase,
        on screen: ScreenDescriptor,
        notchExpansionEnabled: Bool
    ) -> OverlayPlacement {
        let centerX = screen.notchFrame?.midX ?? screen.frame.midX
        let size = size(for: presentation, on: screen, notchExpansionEnabled: notchExpansionEnabled)
        let tuckedSize = tuckedSize(on: screen)
        let x = centerX - size.width / 2
        let y = screen.frame.maxY - size.height
        let tuckedX = centerX - tuckedSize.width / 2
        let tuckedY = screen.frame.maxY - tuckedSize.height

        return OverlayPlacement(
            frame: CGRect(x: x, y: y, width: size.width, height: size.height),
            tuckedFrame: CGRect(x: tuckedX, y: tuckedY, width: tuckedSize.width, height: tuckedSize.height),
            topInset: screen.notchFrame?.height ?? screen.menuBarHeight
        )
    }

    private func size(
        for presentation: ReminderState.PresentationPhase,
        on screen: ScreenDescriptor,
        notchExpansionEnabled: Bool
    ) -> CGSize {
        let notchWidth = screen.notchFrame?.width ?? Sizing.fallbackTuckedWidth
        let baseHeight = screen.notchFrame?.height ?? screen.menuBarHeight

        switch presentation {
        case .hidden, .reminderPending:
            return tuckedSize(on: screen)
        case .hoverPreview:
            return CGSize(
                width: clamped(
                    notchWidth + Sizing.previewExtraWidth,
                    min: Sizing.previewMinWidth,
                    max: Sizing.previewMaxWidth
                ),
                height: max(baseHeight + 34, Sizing.previewMinHeight)
            )
        case .presenting, .dismissAnimating:
            return reminderSize(
                notchWidth: notchWidth,
                notchExpansionEnabled: notchExpansionEnabled
            )
        }
    }

    private func reminderSize(
        notchWidth: CGFloat,
        notchExpansionEnabled: Bool
    ) -> CGSize {
        if notchExpansionEnabled {
            return CGSize(
                width: clamped(
                    notchWidth + Sizing.reminderExpandedExtraWidth,
                    min: Sizing.reminderExpandedMinWidth,
                    max: Sizing.reminderExpandedMaxWidth
                ),
                height: Sizing.reminderExpandedMinHeight
            )
        }

        return CGSize(
            width: clamped(
                notchWidth + Sizing.reminderCollapsedExtraWidth,
                min: Sizing.reminderCollapsedMinWidth,
                max: Sizing.reminderCollapsedMaxWidth
            ),
            height: Sizing.reminderCollapsedMinHeight
        )
    }

    private func tuckedSize(on screen: ScreenDescriptor) -> CGSize {
        if let notchFrame = screen.notchFrame {
            return notchFrame.size
        }

        return CGSize(
            width: min(Sizing.fallbackTuckedWidth, screen.frame.width),
            height: max(screen.menuBarHeight, 1)
        )
    }

    private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}

struct ScreenSelectionService {
    func selectedScreen(
        for mode: Preferences.OverlayDisplayMode,
        in screens: [ScreenDescriptor],
        mainDisplayID: CGDirectDisplayID?
    ) -> ScreenDescriptor? {
        switch mode {
        case .automatic:
            return automaticScreen(in: screens, mainDisplayID: mainDisplayID)
        case .display(let displayID):
            return screens.first { $0.displayID == displayID } ??
                automaticScreen(in: screens, mainDisplayID: mainDisplayID)
        }
    }

    private func automaticScreen(
        in screens: [ScreenDescriptor],
        mainDisplayID: CGDirectDisplayID?
    ) -> ScreenDescriptor? {
        screens.first { $0.isBuiltIn && $0.notchFrame != nil } ??
            screens.first { $0.isBuiltIn } ??
            screens.first { $0.displayID == mainDisplayID } ??
            screens.first
    }
}

struct MainScreenProvider: ScreenProviding {
    private let selectionService = ScreenSelectionService()

    func currentScreen(for mode: Preferences.OverlayDisplayMode) -> ScreenDescriptor? {
        selectionService.selectedScreen(
            for: mode,
            in: availableScreens(),
            mainDisplayID: NSScreen.main?.displayID
        )
    }

    func availableScreens() -> [ScreenDescriptor] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else { return nil }

            return ScreenDescriptor(
                displayID: displayID,
                localizedName: screen.localizedName,
                isBuiltIn: screen.isBuiltInDisplay,
                frame: screen.frame,
                notchFrame: screen.notchFrame,
                menuBarHeight: screen.menuBarHeight
            )
        }
    }
}
