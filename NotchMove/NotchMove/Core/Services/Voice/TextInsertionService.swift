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
            guard copyToPasteboard(trimmedText) else {
                let outcome = TextInsertionOutcome.failed("Could not copy text to the clipboard.")
                lastOutcome = outcome
                return outcome
            }
            lastOutcome = .copiedToClipboard
            logger.notice("Voice text copied because Accessibility is not trusted")
            return .copiedToClipboard
        }

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        guard copyToPasteboard(trimmedText) else {
            let outcome = TextInsertionOutcome.failed("Could not copy text to the clipboard.")
            lastOutcome = outcome
            return outcome
        }

        let pasteboardChangeCountAfterCopy = pasteboard.changeCount
        guard postCommandKey(virtualKey: UInt16(kVK_ANSI_V)) else {
            lastOutcome = .copiedToClipboard
            return .copiedToClipboard
        }

        try? await Task.sleep(for: .milliseconds(250))
        if !snapshot.restoreIfUnchanged(to: pasteboard, expectedChangeCount: pasteboardChangeCountAfterCopy) {
            logger.notice("Skipped clipboard restoration because the pasteboard changed after voice paste")
        }

        lastOutcome = .pastedViaClipboard
        logger.notice("Voice text pasted through clipboard fallback")
        return .pastedViaClipboard
    }

    func undoLastInsertion() {
        guard let lastOutcome, lastOutcome.didReachTargetApp, AccessibilityPermissionService.isTrusted else {
            return
        }

        _ = postCommandKey(virtualKey: UInt16(kVK_ANSI_Z))
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

        guard let focusedElement = TextInsertionService.accessibilityElement(from: focusedValue) else {
            return false
        }
        let selectedTextResult = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return selectedTextResult == .success
    }

    private func copyToPasteboard(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private func postCommandKey(virtualKey: UInt16) -> Bool {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    static func accessibilityElement(from value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }
}

struct PasteboardSnapshot {
    struct Item {
        var representations: [(type: NSPasteboard.PasteboardType, data: Data)]
    }

    var items: [Item]
    var capturedChangeCount: Int

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            Item(representations: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type: type, data: data)
            })
        } ?? []

        return PasteboardSnapshot(items: items, capturedChangeCount: pasteboard.changeCount)
    }

    func restoreIfUnchanged(to pasteboard: NSPasteboard, expectedChangeCount: Int) -> Bool {
        guard pasteboard.changeCount == expectedChangeCount else { return false }
        pasteboard.clearContents()
        guard !items.isEmpty else { return true }

        let restoredItems = items.map { snapshotItem in
            let item = NSPasteboardItem()
            for representation in snapshotItem.representations {
                item.setData(representation.data, forType: representation.type)
            }
            return item
        }

        return pasteboard.writeObjects(restoredItems)
    }
}
