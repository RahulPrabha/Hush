import XCTest

final class PlaybackSessionPolicyTests: XCTestCase {
    func testInterruptionBeganPausesKeepingIntent() {
        XCTAssertEqual(
            PlaybackSessionPolicy.action(for: .began),
            .pauseKeepingIntent
        )
    }

    func testInterruptionEndedWithShouldResumeResumes() {
        XCTAssertEqual(
            PlaybackSessionPolicy.action(for: .ended(shouldResume: true)),
            .resumeIfIntended
        )
    }

    func testInterruptionEndedWithoutShouldResumeStaysPaused() {
        XCTAssertEqual(
            PlaybackSessionPolicy.action(for: .ended(shouldResume: false)),
            .none
        )
    }

    func testHeadphonesUnpluggedStops() {
        XCTAssertEqual(
            PlaybackSessionPolicy.action(for: .oldDeviceUnavailable),
            .stop
        )
    }

    func testOtherRouteChangesAreIgnored() {
        XCTAssertEqual(
            PlaybackSessionPolicy.action(for: .other),
            .none
        )
    }
}
