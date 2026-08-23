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

enum TextInsertionRoute: String, Equatable {
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
        var focusedElementPID: pid_t = 0
        if let element { AXUIElementGetPid(element, &focusedElementPID) }

        // Browser controls can be owned by a renderer/helper process. The
        // visible frontmost application is still the destination that owns
        // keyboard routing and supplies the browser bundle identifier used by
        // the insertion policy.
        let destinationPID = TextTargetPlanner.destinationProcessIdentifier(
            frontmost: frontmostApplication?.processIdentifier,
            focusedElement: focusedElementPID
        )
        let application = destinationPID.flatMap(NSRunningApplication.init(processIdentifier:))

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
        if TextInsertionPolicy.preferredRoute(for: target.bundleIdentifier) == .accessibility,
           let element = target.element {
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

        let source = CGEventSource(stateID: .combinedSessionState)
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

        // Send the shortcut through the logged-in session's focused control.
        // Dia and other Chromium browsers keep their address bar in the main
        // process but website fields in renderer processes, so posting to one
        // PID only reaches some of their editable surfaces.
        keyDown.post(tap: .cgSessionEventTap)
        try await Task.sleep(nanoseconds: 10_000_000)
        keyUp.post(tap: .cgSessionEventTap)
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

enum TextTargetPlanner {
    static func destinationProcessIdentifier(
        frontmost: pid_t?,
        focusedElement: pid_t
    ) -> pid_t? {
        if let frontmost, frontmost > 0 { return frontmost }
        return focusedElement > 0 ? focusedElement : nil
    }
}

enum TextInsertionPolicy {
    private static let pastePreferredBundleIdentifiers: Set<String> = [
        // Web fields often expose writable Accessibility attributes without
        // dispatching the DOM input event expected by the page. A real paste
        // event is more reliable for search boxes, editors, and form controls.
        "com.apple.safari",
        "com.apple.safaritechnologypreview",
        "com.google.chrome",
        "com.google.chrome.beta",
        "com.google.chrome.canary",
        "org.chromium.chromium",
        "com.brave.browser",
        "com.brave.browser.beta",
        "com.brave.browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.beta",
        "com.microsoft.edgemac.dev",
        "com.microsoft.edgemac.canary",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "company.thebrowser.browser",
        "company.thebrowser.dia",
        "com.operasoftware.opera",
        "com.vivaldi.vivaldi",
        "com.duckduckgo.macos.browser",
        "com.kagi.kagimacos",
        "com.sigmaos.sigmaos.macos",

        // Hybrid editors and terminals also need a genuine key/paste event.
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.openai.codex",
        "com.microsoft.vscode",
        "com.microsoft.vscodeinsiders",
        "com.apple.dt.xcode",
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "dev.warp.warp",
        "dev.warp.warp-stable",
        "dev.zed.zed",
        "com.mitchellh.ghostty",
        "com.t3tools.t3code"
    ]

    private static let pastePreferredBundleIdentifierPrefixes = [
        "com.apple.webkit.",
        "com.google.chrome.",
        "com.brave.browser.",
        "com.microsoft.edgemac.",
        "org.mozilla.firefox.",
        "org.chromium.chromium.",
        "company.thebrowser."
    ]

    static func preferredRoute(for bundleIdentifier: String?) -> TextInsertionRoute {
        guard let bundleIdentifier = bundleIdentifier?.lowercased() else {
            return .accessibility
        }
        let prefersPaste = pastePreferredBundleIdentifiers.contains(bundleIdentifier)
            || pastePreferredBundleIdentifierPrefixes.contains {
                bundleIdentifier.hasPrefix($0)
            }
        return prefersPaste
            ? .pasteboard
            : .accessibility
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
