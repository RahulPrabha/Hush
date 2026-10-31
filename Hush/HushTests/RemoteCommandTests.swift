import XCTest

final class RemoteCommandTests: XCTestCase {
    // MARK: Sound lookup

    func testSoundIDsAreKebabCase() {
        XCTAssertEqual(NoiseType.brown.cliID, "brown")
        XCTAssertEqual(NoiseType.speechBlocker.cliID, "speech-blocker")
    }

    func testLookupAcceptsIDNameAndCase() {
        XCTAssertEqual(NoiseType.lookup("brown"), .found(.brown))
        XCTAssertEqual(NoiseType.lookup("BROWN"), .found(.brown))
        XCTAssertEqual(NoiseType.lookup("speech-blocker"), .found(.speechBlocker))
        XCTAssertEqual(NoiseType.lookup("Speech Blocker"), .found(.speechBlocker))
        XCTAssertEqual(NoiseType.lookup("speech_blocker"), .found(.speechBlocker))
    }

    func testLookupAcceptsUnambiguousPrefix() {
        XCTAssertEqual(NoiseType.lookup("speech"), .found(.speechBlocker))
        XCTAssertEqual(NoiseType.lookup("b"), .found(.brown))
    }

    func testLookupRejectsUnknownAndEmpty() {
        XCTAssertEqual(NoiseType.lookup("white"), .unknown)
        XCTAssertEqual(NoiseType.lookup(""), .unknown)
        XCTAssertEqual(NoiseType.lookup("   "), .unknown)
    }

    // MARK: Command files

    private func decode(_ json: String) throws -> RemoteCommand {
        try JSONDecoder().decode(RemoteCommand.self, from: Data(json.utf8))
    }

    func testEveryCommandSurvivesAnEncodeDecodeRoundTrip() throws {
        let commands: [RemoteCommand] = [
            .play(nil), .play(.brown), .play(.speechBlocker),
            .stop, .toggle, .status,
            .setVolume(0), .setVolume(37), .setVolume(100),
        ]
        for command in commands {
            let data = try JSONEncoder().encode(command)
            XCTAssertEqual(try JSONDecoder().decode(RemoteCommand.self, from: data), command, "\(command)")
        }
    }

    func testDecodesHandWrittenCommands() throws {
        XCTAssertEqual(try decode(#"{"command":"play"}"#), .play(nil))
        XCTAssertEqual(try decode(#"{"command":"play","sound":"speech"}"#), .play(.speechBlocker))
        XCTAssertEqual(try decode(#"{"command":"play","sound":"Speech Blocker"}"#), .play(.speechBlocker))
        XCTAssertEqual(try decode(#"{"command":"stop"}"#), .stop)
        XCTAssertEqual(try decode(#"{"command":"toggle"}"#), .toggle)
        XCTAssertEqual(try decode(#"{"command":"status"}"#), .status)
        XCTAssertEqual(try decode(#"{"command":"volume","level":40}"#), .setVolume(40))
    }

    func testRejectsUnknownCommand() {
        XCTAssertThrowsError(try decode(#"{"command":"explode"}"#)) {
            XCTAssertEqual($0 as? RemoteCommandError, .unknownCommand("explode"))
        }
        // Command names are exact: the CLI lowercases before it writes one.
        XCTAssertThrowsError(try decode(#"{"command":"STOP"}"#))
    }

    func testRejectsUnknownSound() {
        XCTAssertThrowsError(try decode(#"{"command":"play","sound":"white"}"#)) {
            XCTAssertEqual($0 as? RemoteCommandError, .unknownSound("white"))
        }
    }

    func testRejectsBadVolumes() {
        for bad in [#"{"command":"volume"}"#,
                    #"{"command":"volume","level":101}"#,
                    #"{"command":"volume","level":-1}"#] {
            XCTAssertThrowsError(try decode(bad), bad) {
                guard case .invalidVolume = $0 as? RemoteCommandError else {
                    return XCTFail("\(bad): unexpected error \($0)")
                }
            }
        }
        XCTAssertThrowsError(try decode(#"{"command":"volume","level":4.5}"#))
        XCTAssertThrowsError(try decode(#"{"command":"volume","level":"loud"}"#))
    }

    func testRejectsMalformedFiles() {
        XCTAssertThrowsError(try decode("not json"))
        XCTAssertThrowsError(try decode("{}"))
        XCTAssertThrowsError(try decode("[]"))
    }

    func testErrorMessagesNameTheProblem() {
        XCTAssertTrue(RemoteCommandError.unknownSound("white").localizedDescription.contains("brown, speech-blocker"))
        XCTAssertTrue(RemoteCommandError.invalidVolume(500).localizedDescription.contains("0 to 100"))
    }

    // MARK: Responses

    func testResponseCodableRoundTrip() throws {
        let state = PlaybackSnapshot(playing: true, sound: "brown", volume: 50)
        for response in [RemoteResponse.success(state), .failure("nope", state: state), .failure("nope")] {
            let data = try JSONEncoder().encode(response)
            XCTAssertEqual(try JSONDecoder().decode(RemoteResponse.self, from: data), response)
        }
    }
}
