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

    // MARK: URLs

    func testEveryCommandSurvivesAURLRoundTrip() throws {
        let commands: [RemoteCommand] = [
            .play(nil), .play(.brown), .play(.speechBlocker),
            .stop, .toggle, .status,
            .setVolume(0), .setVolume(37), .setVolume(100),
        ]
        for command in commands {
            XCTAssertEqual(try RemoteCommand(url: command.url()), command, "\(command)")
            XCTAssertEqual(try RemoteCommand(url: command.url(replyToken: "ABCD-1234")), command, "\(command)")
        }
    }

    func testURLShapes() {
        XCTAssertEqual(RemoteCommand.stop.url().absoluteString, "hush://stop")
        XCTAssertEqual(RemoteCommand.play(.speechBlocker).url().absoluteString, "hush://play?sound=speech-blocker")
        XCTAssertEqual(RemoteCommand.setVolume(40).url().absoluteString, "hush://volume?level=40")
        XCTAssertEqual(
            RemoteCommand.status.url(replyToken: "ABCD-1234").absoluteString,
            "hush://status?reply=ABCD-1234"
        )
    }

    func testParsesHandWrittenURLs() throws {
        XCTAssertEqual(try RemoteCommand(url: URL(string: "hush://play")!), .play(nil))
        XCTAssertEqual(try RemoteCommand(url: URL(string: "HUSH://Toggle")!), .toggle)
        XCTAssertEqual(try RemoteCommand(url: URL(string: "hush:stop")!), .stop)
        XCTAssertEqual(try RemoteCommand(url: URL(string: "hush:///status")!), .status)
        XCTAssertEqual(try RemoteCommand(url: URL(string: "hush://play?sound=Speech%20Blocker")!), .play(.speechBlocker))
        XCTAssertEqual(try RemoteCommand(url: URL(string: "hush://play?sound=speech")!), .play(.speechBlocker))
    }

    func testRejectsWrongScheme() {
        XCTAssertThrowsError(try RemoteCommand(url: URL(string: "https://play")!)) {
            XCTAssertEqual($0 as? RemoteCommandError, .notAHushURL)
        }
        XCTAssertFalse(RemoteCommand.handles(URL(string: "https://hush")!))
        XCTAssertTrue(RemoteCommand.handles(URL(string: "hush://stop")!))
    }

    func testRejectsUnknownCommand() {
        XCTAssertThrowsError(try RemoteCommand(url: URL(string: "hush://explode")!)) {
            XCTAssertEqual($0 as? RemoteCommandError, .unknownCommand("explode"))
        }
    }

    func testRejectsUnknownSound() {
        XCTAssertThrowsError(try RemoteCommand(url: URL(string: "hush://play?sound=white")!)) {
            XCTAssertEqual($0 as? RemoteCommandError, .unknownSound("white"))
        }
    }

    func testRejectsBadVolumes() {
        for bad in ["hush://volume", "hush://volume?level=", "hush://volume?level=abc",
                    "hush://volume?level=101", "hush://volume?level=-1", "hush://volume?level=4.5"] {
            XCTAssertThrowsError(try RemoteCommand(url: URL(string: bad)!), bad) {
                guard case .invalidVolume = $0 as? RemoteCommandError else {
                    return XCTFail("\(bad): unexpected error \($0)")
                }
            }
        }
    }

    func testErrorMessagesNameTheProblem() {
        XCTAssertTrue(RemoteCommandError.unknownSound("white").localizedDescription.contains("brown, speech-blocker"))
        XCTAssertTrue(RemoteCommandError.invalidVolume("abc").localizedDescription.contains("0 to 100"))
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
