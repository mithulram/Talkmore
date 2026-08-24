import XCTest
@testable import Talkmore

final class DictationAccuracyTests: XCTestCase {
    func testBufferedStreamGatePreservesInitialAndLiveElementsInOrder() async {
        let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
        let gate = BufferedStreamGate(continuation: continuation)

        gate.yield(1)
        gate.yield(2)
        gate.open()
        gate.yield(3)
        gate.finish()

        var received: [Int] = []
        for await value in stream {
            received.append(value)
        }
        XCTAssertEqual(received, [1, 2, 3])
    }

    func testFinishingClosedGateFlushesBufferedElements() async {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let gate = BufferedStreamGate(continuation: continuation)

        gate.yield("first word")
        gate.finish()

        var received: [String] = []
        for await value in stream {
            received.append(value)
        }
        XCTAssertEqual(received, ["first word"])
    }

    func testSpeechContextTrimsAndDeduplicatesHints() {
        XCTAssertEqual(
            SpeechContextPlanner.normalized([
                "  OpenAI  ", "openai", "Mithul", "", "  ", "MITHUL", "SwiftUI"
            ]),
            ["OpenAI", "Mithul", "SwiftUI"]
        )
    }

    func testCompletedTranscriptWinsOverLessStableLiveText() {
        XCTAssertEqual(
            DictationTranscriptPlanner.bestAvailable(
                completed: "The finalized accurate transcript",
                live: "The final accurate trans"
            ),
            "The finalized accurate transcript"
        )
    }

    func testLiveTranscriptRemainsFallbackWithinLatencyBudget() {
        XCTAssertEqual(
            DictationTranscriptPlanner.bestAvailable(completed: nil, live: "Fast partial result"),
            "Fast partial result"
        )
        XCTAssertEqual(
            DictationTranscriptPlanner.bestAvailable(completed: "   ", live: "Fast partial result"),
            "Fast partial result"
        )
    }

    func testTrailingPartialResultDoesNotEndSettleWindowEarly() {
        XCTAssertFalse(
            DictationSettlePlanner.shouldFinishEarly(
                hasFinalResultAfterCapture: false,
                stableTicks: 8,
                elapsed: 0.30
            )
        )
    }

    func testStablePostCaptureFinalResultCanEndSettleWindowEarly() {
        XCTAssertFalse(
            DictationSettlePlanner.shouldFinishEarly(
                hasFinalResultAfterCapture: true,
                stableTicks: 2,
                elapsed: 0.12
            )
        )
        XCTAssertTrue(
            DictationSettlePlanner.shouldFinishEarly(
                hasFinalResultAfterCapture: true,
                stableTicks: 2,
                elapsed: 0.15
            )
        )
    }
}
