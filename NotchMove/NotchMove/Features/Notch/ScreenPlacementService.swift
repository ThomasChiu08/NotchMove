//
//  ScreenPlacementService.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import AppKit

protocol ScreenProviding {
    func currentScreen() -> ScreenDescriptor?
}

struct ScreenDescriptor: Equatable {
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

struct MainScreenProvider: ScreenProviding {
    func currentScreen() -> ScreenDescriptor? {
        guard let screen = NSScreen.main else { return nil }
        return ScreenDescriptor(
            frame: screen.frame,
            notchFrame: screen.notchFrame,
            menuBarHeight: screen.menuBarHeight
        )
    }
}
