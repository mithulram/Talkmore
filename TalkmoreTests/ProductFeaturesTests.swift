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

    func testExplicitIdeasBecomeANumberedList() {
        XCTAssertEqual(
            ConversationalStructureFormatter.format(
                "I have two ideas. First one is improve recognition, and second one is reduce latency."
            ),
            "I have two ideas:\n1. Improve recognition\n2. Reduce latency."
        )
    }

    func testOrdinalProseWithoutEnumerationIntentIsPreserved() {
        XCTAssertEqual(
            ConversationalStructureFormatter.format(
                "The first one is blue and the second one is green."
            ),
            "The first one is blue and the second one is green."
        )
    }

    func testDirectOrdinalSequenceBecomesANumberedList() {
        XCTAssertEqual(
            ConversationalStructureFormatter.format(
                "First: open Xcode. Second: run the tests. Third: publish the build."
            ),
            "1. Open Xcode.\n2. Run the tests.\n3. Publish the build."
        )
    }

    func testCorrectionDetectorExtractsEditedNameInsideDictation() {
        XCTAssertEqual(
            CorrectionCandidateDetector.candidate(
                before: "Message Fluid Voice today",
                after: "Message FluidVoice today",
                insertedRange: NSRange(location: 0, length: 25)
            ),
            LearnedCorrectionCandidate(heardText: "Fluid Voice", correctedText: "FluidVoice")
        )
    }

    func testCorrectionDetectorRejectsTypingOutsideInsertedText() {
        XCTAssertNil(
            CorrectionCandidateDetector.candidate(
                before: "Talkmore",
                after: "Talkmore is useful",
                insertedRange: NSRange(location: 0, length: 8)
            )
        )
    }

    func testAutomaticDictionaryRequiresRepeatedCorrectionEvidence() {
        XCTAssertFalse(CorrectionLearningPolicy.shouldLearn(occurrenceCount: 1))
        XCTAssertTrue(CorrectionLearningPolicy.shouldLearn(occurrenceCount: 2))
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
    func testPersonalDictionaryRefreshesCompiledReplacementsAfterChanges() {
        withIsolatedDefaults { defaults in
            let dictionary = PersonalDictionary(defaults: defaults)
            XCTAssertTrue(dictionary.add(spokenForm: "see plus plus", replacement: "C++"))
            XCTAssertEqual(dictionary.apply(to: "Use see plus plus today."), "Use C++ today.")

            XCTAssertTrue(dictionary.add(spokenForm: "see plus plus", replacement: "CXX"))
            XCTAssertEqual(dictionary.apply(to: "Use see plus plus today."), "Use CXX today.")

            guard let entry = dictionary.entries.first else {
                XCTFail("Expected a dictionary entry")
                return
            }
            dictionary.remove(id: entry.id)
            XCTAssertEqual(dictionary.apply(to: "Use see plus plus today."), "Use see plus plus today.")
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
            settings.showOverlay = false
            settings.overlayPlacement = .top
            settings.saveHistory = false

            let restored = ProductSettings(defaults: defaults)
            XCTAssertEqual(restored.writingStyle, .concise)
            XCTAssertEqual(restored.dictationLanguage, .englishUS)
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
