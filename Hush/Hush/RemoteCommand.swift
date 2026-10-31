import Foundation

// The vocabulary shared by the `hush` command line tool and the app. A command
// travels from the CLI to the running app as a small JSON file in the app's own
// sandbox container (see CommandChannel); the app answers with a
// `RemoteResponse`.

extension NoiseType {
    /// Stable, shell-friendly identifier used on the command line and in
    /// command files: "brown", "speech-blocker".
    var cliID: String {
        rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    enum Lookup: Equatable {
        case found(NoiseType)
        case unknown
        case ambiguous([NoiseType])
    }

    /// Resolves what a person typed to a sound: an exact id ("brown"), the
    /// English name ("Speech Blocker"), or an unambiguous prefix ("speech").
    static func lookup(_ input: String) -> Lookup {
        let key = input
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        guard !key.isEmpty else { return .unknown }
        if let exact = allCases.first(where: { $0.cliID == key }) { return .found(exact) }
        let matches = allCases.filter { $0.cliID.hasPrefix(key) }
        switch matches.count {
        case 0: return .unknown
        case 1: return .found(matches[0])
        default: return .ambiguous(matches)
        }
    }

    static var cliIDList: String {
        allCases.map(\.cliID).joined(separator: ", ")
    }
}

/// One thing the `hush` tool can ask the running app to do.
enum RemoteCommand: Equatable {
    /// Start playing, switching to the given sound first when there is one.
    case play(NoiseType?)
    case stop
    case toggle
    case status
    /// Master volume as a percentage, 0...100.
    case setVolume(Int)
}

enum RemoteCommandError: Error, Equatable, LocalizedError {
    case unknownCommand(String)
    case unknownSound(String)
    case ambiguousSound(String)
    case invalidVolume(Int?)

    var errorDescription: String? {
        switch self {
        case .unknownCommand(let name):
            return "Unknown command '\(name)'."
        case .unknownSound(let name):
            return "Unknown sound '\(name)'. Available sounds: \(NoiseType.cliIDList)."
        case .ambiguousSound(let name):
            return "'\(name)' matches more than one sound. Available sounds: \(NoiseType.cliIDList)."
        case .invalidVolume(let value):
            return "Volume must be a whole number from 0 to 100 (got '\(value.map(String.init) ?? "nothing")')."
        }
    }
}

/// How a command is written to disk: `{"command":"play","sound":"brown"}`,
/// `{"command":"volume","level":40}`, `{"command":"stop"}`. Decoding checks
/// the values, so whatever reads a command file gets a valid command or an
/// error it can report.
extension RemoteCommand: Codable {
    private struct Wire: Codable {
        var command: String
        var sound: String?
        var level: Int?
    }

    init(from decoder: Decoder) throws {
        let wire = try Wire(from: decoder)
        switch wire.command {
        case "play":
            guard let raw = wire.sound else {
                self = .play(nil)
                return
            }
            switch NoiseType.lookup(raw) {
            case .found(let sound): self = .play(sound)
            case .unknown: throw RemoteCommandError.unknownSound(raw)
            case .ambiguous: throw RemoteCommandError.ambiguousSound(raw)
            }
        case "stop": self = .stop
        case "toggle": self = .toggle
        case "status": self = .status
        case "volume":
            guard let level = wire.level, (0...100).contains(level) else {
                throw RemoteCommandError.invalidVolume(wire.level)
            }
            self = .setVolume(level)
        default:
            throw RemoteCommandError.unknownCommand(wire.command)
        }
    }

    func encode(to encoder: Encoder) throws {
        let wire: Wire
        switch self {
        case .play(let sound): wire = Wire(command: "play", sound: sound?.cliID)
        case .stop: wire = Wire(command: "stop")
        case .toggle: wire = Wire(command: "toggle")
        case .status: wire = Wire(command: "status")
        case .setVolume(let level): wire = Wire(command: "volume", level: level)
        }
        try wire.encode(to: encoder)
    }
}

/// What Hush is doing right now.
struct PlaybackSnapshot: Codable, Equatable {
    var playing: Bool
    /// The sound's `cliID`.
    var sound: String
    /// Master volume, 0...100.
    var volume: Int
}

/// The app's answer to a command. A failed command still carries the state
/// Hush is left in.
struct RemoteResponse: Codable, Equatable {
    var ok: Bool
    var error: String?
    var state: PlaybackSnapshot?

    static func success(_ state: PlaybackSnapshot) -> RemoteResponse {
        RemoteResponse(ok: true, error: nil, state: state)
    }

    static func failure(_ message: String, state: PlaybackSnapshot? = nil) -> RemoteResponse {
        RemoteResponse(ok: false, error: message, state: state)
    }
}
