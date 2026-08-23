import XCTest
@testable import Talkmore

final class TextInsertionPlannerTests: XCTestCase {
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
