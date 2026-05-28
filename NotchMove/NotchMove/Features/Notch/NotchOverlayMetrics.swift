//
//  NotchOverlayMetrics.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import CoreGraphics
import Observation

@MainActor
@Observable
final class NotchOverlayMetrics {
    var topInset: CGFloat
    var tuckedSize: CGSize
    var canvasSize: CGSize

    init(
        topInset: CGFloat,
        tuckedSize: CGSize = CGSize(width: 208, height: 38),
        canvasSize: CGSize = CGSize(width: 208, height: 38)
    ) {
        self.topInset = topInset
        self.tuckedSize = tuckedSize
        self.canvasSize = canvasSize
    }
}
