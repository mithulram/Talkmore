import XCTest
@testable import Talkmore

final class DeveloperModeTests: XCTestCase {
    func testRecognizesCursorByBundleIdentifier() {
        let context = WritingContext(
            applicationName: "Anything",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            developerModeEnabled: true
        )
        XCTAssertTrue(context.isDeveloperMode)
        XCTAssertFalse(context.speechHints.isEmpty)
    }

    func testRecognizesCommonDeveloperApps() {
        for bundle in ["com.apple.dt.Xcode", "com.apple.Terminal", "com.openai.codex"] {
            XCTAssertTrue(
                WritingContext(
                    applicationName: nil,
                    bundleIdentifier: bundle,
                    developerModeEnabled: true
                ).isDeveloperMode,
                "Expected developer mode for \(bundle)"
            )
        }
    }

    func testDoesNotEnableForRegularWritingApps() {
        for bundle in ["com.apple.Safari", "com.apple.Notes"] {
            XCTAssertFalse(
                WritingContext(
                    applicationName: nil,
                    bundleIdentifier: bundle,
                    developerModeEnabled: true
                ).isDeveloperMode
            )
        }
    }

    func testGlobalToggleCanDisableDeveloperMode() {
        let context = WritingContext(
            applicationName: "Cursor",
            bundleIdentifier: nil,
            developerModeEnabled: false
        )
        XCTAssertFalse(context.isDeveloperMode)
    }

    func testNormalizesTechnologySpellings() {
        XCTAssertEqual(
            DeveloperTextProcessor.process("use swift u i with type script and node j s"),
            "use SwiftUI with TypeScript and Node.js"
        )
    }

    func testNormalizesKnownAndGenericFilenames() {
        XCTAssertEqual(
            DeveloperTextProcessor.process("update read me dot md and server dot swift"),
            "update README.md and server.swift"
        )
    }

    func testWholeUtteranceCaseCommands() {
        XCTAssertEqual(DeveloperTextProcessor.process("camel case user profile"), "userProfile")
        XCTAssertEqual(DeveloperTextProcessor.process("snake case user profile"), "user_profile")
        XCTAssertEqual(DeveloperTextProcessor.process("Pascal case user profile"), "UserProfile")
    }

    func testDelimitedCaseCommandPreservesSurroundingText() {
        XCTAssertEqual(
            DeveloperTextProcessor.process("rename it to camel case user profile end case please"),
            "rename it to userProfile please"
        )
    }

    func testFormattingAndSymbolCommands() {
        XCTAssertEqual(
            DeveloperTextProcessor.process(
                "call open parenthesis user underscore id close parenthesis semicolon new line return user underscore id"
            ),
            "call(user_id);\nreturn user_id"
        )
    }

    func testStandardContextLeavesTextUntouched() {
        XCTAssertEqual(
            WritingContext.standard.process("camel case user profile new line"),
            "camel case user profile new line"
        )
    }
}
