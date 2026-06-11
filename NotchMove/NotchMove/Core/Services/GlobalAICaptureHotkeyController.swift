//
//  GlobalAICaptureHotkeyController.swift
//  NotchMove
//
//  Created by Codex on 5/1/26.
//

import Carbon.HIToolbox
import Foundation
import Observation
import OSLog

enum GlobalHotkeyRegistrationState: Equatable {
    case disabled
    case registered(GlobalHotkeyShortcut)
    case failed(GlobalHotkeyShortcut, String)
}

@MainActor
@Observable
final class GlobalAICaptureHotkeyController {
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "global-hotkey")
    private let onPress: () -> Void
    private let onRelease: () -> Void
    @ObservationIgnored private nonisolated(unsafe) var eventHandlerRef: EventHandlerRef?
    @ObservationIgnored private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private nonisolated(unsafe) var isEventHandlerInstalled = false

    private static let hotKeySignature = OSType(0x4E4D4149) // NMAI
    private static let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)

    var registrationState: GlobalHotkeyRegistrationState = .disabled

    init(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func update(preferences: Preferences) {
        unregisterHotkey()

        guard preferences.voiceInputEnabled else {
            registrationState = .disabled
            return
        }

        let shortcut = GlobalHotkeyShortcut(rawValue: preferences.voiceInputShortcutID) ?? .default

        guard installEventHandlerIfNeeded(for: shortcut) else {
            return
        }

        var newHotKeyRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard registerStatus == noErr, let newHotKeyRef else {
            let message = Self.message(for: registerStatus)
            registrationState = .failed(shortcut, message)
            logger.error("Global AI capture hotkey registration failed: \(message, privacy: .public)")
            return
        }

        hotKeyRef = newHotKeyRef
        registrationState = .registered(shortcut)
        logger.notice("Global AI capture hotkey registered: \(shortcut.rawValue, privacy: .public)")
    }

    func retry(preferences: Preferences) {
        update(preferences: preferences)
    }

    fileprivate func handleHotKeyEvent(kind: UInt32) {
        switch kind {
        case UInt32(kEventHotKeyPressed):
            logger.notice("Global AI capture hotkey pressed")
            onPress()
        case UInt32(kEventHotKeyReleased):
            logger.notice("Global AI capture hotkey released")
            onRelease()
        default:
            break
        }
    }

    private func installEventHandlerIfNeeded(for shortcut: GlobalHotkeyShortcut) -> Bool {
        guard !isEventHandlerInstalled else { return true }

        let eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            ),
        ]
        let installStatus = eventTypes.withUnsafeBufferPointer { buffer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                globalAICaptureHotkeyEventHandler,
                buffer.count,
                buffer.baseAddress,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )
        }

        guard installStatus == noErr else {
            let message = Self.message(for: installStatus)
            registrationState = .failed(shortcut, message)
            logger.error("Global AI capture hotkey event handler failed: \(message, privacy: .public)")
            return false
        }

        isEventHandlerInstalled = true
        return true
    }

    private func unregisterHotkey() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private static func message(for status: OSStatus) -> String {
        switch status {
        case OSStatus(eventHotKeyExistsErr):
            "The shortcut is already in use."
        case OSStatus(eventHotKeyInvalidErr):
            "The shortcut is not valid for a global hotkey."
        default:
            "macOS returned status \(status)."
        }
    }
}

private let globalAICaptureHotkeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else { return noErr }

    let controller = Unmanaged<GlobalAICaptureHotkeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()
    let kind = event.map { GetEventKind($0) } ?? 0

    Task { @MainActor in
        controller.handleHotKeyEvent(kind: kind)
    }

    return noErr
}
