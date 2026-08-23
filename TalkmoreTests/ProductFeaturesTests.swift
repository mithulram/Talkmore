import XCTest
@testable import Talkmore

final class ProductFeaturesTests: XCTestCase {
    func testAutomaticStyleUsesEmailModeInMail() {
        let context = WritingContext(
            applicationName: "Mail",
            bundleIdentifier: "com.apple.mail",
            developerModeEnabled: true
        )

        XCTAssertEqual(context.resolvedStyle, .email)
        XCTAssertTrue(context.isEmailMode)
        XCTAssertFalse(context.isDeveloperMode)
    }

    func testAutomaticStyleUsesDeveloperModeInCursor() {
        let context = WritingContext(
            applicationName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            developerModeEnabled: true
        )

        XCTAssertEqual(context.resolvedStyle, .developer)
        XCTAssertTrue(context.isDeveloperMode)
    }

    func testExplicitStyleOverridesApplicationDetection() {
        let context = WritingContext(
            applicationName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            developerModeEnabled: true,
            preferredStyle: .email
        )

        XCTAssertEqual(context.resolvedStyle, .email)
        XCTAssertTrue(context.isEmailMode)
    }

    func testDeveloperStyleFallsBackWhenDeveloperModeIsOff() {
        let context = WritingContext(
            applicationName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            developerModeEnabled: false,
            preferredStyle: .developer
        )

        XCTAssertEqual(context.resolvedStyle, .everyday)
    }

    func testVerbatimPreprocessingOnlyTrimsOuterWhitespace() {
        let context = WritingContext(
            applicationName: nil,
            bundleIdentifier: nil,
            developerModeEnabled: false,
            preferredStyle: .verbatim
        )

        XCTAssertEqual(context.preprocess("  Um I mean this  "), "Um I mean this")
    }

    func testEmailProcessorCreatesSubjectParagraphsAndPunctuation() {
        XCTAssertEqual(
            EmailTextProcessor.process(
                "subject line project update new paragraph hi alex comma new paragraph everything is ready period"
            ),
            "Subject: project update\n\nHi alex,\n\nEverything is ready."
        )
    }

    @MainActor
    func testPersonalDictionaryReplacesWholePhrasesAndPersists() {
        withIsolatedDefaults { defaults in
            let dictionary = PersonalDictionary(defaults: defaults)
            XCTAssertTrue(dictionary.add(spokenForm: "open ai", replacement: "OpenAI"))
            XCTAssertTrue(dictionary.add(spokenForm: "my tool", replacement: "MyTool"))
            XCTAssertEqual(
                dictionary.apply(to: "Use open ai in my tool, not unopened ai."),
                "Use OpenAI in MyTool, not unopened ai."
            )

            let restored = PersonalDictionary(defaults: defaults)
            XCTAssertEqual(restored.entries.count, 2)
            XCTAssertTrue(restored.speechHints.contains("OpenAI"))
        }
    }

    @MainActor
    func testHistoryIsNewestFirstPersistsAndKeepsFiftyItems() {
        withIsolatedDefaults { defaults in
            let history = DictationHistory(defaults: defaults)
            for index in 0..<55 {
                history.record(
                    text: "Dictation \(index)",
                    applicationName: "TextEdit",
                    writingStyle: .everyday,
                    route: .accessibility,
                    visibleLatency: 0.2
                )
            }

            XCTAssertEqual(history.items.count, 50)
            XCTAssertEqual(history.items.first?.text, "Dictation 54")
            XCTAssertEqual(history.items.last?.text, "Dictation 5")

            let restored = DictationHistory(defaults: defaults)
            XCTAssertEqual(restored.items, history.items)
            restored.clear()
            XCTAssertTrue(restored.items.isEmpty)
        }
    }

    @MainActor
    func testProductSettingsPersistCustomization() {
        withIsolatedDefaults { defaults in
            let settings = ProductSettings(defaults: defaults)
            settings.writingStyle = .concise
            settings.dictationLanguage = .german
            settings.showOverlay = false
            settings.overlayPlacement = .top
            settings.saveHistory = false

            let restored = ProductSettings(defaults: defaults)
            XCTAssertEqual(restored.writingStyle, .concise)
            XCTAssertEqual(restored.dictationLanguage, .german)
            XCTAssertFalse(restored.showOverlay)
            XCTAssertEqual(restored.overlayPlacement, .top)
            XCTAssertFalse(restored.saveHistory)
        }
    }

    @MainActor
    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "TalkmoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
