//
//  GlobalHotkeyShortcut.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Carbon.HIToolbox
import Foundation

struct GlobalHotkeyShortcut: Identifiable, RawRepresentable, CaseIterable, Equatable, Hashable {
    static let `default` = GlobalHotkeyShortcut.controlOptionSpace

    static let controlOptionSpace = GlobalHotkeyShortcut(
        rawValue: "control-option-space",
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(controlKey | optionKey),
        displayNameKey: "ai.settings.global_hotkey_shortcut_control_option_space"
    )

    static let controlOptionA = GlobalHotkeyShortcut(
        rawValue: "control-option-a",
        keyCode: UInt32(kVK_ANSI_A),
        carbonModifiers: UInt32(controlKey | optionKey),
        displayNameKey: "ai.settings.global_hotkey_shortcut_control_option_a"
    )

    static let controlOptionM = GlobalHotkeyShortcut(
        rawValue: "control-option-m",
        keyCode: UInt32(kVK_ANSI_M),
        carbonModifiers: UInt32(controlKey | optionKey),
        displayNameKey: "ai.settings.global_hotkey_shortcut_control_option_m"
    )

    static let allCases: [GlobalHotkeyShortcut] = [
        .controlOptionSpace,
        .controlOptionA,
        .controlOptionM,
    ]

    let rawValue: String
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let displayNameKey: String

    var id: String { rawValue }

    init?(rawValue: String) {
        guard let shortcut = Self.allCases.first(where: { $0.rawValue == rawValue }) else {
            return nil
        }

        self = shortcut
    }

    private init(
        rawValue: String,
        keyCode: UInt32,
        carbonModifiers: UInt32,
        displayNameKey: String
    ) {
        self.rawValue = rawValue
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayNameKey = displayNameKey
    }
}
