import XCTest
@testable import Talkmore

final class DictationStateTests: XCTestCase {
    func testIdleAndErrorAreNotBusy() {
        XCTAssertFalse(DictationState.idle.isBusy)
        XCTAssertFalse(DictationState.error("test").isBusy)
    }

    func testActivePipelineStatesAreBusy() {
        XCTAssertTrue(DictationState.preparing.isBusy)
        XCTAssertTrue(DictationState.recording.isBusy)
        XCTAssertTrue(DictationState.finalizing.isBusy)
        XCTAssertTrue(DictationState.refining.isBusy)
        XCTAssertTrue(DictationState.inserting.isBusy)
    }
}
