//
//  TextInsertionService.swift
//  NotchMove
//
//  Created by Codex on 5/14/26.
//

import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Foundation
import OSLog

enum TextInsertionOutcome: Equatable {
    case insertedViaAccessibility
    case pastedViaClipboard
    case copiedToClipboard
    case failed(String)

    var didReachTargetApp: Bool {
        switch self {
        case .insertedViaAccessibility, .pastedViaClipboard:
            true
        case .copiedToClipboard, .failed:
            false
        }
    }
}

@MainActor
final class TextInsertionService {
    private let pasteboard: NSPasteboard
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "voice-insertion")
    private var lastOutcome: TextInsertionOutcome?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func insert(_ text: String) async -> TextInsertionOutcome {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .failed("There is no text to insert.")
        }

        if insertUsingFocusedAccessibilityElement(trimmedText) {
            lastOutcome = .insertedViaAccessibility
            logger.notice("Voice text inserted through Accessibility")
            return .insertedViaAccessibility
        }

        guard AccessibilityPermissionService.isTrusted else {
            _ = AccessibilityPermissionService.requestTrustPrompt()
            copyToPasteboard(trimmedText)
            lastOutcome = .copiedToClipboard
            logger.notice("Voice text copied because Accessibility is not trusted")
            return .copiedToClipboard
        }

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        copyToPasteboard(trimmedText)
        postCommandKey(virtualKey: UInt16(kVK_ANSI_V))

        try? await Task.sleep(for: .milliseconds(250))
        snapshot.restore(to: pasteboard)

        lastOutcome = .pastedViaClipboard
        logger.notice("Voice text pasted through clipboard fallback")
        return .pastedViaClipboard
    }

    func undoLastInsertion() {
        guard let lastOutcome, lastOutcome.didReachTargetApp, AccessibilityPermissionService.isTrusted else {
            return
        }

        postCommandKey(virtualKey: UInt16(kVK_ANSI_Z))
        self.lastOutcome = nil
        logger.notice("Voice insertion undo requested")
    }

    private func insertUsingFocusedAccessibilityElement(_ text: String) -> Bool {
        guard AccessibilityPermissionService.isTrusted else { return false }

        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedResult == .success, let focusedValue else { return false }

        let focusedElement = focusedValue as! AXUIElement
        let selectedTextResult = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return selectedTextResult == .success
    }

    private func copyToPasteboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func postCommandKey(virtualKey: UInt16) {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false)
        else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    struct Item {
        var representations: [(type: NSPasteboard.PasteboardType, data: Data)]
    }

    var items: [Item]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            Item(representations: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type: type, data: data)
            })
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restoredItems = items.map { snapshotItem in
            let item = NSPasteboardItem()
            for representation in snapshotItem.representations {
                item.setData(representation.data, forType: representation.type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}
