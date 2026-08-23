import XCTest
@testable import Talkmore

final class TextInsertionPlannerTests: XCTestCase {
    func testFrontmostApplicationWinsOverFocusedBrowserRenderer() {
        XCTAssertEqual(
            TextTargetPlanner.destinationProcessIdentifier(
                frontmost: 120,
                focusedElement: 987
            ),
            120
        )
    }

    func testFocusedElementProcessIsFallbackWhenNoFrontmostApplicationExists() {
        XCTAssertEqual(
            TextTargetPlanner.destinationProcessIdentifier(
                frontmost: nil,
                focusedElement: 987
            ),
            987
        )
        XCTAssertNil(
            TextTargetPlanner.destinationProcessIdentifier(
                frontmost: nil,
                focusedElement: 0
            )
        )
    }

    func testDevelopmentAppsPreferPaste() {
        XCTAssertEqual(
            TextInsertionPolicy.preferredRoute(for: "com.todesktop.230313mzl4w4u92"),
            .pasteboard
        )
        XCTAssertEqual(
            TextInsertionPolicy.preferredRoute(for: "com.openai.codex"),
            .pasteboard
        )
        XCTAssertEqual(
            TextInsertionPolicy.preferredRoute(for: "com.microsoft.VSCode"),
            .pasteboard
        )
        XCTAssertEqual(
            TextInsertionPolicy.preferredRoute(for: "com.apple.dt.Xcode"),
            .pasteboard
        )
    }

    func testNativeEditorsPreferAccessibility() {
        XCTAssertEqual(
            TextInsertionPolicy.preferredRoute(for: "com.apple.TextEdit"),
            .accessibility
        )
        XCTAssertEqual(TextInsertionPolicy.preferredRoute(for: nil), .accessibility)
    }

    func testWebBrowsersPreferPasteForWebsiteFields() {
        let browserBundleIdentifiers = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "company.thebrowser.Browser"
        ]

        for bundleIdentifier in browserBundleIdentifiers {
            XCTAssertEqual(
                TextInsertionPolicy.preferredRoute(for: bundleIdentifier),
                .pasteboard,
                "Expected website fields in \(bundleIdentifier) to use paste"
            )
        }
    }

    func testBrowserHelperProcessesAlsoPreferPaste() {
        let helperBundleIdentifiers = [
            "com.apple.WebKit.WebContent",
            "com.google.Chrome.helper.renderer",
            "com.brave.Browser.helper.renderer",
            "com.microsoft.edgemac.helper.renderer",
            "org.mozilla.firefox.helper",
            "org.chromium.Chromium.helper",
            "company.thebrowser.browser.helper.renderer"
        ]

        for bundleIdentifier in helperBundleIdentifiers {
            XCTAssertEqual(
                TextInsertionPolicy.preferredRoute(for: bundleIdentifier),
                .pasteboard,
                "Expected browser helper \(bundleIdentifier) to use paste"
            )
        }
    }

    func testReplacementRangeEndsAtCaret() {
        let range = TextInsertionPlanner.replacementRange(
            insertedUTF16Length: 12,
            caretLocation: 30
        )
        XCTAssertEqual(range?.location, 18)
        XCTAssertEqual(range?.length, 12)
    }

    func testReplacementRangeSupportsEmojiUTF16Length() {
        let text = "Hello 👋"
        let length = (text as NSString).length
        let range = TextInsertionPlanner.replacementRange(
            insertedUTF16Length: length,
            caretLocation: length
        )
        XCTAssertEqual(range?.location, 0)
        XCTAssertEqual(range?.length, length)
    }

    func testReplacementRangeRejectsCaretBeforeInsertedText() {
        XCTAssertNil(
            TextInsertionPlanner.replacementRange(
                insertedUTF16Length: 20,
                caretLocation: 10
            )
        )
    }
}
