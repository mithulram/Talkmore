import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

struct TextTarget {
    let element: AXUIElement?
    let processIdentifier: pid_t?
    let applicationName: String?
    let bundleIdentifier: String?
}

enum TextInsertionRoute: String {
    case accessibility = "Accessibility"
    case pasteboard = "Paste fallback"
}

struct TextInsertionReceipt {
    let element: AXUIElement?
    let insertedText: String
    let caretLocation: CFIndex?
    let canReplace: Bool
    let route: TextInsertionRoute
}

@MainActor
final class TextInserter {
    func captureTarget() -> TextTarget {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        var element = result == .success ? (value as! AXUIElement?) : nil
        var pid: pid_t = 0
        if let element { AXUIElementGetPid(element, &pid) }

        let application = pid == 0
            ? frontmostApplication
            : NSRunningApplication(processIdentifier: pid)

        // The system-wide focused element lookup can intermittently fail in
        // Electron apps and directly after a local rebuild. Ask the frontmost
        // application itself before falling back to simulated paste.
        if element == nil, let application {
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            var focusedValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                applicationElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            ) == .success {
                element = focusedValue as! AXUIElement?
            }
        }

        return TextTarget(
            element: element,
            processIdentifier: application?.processIdentifier,
            applicationName: application?.localizedName,
            bundleIdentifier: application?.bundleIdentifier
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
                    canReplace: true,
                    route: .accessibility
                )
            }
        }

        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else {
            throw InsertionError.couldNotWritePasteboard
        }

        if let pid = target.processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid),
           !app.isActive {
            app.activate()
            try await Task.sleep(nanoseconds: 80_000_000)
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
        else {
            throw InsertionError.couldNotCreatePasteEvent
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        if let pid = target.processIdentifier {
            keyDown.postToPid(pid)
            keyUp.postToPid(pid)
        } else {
            keyDown.post(tap: .cgSessionEventTap)
            keyUp.post(tap: .cgSessionEventTap)
        }
        try await Task.sleep(nanoseconds: 40_000_000)
        return TextInsertionReceipt(
            element: target.element,
            insertedText: text,
            caretLocation: nil,
            canReplace: false,
            route: .pasteboard
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

        guard var replacementRange = TextInsertionPlanner.replacementRange(
            insertedUTF16Length: insertedLength,
            caretLocation: expectedCaret
        ) else { return false }
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

enum TextInsertionPlanner {
    static func replacementRange(insertedUTF16Length: Int, caretLocation: CFIndex) -> CFRange? {
        guard insertedUTF16Length >= 0, caretLocation >= insertedUTF16Length else { return nil }
        return CFRange(
            location: caretLocation - insertedUTF16Length,
            length: insertedUTF16Length
        )
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
