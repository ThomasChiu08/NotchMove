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

    init(topInset: CGFloat) {
        self.topInset = topInset
    }
}
