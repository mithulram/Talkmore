import XCTest
@testable import Talkmore

final class TextInsertionPlannerTests: XCTestCase {
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
