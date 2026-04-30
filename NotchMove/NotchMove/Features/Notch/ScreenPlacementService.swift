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
    let topInset: CGFloat
}

struct ScreenPlacementService {
    func placement(
        for presentation: ReminderState.PresentationPhase,
        on screen: ScreenDescriptor,
        notchExpansionEnabled: Bool
    ) -> OverlayPlacement {
        let centerX = screen.notchFrame?.midX ?? screen.frame.midX
        let size = size(for: presentation, on: screen, notchExpansionEnabled: notchExpansionEnabled)
        let x = centerX - size.width / 2
        let y = screen.frame.maxY - size.height

        return OverlayPlacement(
            frame: CGRect(x: x, y: y, width: size.width, height: size.height),
            topInset: screen.notchFrame?.height ?? screen.menuBarHeight
        )
    }

    private func size(
        for presentation: ReminderState.PresentationPhase,
        on screen: ScreenDescriptor,
        notchExpansionEnabled: Bool
    ) -> CGSize {
        let notchWidth = screen.notchFrame?.width ?? 200
        let baseHeight = screen.notchFrame?.height ?? screen.menuBarHeight

        switch presentation {
        case .hidden, .dismissAnimating:
            return CGSize(width: notchWidth + 8, height: baseHeight + 24)
        case .hoverPreview:
            return CGSize(width: notchWidth + 60, height: baseHeight + 60)
        case .presenting:
            if notchExpansionEnabled {
                return CGSize(width: 380, height: 160)
            }
            return CGSize(width: notchWidth + 60, height: baseHeight + 60)
        }
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
