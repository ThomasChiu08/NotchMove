//
//  NotchOverlayMetrics.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import CoreGraphics
import Observation

struct OverlayContentFitRequest: Equatable {
    let size: CGSize

    init(size: CGSize, displayScale: CGFloat = 2) {
        self.size = CGSize(
            width: Self.roundedUpToPixel(max(size.width, 1), displayScale: displayScale),
            height: Self.roundedUpToPixel(max(size.height, 1), displayScale: displayScale)
        )
    }

    func isApproximatelyEqual(to other: OverlayContentFitRequest, tolerance: CGFloat = 1) -> Bool {
        abs(size.width - other.size.width) < tolerance &&
            abs(size.height - other.size.height) < tolerance
    }

    private static func roundedUpToPixel(_ value: CGFloat, displayScale: CGFloat) -> CGFloat {
        let safeScale = max(displayScale, 1)
        return ceil(value * safeScale) / safeScale
    }
}

@MainActor
@Observable
final class NotchOverlayMetrics {
    var topInset: CGFloat
    var tuckedSize: CGSize
    var canvasSize: CGSize
    private(set) var contentFitRequest: OverlayContentFitRequest?

    init(
        topInset: CGFloat,
        tuckedSize: CGSize = CGSize(width: 208, height: 38),
        canvasSize: CGSize = CGSize(width: 208, height: 38)
    ) {
        self.topInset = topInset
        self.tuckedSize = tuckedSize
        self.canvasSize = canvasSize
    }

    func requestContentFit(size: CGSize, displayScale: CGFloat) {
        let request = OverlayContentFitRequest(size: size, displayScale: displayScale)
        if let contentFitRequest,
           contentFitRequest.isApproximatelyEqual(to: request) {
            return
        }

        contentFitRequest = request
    }

    func clearContentFitRequest() {
        guard contentFitRequest != nil else { return }
        contentFitRequest = nil
    }
}
