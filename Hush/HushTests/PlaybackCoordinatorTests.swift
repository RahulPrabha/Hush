import XCTest

private final class FakeBackend: PlaybackBackend {
    var isRunning = false
    var startError: Error?
    private(set) var startCalls = 0
    private(set) var stopCalls = 0

    func start() throws {
        startCalls += 1
        if let startError { throw startError }
        isRunning = true
    }

    func stop() {
        stopCalls += 1
        isRunning = false
    }
}

private struct StartFailure: Error {}

/// Runs delayed work only when the test says time has passed.
private final class ManualClock {
    private var pending: [() -> Void] = []

    func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        pending.append(work)
    }

    func fireAll() {
        let work = pending
        pending = []
        work.forEach { $0() }
    }
}

final class PlaybackCoordinatorTests: XCTestCase {
    private var backend: FakeBackend!
    private var clock: ManualClock!
    private var coordinator: PlaybackCoordinator!
    private var changes: [Bool] = []

    override func setUp() {
        super.setUp()
        backend = FakeBackend()
        clock = ManualClock()
        changes = []
        coordinator = PlaybackCoordinator(backend: backend, schedule: clock.schedule)
        coordinator.onChange = { [unowned self] in changes.append($0) }
    }

    /// The icon follows `isPlaying`; it must agree with the real output.
    private func assertIconMatchesOutput(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(coordinator.isPlaying, backend.isRunning, message, file: file, line: line)
    }

    func testToggleStartsAndStopsOutput() {
        coordinator.toggle()
        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertTrue(backend.isRunning)

        coordinator.toggle()
        XCTAssertFalse(coordinator.isPlaying)
        clock.fireAll()
        XCTAssertFalse(backend.isRunning)
        assertIconMatchesOutput()
    }

    func testStopKeepsOutputRunningUntilFadeOutFinishes() {
        coordinator.play()
        coordinator.stop()
        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertTrue(backend.isRunning, "output keeps running while it fades out")

        clock.fireAll()
        XCTAssertFalse(backend.isRunning)
    }

    /// Right-clicking the menu bar icon three times quickly: the second click's
    /// fade-out teardown used to fire after the third click had started the
    /// output again, leaving the icon "playing" with no audio.
    func testPlayDuringFadeOutIsNotKilledByPendingTeardown() {
        coordinator.toggle()   // click 1: play
        coordinator.toggle()   // click 2: stop, teardown pending
        coordinator.toggle()   // click 3: play again before the teardown fires
        clock.fireAll()        // the teardown from click 2 comes due

        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertTrue(backend.isRunning, "the stale teardown stopped the restarted output")
        assertIconMatchesOutput()
    }

    func testPlayDuringFadeOutReusesRunningOutput() {
        coordinator.play()
        coordinator.stop()
        coordinator.play()
        XCTAssertEqual(backend.startCalls, 1)
        XCTAssertEqual(backend.stopCalls, 0)
    }

    func testStopAfterQuickPlayStillTearsDownOutput() {
        coordinator.toggle()
        coordinator.toggle()
        coordinator.toggle()
        coordinator.toggle()   // 4th click: stop again
        clock.fireAll()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertFalse(backend.isRunning)
        assertIconMatchesOutput()
    }

    func testIconMatchesOutputForEveryRapidClickSequence() {
        // Every sequence of up to 6 clicks, with the pending teardowns firing
        // after the last click.
        for length in 1...6 {
            for pattern in 0..<(1 << length) {
                setUp()
                for bit in 0..<length {
                    if pattern & (1 << bit) != 0 { clock.fireAll() }   // a gap long enough for teardowns
                    coordinator.toggle()
                }
                clock.fireAll()
                assertIconMatchesOutput("click gaps pattern \(pattern) of length \(length)")
                XCTAssertEqual(coordinator.isPlaying, length % 2 == 1, "pattern \(pattern) of length \(length)")
            }
        }
    }

    func testFailedStartLeavesIconStoppedAndNextClickRetries() {
        backend.startError = StartFailure()
        coordinator.toggle()
        XCTAssertFalse(coordinator.isPlaying)
        assertIconMatchesOutput()

        backend.startError = nil
        coordinator.toggle()
        XCTAssertTrue(coordinator.isPlaying)
        assertIconMatchesOutput()
    }

    func testRestartRebuildsOutputAndKeepsPlaying() {
        coordinator.play()
        coordinator.restart()
        XCTAssertTrue(coordinator.isPlaying, "restarting is not a stop")
        XCTAssertFalse(backend.isRunning)

        clock.fireAll()
        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertTrue(backend.isRunning)
        XCTAssertEqual(backend.startCalls, 2)
    }

    func testRestartThatFailsToStartReportsStopped() {
        coordinator.play()
        coordinator.restart()
        backend.startError = StartFailure()
        clock.fireAll()

        XCTAssertFalse(coordinator.isPlaying)
        assertIconMatchesOutput()
    }

    func testStopDuringRestartCancelsTheRestart() {
        coordinator.play()
        coordinator.restart()
        coordinator.stop()
        clock.fireAll()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertFalse(backend.isRunning)
    }

    func testRestartIsIgnoredWhenNotPlaying() {
        coordinator.restart()
        clock.fireAll()
        XCTAssertFalse(backend.isRunning)
        XCTAssertEqual(backend.startCalls, 0)
    }

    func testSuspendSilencesOutputAndResumeRestoresIt() {
        coordinator.play()
        coordinator.suspend()
        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertFalse(backend.isRunning)

        coordinator.resumeIfIntended()
        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertTrue(backend.isRunning)
    }

    func testResumeDoesNothingAfterUserStop() {
        coordinator.play()
        coordinator.stop()
        clock.fireAll()
        coordinator.resumeIfIntended()
        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertFalse(backend.isRunning)
    }

    func testOnChangeReportsOnlyRealTransitions() {
        coordinator.play()
        coordinator.play()
        coordinator.stop()
        coordinator.stop()
        XCTAssertEqual(changes, [true, false])
    }
}
