//
//  NSScreen+Notch.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import CoreGraphics

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    var isBuiltInDisplay: Bool {
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }

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
