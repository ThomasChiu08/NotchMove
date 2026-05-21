//
//  AccessibilityPermissionService.swift
//  NotchMove
//
//  Created by Codex on 5/14/26.
//

import ApplicationServices
import Foundation

enum AccessibilityPermissionService {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestTrustPrompt() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true,
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
