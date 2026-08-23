import XCTest
@testable import Talkmore

final class FastTextCleanerTests: XCTestCase {
    func testRemovesCommonFillersAndCapitalizes() {
        XCTAssertEqual(
            FastTextCleaner.clean("um hello there, uh this is a test"),
            "Hello there, this is a test"
        )
    }

    func testPreservesTrailingWords() {
        let input = "please include every word at the end of this sentence"
        XCTAssertEqual(
            FastTextCleaner.clean(input),
            "Please include every word at the end of this sentence"
        )
    }

    func testDoesNotRemoveFillersInsideWords() {
        XCTAssertEqual(
            FastTextCleaner.clean("the umbrella belongs to Uma"),
            "The umbrella belongs to Uma"
        )
    }

    func testNormalizesSpacingBeforePunctuation() {
        XCTAssertEqual(
            FastTextCleaner.clean("hello   world , this works !"),
            "Hello world, this works!"
        )
    }
}
