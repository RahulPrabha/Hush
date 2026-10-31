import XCTest

final class FakeEngine: PlaybackControlling {
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

/// Shared scratch space: a throwaway UserDefaults suite and channel folder.
class RemoteControlTestCase: XCTestCase {
    var defaults: UserDefaults!
    var suiteName: String!
    var directory: URL!
    var channel: CommandChannel!
    var engine: FakeEngine!

    override func setUpWithError() throws {
        suiteName = "HushTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HushTests-\(UUID().uuidString)", isDirectory: true)
        channel = CommandChannel(directory: directory)
        engine = FakeEngine()
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }

    func state(playing: Bool, sound: String = "brown", volume: Int = 50) -> PlaybackSnapshot {
        PlaybackSnapshot(playing: playing, sound: sound, volume: volume)
    }

    /// Runs the main run loop until `condition` holds, so dispatch sources on
    /// the main queue can fire.
    func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}

final class RemoteControlHandlerTests: RemoteControlTestCase {
    private var handler: RemoteControlHandler!

    override func setUpWithError() throws {
        try super.setUpWithError()
        handler = RemoteControlHandler(engine: engine, defaults: defaults)
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
}

final class CommandChannelTests: RemoteControlTestCase {
    private func writeRaw(_ text: String, named name: String, age: TimeInterval = 0) throws {
        try FileManager.default.createDirectory(at: channel.commandsDirectory, withIntermediateDirectories: true)
        let url = channel.commandsDirectory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        if age > 0 {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: -age)],
                ofItemAtPath: url.path
            )
        }
    }

    func testSubmittedCommandIsTakenOnce() throws {
        try channel.submit(.play(.speechBlocker), token: "TOKEN-0001")
        let pending = channel.takePendingCommands()
        XCTAssertEqual(pending.map(\.token), ["TOKEN-0001"])
        XCTAssertEqual(try pending[0].command.get(), .play(.speechBlocker))
        XCTAssertTrue(channel.takePendingCommands().isEmpty, "a command is consumed when it is taken")
    }

    func testCommandsComeOutOldestFirst() throws {
        try channel.submit(.stop, token: "TOKEN-NEW1")
        try channel.submit(.toggle, token: "TOKEN-OLD1")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -5)],
            ofItemAtPath: channel.commandsDirectory.appendingPathComponent("TOKEN-OLD1.json").path
        )
        XCTAssertEqual(channel.takePendingCommands().map(\.token), ["TOKEN-OLD1", "TOKEN-NEW1"])
    }

    func testStaleCommandsAreDroppedUnread() throws {
        try writeRaw(#"{"command":"play"}"#, named: "TOKEN-OLD1.json", age: CommandChannel.commandLifetime + 5)
        XCTAssertTrue(channel.takePendingCommands().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: channel.commandsDirectory.appendingPathComponent("TOKEN-OLD1.json").path))
    }

    func testUnusableFileNamesAreDiscarded() throws {
        try writeRaw(#"{"command":"play"}"#, named: "x.json")                 // token too short
        try writeRaw(#"{"command":"play"}"#, named: "has space 123.json")
        try writeRaw(#"{"command":"play"}"#, named: "TOKEN-0001.txt")         // not a command file
        XCTAssertTrue(channel.takePendingCommands().isEmpty)
    }

    func testUnreadableCommandIsReportedWithItsToken() throws {
        try writeRaw(#"{"command":"explode"}"#, named: "TOKEN-0001.json")
        try writeRaw("garbage", named: "TOKEN-0002.json")
        let pending = channel.takePendingCommands()
        XCTAssertEqual(pending.count, 2)
        for entry in pending {
            XCTAssertThrowsError(try entry.command.get())
        }
    }

    func testWithdrawRemovesAnUntakenCommand() throws {
        try channel.submit(.stop, token: "TOKEN-0001")
        XCTAssertTrue(channel.withdraw(token: "TOKEN-0001"))
        XCTAssertTrue(channel.takePendingCommands().isEmpty)
        XCTAssertFalse(channel.withdraw(token: "TOKEN-0001"), "nothing left to withdraw")
    }

    func testReplyIsCollectedOnce() throws {
        let response = RemoteResponse.success(state(playing: true))
        try channel.writeReply(response, token: "TOKEN-0001")
        XCTAssertEqual(channel.takeReply(token: "TOKEN-0001"), response)
        XCTAssertNil(channel.takeReply(token: "TOKEN-0001"))
    }

    func testTokensCannotEscapeTheChannel() throws {
        XCTAssertFalse(CommandChannel.isValid(token: "../../etc/passwd"))
        XCTAssertFalse(CommandChannel.isValid(token: "abc"))
        XCTAssertFalse(CommandChannel.isValid(token: String(repeating: "a", count: 65)))
        XCTAssertFalse(CommandChannel.isValid(token: "has space 1234"))
        XCTAssertTrue(CommandChannel.isValid(token: CommandChannel.makeToken()))

        try channel.submit(.stop, token: "../../escape-token")
        try channel.writeReply(.success(state(playing: false)), token: "../../escape-token")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing is written for a bad token")
        XCTAssertNil(channel.takeReply(token: "../../escape-token"))
    }

    func testTakeReplyIgnoresUnreadableAndMissingFiles() throws {
        try FileManager.default.createDirectory(at: channel.repliesDirectory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: channel.repliesDirectory.appendingPathComponent("GARBAGE-TOKEN.json"))
        XCTAssertNil(channel.takeReply(token: "GARBAGE-TOKEN"))
        XCTAssertNil(channel.takeReply(token: "MISSING-TOKEN"))
    }

    func testRemovesStaleRepliesOnly() throws {
        try channel.writeReply(.success(state(playing: false)), token: "OLD-TOKEN-01")
        try channel.writeReply(.success(state(playing: false)), token: "NEW-TOKEN-01")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -120)],
            ofItemAtPath: channel.repliesDirectory.appendingPathComponent("OLD-TOKEN-01.json").path
        )

        channel.removeStaleReplies(olderThan: 60)

        XCTAssertNil(channel.takeReply(token: "OLD-TOKEN-01"))
        XCTAssertNotNil(channel.takeReply(token: "NEW-TOKEN-01"))
    }
}

/// The app side end to end: a real folder watcher on the main queue, the way
/// `hush` and the running app use it.
final class RemoteControlServerTests: RemoteControlTestCase {
    private var server: RemoteControlServer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        server = RemoteControlServer(engine: engine, channel: channel, defaults: defaults, queue: .main)
    }

    override func tearDownWithError() throws {
        server = nil
        try super.tearDownWithError()
    }

    private func awaitReply(_ token: String) -> RemoteResponse? {
        var reply: RemoteResponse?
        _ = waitUntil {
            reply = reply ?? channel.takeReply(token: token)
            return reply != nil
        }
        return reply
    }

    func testRunsACommandThatArrivesWhileRunning() throws {
        server.start()
        try channel.submit(.play(.speechBlocker), token: "TOKEN-0001")

        let reply = try XCTUnwrap(awaitReply("TOKEN-0001"), "the server never answered")
        XCTAssertEqual(reply, .success(state(playing: true, sound: "speech-blocker")))
        XCTAssertTrue(engine.isPlaying)
    }

    func testRunsACommandThatWasWaitingWhenTheAppStarted() throws {
        // `hush` writes its command before it launches the app.
        try channel.submit(.setVolume(30), token: "TOKEN-0001")
        XCTAssertEqual(engine.volume, 0.5)

        server.start()

        XCTAssertEqual(awaitReply("TOKEN-0001"), .success(state(playing: false, volume: 30)))
        XCTAssertEqual(engine.volume, 0.3, accuracy: 0.0001)
    }

    func testRunsCommandsInTheOrderTheyWereWritten() throws {
        server.start()
        try channel.submit(.play(nil), token: "TOKEN-0001")
        XCTAssertNotNil(awaitReply("TOKEN-0001"))
        try channel.submit(.stop, token: "TOKEN-0002")
        XCTAssertEqual(awaitReply("TOKEN-0002"), .success(state(playing: false)))
    }

    func testReportsACommandItCannotUnderstand() throws {
        server.start()
        try FileManager.default.createDirectory(at: channel.commandsDirectory, withIntermediateDirectories: true)
        try Data(#"{"command":"play","sound":"white"}"#.utf8)
            .write(to: channel.commandsDirectory.appendingPathComponent("TOKEN-0001.json"))

        let reply = try XCTUnwrap(awaitReply("TOKEN-0001"))
        XCTAssertFalse(reply.ok)
        XCTAssertTrue(reply.error?.contains("Unknown sound 'white'") ?? false)
        XCTAssertFalse(engine.isPlaying)
    }

    func testReportsAnEngineThatCannotStart() throws {
        engine.startFails = true
        server.start()
        try channel.submit(.play(nil), token: "TOKEN-0001")

        let reply = try XCTUnwrap(awaitReply("TOKEN-0001"))
        XCTAssertFalse(reply.ok)
        XCTAssertEqual(reply.error, "Hush couldn't start audio output.")
    }

    func testKeepsListeningAfterTheFolderIsReplaced() throws {
        server.start()
        try channel.submit(.play(nil), token: "TOKEN-0001")
        XCTAssertNotNil(awaitReply("TOKEN-0001"))

        // The system can clear temporary files while the app runs.
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: channel.commandsDirectory, withIntermediateDirectories: true)
        // Give the watcher a moment to notice and re-arm.
        _ = waitUntil(0.3) { false }

        try channel.submit(.stop, token: "TOKEN-0002")
        XCTAssertEqual(awaitReply("TOKEN-0002"), .success(state(playing: false)))
    }

    func testIgnoresCommandsPastTheirLifetime() throws {
        server.start()
        try FileManager.default.createDirectory(at: channel.commandsDirectory, withIntermediateDirectories: true)
        let url = channel.commandsDirectory.appendingPathComponent("TOKEN-0001.json")
        try Data(#"{"command":"play"}"#.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -(CommandChannel.commandLifetime + 5))],
            ofItemAtPath: url.path
        )

        XCTAssertTrue(waitUntil { !FileManager.default.fileExists(atPath: url.path) })
        XCTAssertFalse(engine.isPlaying)
        XCTAssertNil(channel.takeReply(token: "TOKEN-0001"))
    }
}
