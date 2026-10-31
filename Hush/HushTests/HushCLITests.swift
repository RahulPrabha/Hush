import XCTest

private final class FakeTransport: RemoteTransport {
    var outcome: TransportOutcome
    private(set) var sent: [RemoteCommand] = []

    init(_ outcome: TransportOutcome) {
        self.outcome = outcome
    }

    func send(_ command: RemoteCommand) -> TransportOutcome {
        sent.append(command)
        return outcome
    }
}

private func success(playing: Bool, sound: String = "brown", volume: Int = 50) -> TransportOutcome {
    .response(.success(PlaybackSnapshot(playing: playing, sound: sound, volume: volume)))
}

final class HushCLIParserTests: XCTestCase {
    private func parse(_ arguments: String...) -> Result<CLIAction, CLIUsageError> {
        CLIParser.parse(arguments)
    }

    private func action(_ arguments: String..., file: StaticString = #filePath, line: UInt = #line) -> CLIAction? {
        switch CLIParser.parse(arguments) {
        case .success(let action): return action
        case .failure(let error):
            XCTFail("unexpected usage error: \(error.message)", file: file, line: line)
            return nil
        }
    }

    private func usageError(_ arguments: String..., file: StaticString = #filePath, line: UInt = #line) -> String? {
        switch CLIParser.parse(arguments) {
        case .success(let action):
            XCTFail("expected a usage error, got \(action)", file: file, line: line)
            return nil
        case .failure(let error):
            return error.message
        }
    }

    func testSimpleCommands() {
        XCTAssertEqual(action("stop"), .remote(.stop, json: false))
        XCTAssertEqual(action("toggle"), .remote(.toggle, json: false))
        XCTAssertEqual(action("status"), .remote(.status, json: false))
        XCTAssertEqual(action("sounds"), .sounds(json: false))
    }

    func testCommandsAreCaseInsensitive() {
        XCTAssertEqual(action("STOP"), .remote(.stop, json: false))
    }

    func testPlay() {
        XCTAssertEqual(action("play"), .remote(.play(nil), json: false))
        XCTAssertEqual(action("play", "brown"), .remote(.play(.brown), json: false))
        XCTAssertEqual(action("play", "speech"), .remote(.play(.speechBlocker), json: false))
        XCTAssertEqual(action("play", "Speech Blocker"), .remote(.play(.speechBlocker), json: false))
    }

    func testPlayRejectsUnknownSoundAndNamesTheChoices() {
        let message = usageError("play", "white")
        XCTAssertTrue(message?.contains("unknown sound 'white'") ?? false)
        XCTAssertTrue(message?.contains("brown, speech-blocker") ?? false)
    }

    func testPlayRejectsExtraOperands() {
        XCTAssertNotNil(usageError("play", "brown", "speech-blocker"))
    }

    func testVolume() {
        XCTAssertEqual(action("volume", "0"), .remote(.setVolume(0), json: false))
        XCTAssertEqual(action("volume", "42"), .remote(.setVolume(42), json: false))
        XCTAssertEqual(action("volume", "100"), .remote(.setVolume(100), json: false))
        XCTAssertEqual(action("volume", "35%"), .remote(.setVolume(35), json: false))
        XCTAssertEqual(action("volume"), .volumeQuery(json: false))
    }

    func testVolumeRejectsBadValues() {
        for bad in ["101", "-1", "1.5", "loud", "", "%", "50 %"] {
            XCTAssertTrue(usageError("volume", bad)?.contains("0 to 100") ?? false, "'\(bad)'")
        }
        XCTAssertNotNil(usageError("volume", "10", "20"))
    }

    func testJSONFlagCanGoAnywhere() {
        XCTAssertEqual(action("status", "--json"), .remote(.status, json: true))
        XCTAssertEqual(action("--json", "status"), .remote(.status, json: true))
        XCTAssertEqual(action("sounds", "--json"), .sounds(json: true))
        XCTAssertEqual(action("volume", "--json"), .volumeQuery(json: true))
        XCTAssertEqual(action("play", "--json", "brown"), .remote(.play(.brown), json: true))
    }

    func testHelpAndVersion() {
        XCTAssertEqual(action("--help"), .help)
        XCTAssertEqual(action("-h"), .help)
        XCTAssertEqual(action("help"), .help)
        XCTAssertEqual(action("play", "--help"), .help)
        XCTAssertEqual(action("--version"), .version)
    }

    func testMissingCommand() {
        XCTAssertEqual(usageError(), "missing command")
    }

    func testUnknownCommandAndOption() {
        XCTAssertEqual(usageError("explode"), "unknown command 'explode'")
        XCTAssertEqual(usageError("status", "--loud"), "unknown option '--loud'")
        XCTAssertNotNil(usageError("-x"))
    }

    func testCommandsThatTakeNoArguments() {
        for command in ["stop", "toggle", "status", "sounds"] {
            XCTAssertTrue(usageError(command, "extra")?.contains("takes no arguments") ?? false, command)
        }
    }

    func testDoubleDashEndsOptions() {
        XCTAssertEqual(action("play", "--", "brown"), .remote(.play(.brown), json: false))
    }
}

final class HushCLIEntryTests: XCTestCase {
    func testInvokedAsHushRunsTheCLI() {
        XCTAssertEqual(HushCLIEntry.cliArguments(from: ["hush", "status"]), ["status"])
        XCTAssertEqual(HushCLIEntry.cliArguments(from: ["/usr/local/bin/hush", "play", "brown"]), ["play", "brown"])
        XCTAssertEqual(HushCLIEntry.cliArguments(from: ["hush"]), [])
    }

    func testCLIFlagRunsTheCLIFromTheRealExecutable() {
        let exe = "/Applications/Hush.app/Contents/MacOS/Hush"
        XCTAssertEqual(HushCLIEntry.cliArguments(from: [exe, "--cli", "status"]), ["status"])
        XCTAssertEqual(HushCLIEntry.cliArguments(from: [exe, "--cli"]), [])
    }

    func testNormalLaunchesStartTheApp() {
        let exe = "/Applications/Hush.app/Contents/MacOS/Hush"
        XCTAssertNil(HushCLIEntry.cliArguments(from: [exe]))
        XCTAssertNil(HushCLIEntry.cliArguments(from: [exe, "-psn_0_12345"]))
        XCTAssertNil(HushCLIEntry.cliArguments(from: [exe, "-NSDocumentRevisionsDebugMode", "YES"]))
        // A command word alone never turns the app into the CLI.
        XCTAssertNil(HushCLIEntry.cliArguments(from: [exe, "status"]))
        XCTAssertNil(HushCLIEntry.cliArguments(from: []))
    }
}

final class HushCLIRunTests: XCTestCase {
    private var out: [String] = []
    private var err: [String] = []

    private func run(_ arguments: [String], transport: FakeTransport) -> Int32 {
        out = []
        err = []
        return HushCLI.run(arguments: arguments, context: CLIContext(
            transport: transport,
            version: "9.9.9",
            out: { self.out.append($0) },
            err: { self.err.append($0) }
        ))
    }

    // MARK: Talking to the app

    func testPlayPrintsTheResultingState() {
        let transport = FakeTransport(success(playing: true))
        XCTAssertEqual(run(["play"], transport: transport), 0)
        XCTAssertEqual(transport.sent, [.play(nil)])
        XCTAssertEqual(out, ["Hush is playing Brown at 50% volume."])
        XCTAssertTrue(err.isEmpty)
    }

    func testPlayWithSoundSendsTheSound() {
        let transport = FakeTransport(success(playing: true, sound: "speech-blocker"))
        XCTAssertEqual(run(["play", "speech"], transport: transport), 0)
        XCTAssertEqual(transport.sent, [.play(.speechBlocker)])
        XCTAssertEqual(out, ["Hush is playing Speech Blocker at 50% volume."])
    }

    func testStatusWhenStopped() {
        let transport = FakeTransport(success(playing: false, volume: 30))
        XCTAssertEqual(run(["status"], transport: transport), 0)
        XCTAssertEqual(transport.sent, [.status])
        XCTAssertEqual(out, ["Hush is stopped. Sound: Brown, volume: 30%."])
    }

    func testStatusJSON() {
        let transport = FakeTransport(success(playing: true, sound: "speech-blocker", volume: 70))
        XCTAssertEqual(run(["status", "--json"], transport: transport), 0)
        XCTAssertEqual(out, [#"{"playing":true,"sound":"speech-blocker","volume":70}"#])
    }

    func testVolumeSetSendsPercent() {
        let transport = FakeTransport(success(playing: false, volume: 35))
        XCTAssertEqual(run(["volume", "35"], transport: transport), 0)
        XCTAssertEqual(transport.sent, [.setVolume(35)])
    }

    func testVolumeQueryPrintsJustTheNumber() {
        let transport = FakeTransport(success(playing: true, volume: 64))
        XCTAssertEqual(run(["volume"], transport: transport), 0)
        XCTAssertEqual(transport.sent, [.status])
        XCTAssertEqual(out, ["64"])
        XCTAssertEqual(run(["volume", "--json"], transport: transport), 0)
        XCTAssertEqual(out, [#"{"volume":64}"#])
    }

    func testStopAndToggleSendTheirCommands() {
        let transport = FakeTransport(success(playing: false))
        XCTAssertEqual(run(["stop"], transport: transport), 0)
        XCTAssertEqual(run(["toggle"], transport: transport), 0)
        XCTAssertEqual(transport.sent, [.stop, .toggle])
    }

    // MARK: Exit codes

    func testAppFailureExitsOneWithTheReason() {
        let transport = FakeTransport(.response(.failure(
            "Hush couldn't start audio output.",
            state: PlaybackSnapshot(playing: false, sound: "brown", volume: 50)
        )))
        XCTAssertEqual(run(["play"], transport: transport), CLIExitCode.failed)
        XCTAssertEqual(CLIExitCode.failed, 1)
        XCTAssertEqual(err, ["hush: Hush couldn't start audio output."])
        XCTAssertTrue(out.isEmpty)
    }

    func testUnreachableAppExitsThree() {
        let transport = FakeTransport(.unreachable("Hush didn't answer within 10 seconds."))
        XCTAssertEqual(run(["status"], transport: transport), CLIExitCode.unreachable)
        XCTAssertEqual(CLIExitCode.unreachable, 3)
        XCTAssertEqual(err, ["hush: Hush didn't answer within 10 seconds."])
        XCTAssertTrue(out.isEmpty)
    }

    func testUsageErrorsExitTwoWithoutContactingTheApp() {
        let transport = FakeTransport(success(playing: false))
        for arguments in [[], ["explode"], ["volume", "500"], ["play", "white"], ["status", "--nope"]] {
            XCTAssertEqual(run(arguments, transport: transport), CLIExitCode.usage, "\(arguments)")
            XCTAssertTrue(err.last?.hasPrefix("hush: ") ?? false)
            XCTAssertTrue(err.last?.contains("hush --help") ?? false)
        }
        XCTAssertEqual(CLIExitCode.usage, 2)
        XCTAssertTrue(transport.sent.isEmpty)
    }

    // MARK: Commands that stay local

    func testHelpListsEveryCommandAndExitCode() {
        let transport = FakeTransport(success(playing: false))
        XCTAssertEqual(run(["--help"], transport: transport), 0)
        let help = out.joined(separator: "\n")
        for word in CLIParser.commands where word != "help" {
            XCTAssertTrue(help.contains("  \(word)"), word)
        }
        for code in ["0  success", "1  ", "2  usage", "3  "] {
            XCTAssertTrue(help.contains(code), code)
        }
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testVersion() {
        let transport = FakeTransport(success(playing: false))
        XCTAssertEqual(run(["--version"], transport: transport), 0)
        XCTAssertEqual(out, ["hush 9.9.9"])
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testSoundsListsEverySoundWithoutContactingTheApp() {
        let transport = FakeTransport(.unreachable("should not be asked"))
        XCTAssertEqual(run(["sounds"], transport: transport), 0)
        XCTAssertEqual(out.count, 1)
        let lines = out[0].split(separator: "\n")
        XCTAssertEqual(lines.count, NoiseType.allCases.count)
        for (line, sound) in zip(lines, NoiseType.allCases) {
            XCTAssertTrue(line.hasPrefix(sound.cliID), "\(line)")
            XCTAssertTrue(line.hasSuffix(sound.rawValue), "\(line)")
        }
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testSoundsJSON() throws {
        let transport = FakeTransport(.unreachable("should not be asked"))
        XCTAssertEqual(run(["sounds", "--json"], transport: transport), 0)
        let entries = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(out[0].utf8)) as? [[String: String]]
        )
        XCTAssertEqual(entries.map { $0["id"] }, NoiseType.allCases.map(\.cliID))
        XCTAssertEqual(entries.map { $0["name"] }, NoiseType.allCases.map(\.rawValue))
    }
}
