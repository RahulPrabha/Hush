import Foundation

// The vocabulary shared by the `hush` command line tool and the app's
// `hush://` URL handler. A command travels from the CLI to the running app as
// a URL; the app answers with a `RemoteResponse`.

extension NoiseType {
    /// Stable, shell-friendly identifier used on the command line and in
    /// `hush://` URLs: "brown", "speech-blocker".
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

/// One thing the CLI (or any `hush://` URL) can ask the running app to do.
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
    case notAHushURL
    case unknownCommand(String)
    case unknownSound(String)
    case ambiguousSound(String)
    case invalidVolume(String?)

    var errorDescription: String? {
        switch self {
        case .notAHushURL:
            return "Not a hush:// URL."
        case .unknownCommand(let name):
            return "Unknown command '\(name)'."
        case .unknownSound(let name):
            return "Unknown sound '\(name)'. Available sounds: \(NoiseType.cliIDList)."
        case .ambiguousSound(let name):
            return "'\(name)' matches more than one sound. Available sounds: \(NoiseType.cliIDList)."
        case .invalidVolume(let value):
            return "Volume must be a whole number from 0 to 100 (got '\(value ?? "nothing")')."
        }
    }
}

extension RemoteCommand {
    static let urlScheme = "hush"
    static let soundQueryName = "sound"
    static let levelQueryName = "level"
    static let replyQueryName = "reply"

    static func handles(_ url: URL) -> Bool {
        url.scheme?.lowercased() == urlScheme
    }

    /// `hush://play?sound=brown`, `hush://stop`, `hush://toggle`,
    /// `hush://status`, `hush://volume?level=40`. A `reply` token asks the app
    /// to leave its answer in the reply mailbox.
    func url(replyToken: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        var items: [URLQueryItem] = []
        switch self {
        case .play(let sound):
            components.host = "play"
            if let sound { items.append(URLQueryItem(name: Self.soundQueryName, value: sound.cliID)) }
        case .stop:
            components.host = "stop"
        case .toggle:
            components.host = "toggle"
        case .status:
            components.host = "status"
        case .setVolume(let level):
            components.host = "volume"
            items.append(URLQueryItem(name: Self.levelQueryName, value: String(level)))
        }
        if let replyToken { items.append(URLQueryItem(name: Self.replyQueryName, value: replyToken)) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url!
    }

    init(url: URL) throws {
        guard Self.handles(url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RemoteCommandError.notAHushURL
        }
        // hush://play, hush:play and hush:///play all name the "play" command.
        let name = ((components.host?.isEmpty == false ? components.host : nil) ?? components.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        func value(_ query: String) -> String? {
            components.queryItems?.first(where: { $0.name == query })?.value
        }

        switch name {
        case "play":
            guard let raw = value(Self.soundQueryName) else {
                self = .play(nil)
                return
            }
            switch NoiseType.lookup(raw) {
            case .found(let sound): self = .play(sound)
            case .unknown: throw RemoteCommandError.unknownSound(raw)
            case .ambiguous: throw RemoteCommandError.ambiguousSound(raw)
            }
        case "stop":
            self = .stop
        case "toggle":
            self = .toggle
        case "status":
            self = .status
        case "volume":
            let raw = value(Self.levelQueryName)
            guard let raw, let level = Int(raw), (0...100).contains(level) else {
                throw RemoteCommandError.invalidVolume(raw)
            }
            self = .setVolume(level)
        default:
            throw RemoteCommandError.unknownCommand(name)
        }
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
