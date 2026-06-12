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
    let visibleSize: CGSize
    let topInset: CGFloat
}

enum OverlaySizingRole: Equatable {
    case standard
    case dualPreview
    case prominentCountdown
    case hubExpanded
}

struct ScreenPlacementService {
    private enum Sizing {
        static let fallbackTuckedWidth: CGFloat = 164
        static let previewExtraWidth: CGFloat = 48
        static let dualPreviewExtraWidth: CGFloat = 160
        static let reminderCollapsedExtraWidth: CGFloat = 88
        static let reminderExpandedExtraWidth: CGFloat = 120
        static let prominentCountdownExtraWidth: CGFloat = 144
        static let previewMinWidth: CGFloat = 240
        static let previewMaxWidth: CGFloat = 280
        static let dualPreviewMinWidth: CGFloat = 332
        static let dualPreviewMaxWidth: CGFloat = 360
        static let reminderCollapsedMinWidth: CGFloat = 280
        static let reminderCollapsedMaxWidth: CGFloat = 320
        static let reminderExpandedMinWidth: CGFloat = 300
        static let reminderExpandedMaxWidth: CGFloat = 340
        static let prominentCountdownMinWidth: CGFloat = 312
        static let prominentCountdownMaxWidth: CGFloat = 360
        static let previewMinHeight: CGFloat = 64
        static let reminderCollapsedMinHeight: CGFloat = 88
        static let reminderExpandedMinHeight: CGFloat = 96
        static let prominentCountdownMinHeight: CGFloat = 88
        static let prominentCountdownMaxHeight: CGFloat = 104
        static let prominentCountdownExtraHeight: CGFloat = 58
        static let dualPreviewMinHeight: CGFloat = 88
        static let dualPreviewMaxHeight: CGFloat = 104
        static let dualPreviewExtraHeight: CGFloat = 58
        static let dualPreviewAdaptiveMaxWidth: CGFloat = 640
        static let dualPreviewAdaptiveHorizontalScreenInset: CGFloat = 80
        static let dualPreviewAdaptiveMaxHeight: CGFloat = 128
        static let hubExpandedMinWidth: CGFloat = 520
        static let hubExpandedMaxWidth: CGFloat = 620
        static let hubExpandedHeight: CGFloat = 318
        static let hubExpandedHorizontalScreenInset: CGFloat = 80
    }

    func placement(
        for presentation: ReminderState.PresentationPhase,
        on screen: ScreenDescriptor,
        notchExpansionEnabled: Bool,
        sizingRole: OverlaySizingRole = .standard,
        contentFitSize: CGSize? = nil
    ) -> OverlayPlacement {
        let centerX = screen.notchFrame?.midX ?? screen.frame.midX
        let size = size(
            for: presentation,
            on: screen,
            notchExpansionEnabled: notchExpansionEnabled,
            sizingRole: sizingRole,
            contentFitSize: contentFitSize
        )
        let tuckedSize = tuckedSize(on: screen)
        let visibleSize = visibleSize(
            for: presentation,
            panelSize: size,
            tuckedSize: tuckedSize
        )
        let x = clampedOriginX(
            centerX - size.width / 2,
            panelWidth: size.width,
            on: screen
        )
        let y = screen.frame.maxY - size.height
        let tuckedX = clampedOriginX(
            centerX - tuckedSize.width / 2,
            panelWidth: tuckedSize.width,
            on: screen
        )
        let tuckedY = screen.frame.maxY - tuckedSize.height

        return OverlayPlacement(
            frame: CGRect(x: x, y: y, width: size.width, height: size.height),
            tuckedFrame: CGRect(x: tuckedX, y: tuckedY, width: tuckedSize.width, height: tuckedSize.height),
            visibleSize: visibleSize,
            topInset: screen.notchFrame?.height ?? screen.menuBarHeight
        )
    }

    private func size(
        for presentation: ReminderState.PresentationPhase,
        on screen: ScreenDescriptor,
        notchExpansionEnabled: Bool,
        sizingRole: OverlaySizingRole,
        contentFitSize: CGSize?
    ) -> CGSize {
        let notchWidth = screen.notchFrame?.width ?? Sizing.fallbackTuckedWidth
        let baseHeight = screen.notchFrame?.height ?? screen.menuBarHeight

        switch presentation {
        case .hidden:
            return tuckedSize(on: screen)
        case .reminderPending:
            if sizingRole == .hubExpanded {
                return hubExpandedSize(screenWidth: screen.frame.width)
            }

            if sizingRole == .prominentCountdown {
                return prominentCountdownSize(
                    notchWidth: notchWidth,
                    baseHeight: baseHeight
                )
            }

            return reminderSize(
                notchWidth: notchWidth,
                notchExpansionEnabled: notchExpansionEnabled
            )
        case .hoverPreviewPending, .hoverPreview, .hoverPreviewDismissing:
            if sizingRole == .hubExpanded {
                return hubExpandedSize(screenWidth: screen.frame.width)
            }

            if sizingRole == .dualPreview {
                return dualPreviewSize(
                    notchWidth: notchWidth,
                    baseHeight: baseHeight,
                    screenWidth: screen.frame.width,
                    contentFitSize: contentFitSize
                )
            }

            if sizingRole == .prominentCountdown {
                return prominentCountdownSize(
                    notchWidth: notchWidth,
                    baseHeight: baseHeight
                )
            }

            return CGSize(
                width: clamped(
                    notchWidth + Sizing.previewExtraWidth,
                    min: Sizing.previewMinWidth,
                    max: Sizing.previewMaxWidth
                ),
                height: max(baseHeight + 34, Sizing.previewMinHeight)
            )
        case .presenting, .dismissAnimating:
            if sizingRole == .hubExpanded {
                return hubExpandedSize(screenWidth: screen.frame.width)
            }

            if sizingRole == .prominentCountdown {
                return prominentCountdownSize(
                    notchWidth: notchWidth,
                    baseHeight: baseHeight
                )
            }

            return reminderSize(
                notchWidth: notchWidth,
                notchExpansionEnabled: notchExpansionEnabled
            )
        }
    }

    private func dualPreviewSize(
        notchWidth: CGFloat,
        baseHeight: CGFloat,
        screenWidth: CGFloat,
        contentFitSize: CGSize?
    ) -> CGSize {
        let baseWidth = clamped(
            notchWidth + Sizing.dualPreviewExtraWidth,
            min: Sizing.dualPreviewMinWidth,
            max: Sizing.dualPreviewMaxWidth
        )
        let basePreviewHeight = clamped(
            baseHeight + Sizing.dualPreviewExtraHeight,
            min: Sizing.dualPreviewMinHeight,
            max: Sizing.dualPreviewMaxHeight
        )
        let adaptiveMaxWidth = max(
            1,
            min(
                Sizing.dualPreviewAdaptiveMaxWidth,
                screenWidth - Sizing.dualPreviewAdaptiveHorizontalScreenInset
            )
        )
        let desiredWidth = max(baseWidth, contentFitSize?.width ?? 0)
        let desiredHeight = max(basePreviewHeight, contentFitSize?.height ?? 0)

        return CGSize(
            width: min(desiredWidth, adaptiveMaxWidth),
            height: min(desiredHeight, Sizing.dualPreviewAdaptiveMaxHeight)
        )
    }

    private func hubExpandedSize(screenWidth: CGFloat) -> CGSize {
        let availableWidth = max(
            1,
            screenWidth - Sizing.hubExpandedHorizontalScreenInset
        )
        let width: CGFloat
        if availableWidth < Sizing.hubExpandedMinWidth {
            width = availableWidth
        } else {
            width = min(Sizing.hubExpandedMaxWidth, availableWidth)
        }

        return CGSize(
            width: width,
            height: Sizing.hubExpandedHeight
        )
    }

    private func prominentCountdownSize(
        notchWidth: CGFloat,
        baseHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: clamped(
                notchWidth + Sizing.prominentCountdownExtraWidth,
                min: Sizing.prominentCountdownMinWidth,
                max: Sizing.prominentCountdownMaxWidth
            ),
            height: clamped(
                baseHeight + Sizing.prominentCountdownExtraHeight,
                min: Sizing.prominentCountdownMinHeight,
                max: Sizing.prominentCountdownMaxHeight
            )
        )
    }

    private func visibleSize(
        for presentation: ReminderState.PresentationPhase,
        panelSize: CGSize,
        tuckedSize: CGSize
    ) -> CGSize {
        switch presentation {
        case .hoverPreview, .presenting:
            panelSize
        case .hidden, .reminderPending, .hoverPreviewPending, .hoverPreviewDismissing, .dismissAnimating:
            tuckedSize
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

    private func clampedOriginX(
        _ value: CGFloat,
        panelWidth: CGFloat,
        on screen: ScreenDescriptor
    ) -> CGFloat {
        let minX = screen.frame.minX
        let maxX = screen.frame.maxX - panelWidth

        guard maxX >= minX else { return minX }

        return clamped(value, min: minX, max: maxX)
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
