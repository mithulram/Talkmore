import AppKit
import ApplicationServices
import CoreGraphics

struct TextTarget {
    let element: AXUIElement?
    let processIdentifier: pid_t?
}

struct TextInsertionReceipt {
    let element: AXUIElement?
    let insertedText: String
    let caretLocation: CFIndex?
    let canReplace: Bool
}

@MainActor
final class TextInserter {
    func captureTarget() -> TextTarget {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        let element = result == .success ? (value as! AXUIElement?) : nil
        var pid: pid_t = 0
        if let element { AXUIElementGetPid(element, &pid) }

        return TextTarget(
            element: element,
            processIdentifier: pid == 0 ? NSWorkspace.shared.frontmostApplication?.processIdentifier : pid
        )
    }

    func insert(_ text: String, into target: TextTarget) async throws -> TextInsertionReceipt {
        if let element = target.element {
            let result = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                text as CFTypeRef
            )
            if result == .success {
                return TextInsertionReceipt(
                    element: element,
                    insertedText: text,
                    caretLocation: selectedRange(of: element)?.location,
                    canReplace: true
                )
            }
        }

        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else {
            throw InsertionError.couldNotWritePasteboard
        }

        if let pid = target.processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
            try await Task.sleep(nanoseconds: 80_000_000)
        }

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        else {
            throw InsertionError.couldNotCreatePasteEvent
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return TextInsertionReceipt(
            element: target.element,
            insertedText: text,
            caretLocation: nil,
            canReplace: false
        )
    }

    func replaceIfUnchanged(_ receipt: TextInsertionReceipt, with replacement: String) -> Bool {
        guard
            receipt.canReplace,
            replacement != receipt.insertedText,
            let element = receipt.element,
            let expectedCaret = receipt.caretLocation,
            let currentSelection = selectedRange(of: element),
            currentSelection.length == 0,
            currentSelection.location == expectedCaret
        else { return replacement == receipt.insertedText }

        let insertedLength = (receipt.insertedText as NSString).length
        guard expectedCaret >= insertedLength else { return false }

        var replacementRange = CFRange(
            location: expectedCaret - insertedLength,
            length: insertedLength
        )
        guard let rangeValue = AXValueCreate(.cfRange, &replacementRange) else { return false }
        guard AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        ) == .success else { return false }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFTypeRef
        ) == .success
    }

    private func selectedRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
        let axValue = value as! AXValue?,
        AXValueGetType(axValue) == .cfRange else { return nil }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
}

enum InsertionError: LocalizedError {
    case couldNotWritePasteboard
    case couldNotCreatePasteEvent

    var errorDescription: String? {
        switch self {
        case .couldNotWritePasteboard: "Talkmore could not copy the transcript for insertion."
        case .couldNotCreatePasteEvent: "Talkmore could not send the paste command."
        }
    }
}
