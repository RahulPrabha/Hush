import XCTest

private final class FakeEngine: PlaybackControlling {
    var isPlaying = false
    var volume: Float = 0.5
    var noiseType: NoiseType = .brown {
        didSet { noiseTypeAssignments += 1 }
    }
    /// When set, `play()` leaves the engine stopped, like a missing output device.
    var startFails = false
    private(set) var noiseTypeAssignments = 0
    private(set) var playCalls = 0
    private(set) var stopCalls = 0

    func play() {
        playCalls += 1
        if !startFails { isPlaying = true }
    }

    func stop() {
        stopCalls += 1
        isPlaying = false
    }

    func toggle() {
        if isPlaying { stop() } else { play() }
    }
}

final class RemoteControlTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var directory: URL!
    private var engine: FakeEngine!
    private var handler: RemoteControlHandler!

    override func setUpWithError() throws {
        suiteName = "HushTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HushTests-\(UUID().uuidString)", isDirectory: true)
        engine = FakeEngine()
        handler = RemoteControlHandler(
            engine: engine,
            defaults: defaults,
            mailbox: ReplyMailbox(directory: directory)
        )
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }

    private func state(playing: Bool, sound: String = "brown", volume: Int = 50) -> PlaybackSnapshot {
        PlaybackSnapshot(playing: playing, sound: sound, volume: volume)
    }

    // MARK: Commands

    func testPlayStartsPlayback() {
        XCTAssertEqual(handler.perform(.play(nil)), .success(state(playing: true)))
        XCTAssertTrue(engine.isPlaying)
    }

    func testPlayWithSoundSwitchesSound() {
        let response = handler.perform(.play(.speechBlocker))
        XCTAssertEqual(response, .success(state(playing: true, sound: "speech-blocker")))
        XCTAssertEqual(engine.noiseType, .speechBlocker)
    }

    func testPlayWithSoundWhilePlayingSwitchesAndKeepsPlaying() {
        _ = handler.perform(.play(.brown))
        let response = handler.perform(.play(.speechBlocker))
        XCTAssertEqual(response, .success(state(playing: true, sound: "speech-blocker")))
    }

    func testPlayWithTheCurrentSoundLeavesTheGeneratorAlone() {
        _ = handler.perform(.play(.brown))
        // Assigning the same sound would reset the noise generator mid-playback.
        XCTAssertEqual(engine.noiseTypeAssignments, 0)
    }

    func testPlayIsIdempotentFromTheCallersPointOfView() {
        _ = handler.perform(.play(nil))
        XCTAssertEqual(handler.perform(.play(nil)), .success(state(playing: true)))
    }

    func testStopStopsPlayback() {
        _ = handler.perform(.play(nil))
        XCTAssertEqual(handler.perform(.stop), .success(state(playing: false)))
        XCTAssertFalse(engine.isPlaying)
    }

    func testStopWhenAlreadyStoppedSucceeds() {
        XCTAssertEqual(handler.perform(.stop), .success(state(playing: false)))
    }

    func testToggleFlipsPlayback() {
        XCTAssertEqual(handler.perform(.toggle), .success(state(playing: true)))
        XCTAssertEqual(handler.perform(.toggle), .success(state(playing: false)))
    }

    func testStatusReportsWithoutChangingAnything() {
        engine.noiseType = .speechBlocker
        engine.volume = 0.25
        let before = (engine.playCalls, engine.stopCalls)
        XCTAssertEqual(
            handler.perform(.status),
            .success(state(playing: false, sound: "speech-blocker", volume: 25))
        )
        XCTAssertEqual(engine.playCalls, before.0)
        XCTAssertEqual(engine.stopCalls, before.1)
    }

    func testSetVolumeAppliesPercentAsGain() {
        let response = handler.perform(.setVolume(35))
        XCTAssertEqual(response, .success(state(playing: false, volume: 35)))
        XCTAssertEqual(engine.volume, 0.35, accuracy: 0.0001)
    }

    func testSetVolumeBoundaries() {
        XCTAssertEqual(handler.perform(.setVolume(0)).state?.volume, 0)
        XCTAssertEqual(handler.perform(.setVolume(100)).state?.volume, 100)
        XCTAssertEqual(engine.volume, 1, accuracy: 0.0001)
    }

    // MARK: Failure

    func testPlayThatCannotStartReportsFailureWithState() {
        engine.startFails = true
        let response = handler.perform(.play(nil))
        XCTAssertFalse(response.ok)
        XCTAssertEqual(response.error, "Hush couldn't start audio output.")
        XCTAssertEqual(response.state, state(playing: false))
    }

    func testToggleThatCannotStartReportsFailure() {
        engine.startFails = true
        XCTAssertFalse(handler.perform(.toggle).ok)
    }

    func testToggleThatStopsNeverFails() {
        _ = handler.perform(.play(nil))
        engine.startFails = true
        XCTAssertTrue(handler.perform(.toggle).ok)
    }

    // MARK: Persistence

    func testSoundAndVolumeAreSavedForTheNextLaunch() {
        _ = handler.perform(.play(.speechBlocker))
        _ = handler.perform(.setVolume(20))
        XCTAssertEqual(defaults.string(forKey: HushSettings.noiseTypeKey), "Speech Blocker")
        XCTAssertEqual(defaults.double(forKey: HushSettings.volumeKey), 0.2, accuracy: 0.0001)
    }

    func testSettingsKeysMatchThePopoversAppStorage() throws {
        // ContentView.swift can't reference HushSettings (the App Store panel
        // renderer compiles it alone), so pin the literals it uses.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()           // HushTests
            .deletingLastPathComponent()           // Hush (project folder)
            .appendingPathComponent("Hush/ContentView.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        XCTAssertTrue(text.contains("@AppStorage(\"\(HushSettings.noiseTypeKey)\")"))
        XCTAssertTrue(text.contains("@AppStorage(\"\(HushSettings.volumeKey)\")"))
    }

    func testRestoreAppliesSavedSettings() {
        defaults.set("Speech Blocker", forKey: HushSettings.noiseTypeKey)
        defaults.set(0.8, forKey: HushSettings.volumeKey)
        HushSettings.restore(into: engine, from: defaults)
        XCTAssertEqual(engine.noiseType, .speechBlocker)
        XCTAssertEqual(engine.volume, 0.8, accuracy: 0.0001)
    }

    func testRestoreWithNothingSavedKeepsDefaults() {
        HushSettings.restore(into: engine, from: defaults)
        XCTAssertEqual(engine.noiseType, .brown)
        XCTAssertEqual(engine.volume, 0.5)
        XCTAssertEqual(engine.noiseTypeAssignments, 0)
    }

    func testRestoreIgnoresRemovedSoundsAndClampsVolume() {
        defaults.set("White", forKey: HushSettings.noiseTypeKey)
        defaults.set(7.0, forKey: HushSettings.volumeKey)
        HushSettings.restore(into: engine, from: defaults)
        XCTAssertEqual(engine.noiseType, .brown)
        XCTAssertEqual(engine.volume, 1)
    }

    // MARK: URLs and replies

    func testHandleURLRunsTheCommandAndLeavesAReply() throws {
        let token = "REPLY-TOKEN-1"
        let response = handler.handle(url: RemoteCommand.play(.speechBlocker).url(replyToken: token))
        XCTAssertEqual(response, .success(state(playing: true, sound: "speech-blocker")))
        let mailbox = ReplyMailbox(directory: directory)
        XCTAssertEqual(mailbox.take(token: token), response)
        XCTAssertNil(mailbox.take(token: token), "a reply is collected once")
    }

    func testHandleURLWithoutAReplyTokenWritesNothing() {
        handler.handle(url: RemoteCommand.toggle.url())
        XCTAssertTrue(engine.isPlaying)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testBadURLReportsTheProblemAndLeavesEngineAlone() {
        let token = "REPLY-TOKEN-2"
        let response = handler.handle(url: URL(string: "hush://play?sound=white&reply=\(token)")!)
        XCTAssertFalse(response.ok)
        XCTAssertTrue(response.error?.contains("Unknown sound 'white'") ?? false)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(ReplyMailbox(directory: directory).take(token: token), response)
    }

    func testReplyTokensCannotEscapeTheMailbox() {
        XCTAssertFalse(ReplyMailbox.isValid(token: "../../etc/passwd"))
        XCTAssertFalse(ReplyMailbox.isValid(token: "abc"))              // too short
        XCTAssertFalse(ReplyMailbox.isValid(token: String(repeating: "a", count: 65)))
        XCTAssertFalse(ReplyMailbox.isValid(token: "has space 1234"))
        XCTAssertTrue(ReplyMailbox.isValid(token: ReplyMailbox.makeToken()))

        let response = handler.handle(url: URL(string: "hush://stop?reply=../../escape")!)
        XCTAssertTrue(response.ok, "the command still runs")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "but no reply is written")
    }

    func testMailboxTakeIgnoresUnreadableFiles() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("GARBAGE-TOKEN.json"))
        XCTAssertNil(ReplyMailbox(directory: directory).take(token: "GARBAGE-TOKEN"))
        XCTAssertNil(ReplyMailbox(directory: directory).take(token: "MISSING-TOKEN"))
    }

    func testMailboxRemovesStaleRepliesOnly() throws {
        let mailbox = ReplyMailbox(directory: directory)
        try mailbox.write(.success(state(playing: false)), token: "OLD-TOKEN-01")
        try mailbox.write(.success(state(playing: false)), token: "NEW-TOKEN-01")
        let old = directory.appendingPathComponent("OLD-TOKEN-01.json")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -120)],
            ofItemAtPath: old.path
        )

        mailbox.removeStale(olderThan: 60)

        XCTAssertNil(mailbox.take(token: "OLD-TOKEN-01"))
        XCTAssertNotNil(mailbox.take(token: "NEW-TOKEN-01"))
    }
}
