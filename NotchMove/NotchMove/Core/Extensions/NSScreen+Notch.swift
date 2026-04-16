//
//  NSScreen+Notch.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit

extension NSScreen {
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// The rect occupied by the physical camera notch, in global screen coordinates
    /// (bottom-left origin). Returns nil on screens without a notch.
    var notchFrame: CGRect? {
        guard hasNotch,
              let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea
        else { return nil }

        let originX = leftArea.maxX
        let width = rightArea.minX - leftArea.maxX
        let height = safeAreaInsets.top
        let originY = frame.maxY - height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    /// Menu bar height for this screen — enlarged on notched Macs to clear the camera housing.
    var menuBarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }
}
