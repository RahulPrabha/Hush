import Foundation

// The `hush` command line tool. It never plays audio itself: it turns its
// arguments into a `RemoteCommand`, hands that to the running Hush app through
// a `RemoteTransport`, and prints the app's answer.

enum CLIExitCode {
    static let success: Int32 = 0
    /// Hush understood the command but couldn't carry it out.
    static let failed: Int32 = 1
    /// Bad command or argument.
    static let usage: Int32 = 2
    /// Hush couldn't be launched, or didn't answer in time.
    static let unreachable: Int32 = 3
}

enum CLIAction: Equatable {
    case help
    case version
    case sounds(json: Bool)
    /// Ask the app for its state and print only the volume.
    case volumeQuery(json: Bool)
    case remote(RemoteCommand, json: Bool)
}

struct CLIUsageError: Error, Equatable {
    var message: String
}

enum CLIParser {
    static let commands = ["play", "stop", "toggle", "status", "volume", "sounds", "help"]

    static func parse(_ arguments: [String]) -> Result<CLIAction, CLIUsageError> {
        var json = false
        var wantsHelp = false
        var wantsVersion = false
        var positionals: [String] = []
        var optionsEnded = false

        for argument in arguments {
            if optionsEnded || !argument.hasPrefix("-") || Int(argument) != nil {
                positionals.append(argument)
                continue
            }
            switch argument {
            case "--": optionsEnded = true
            case "--json": json = true
            case "-h", "--help": wantsHelp = true
            case "--version": wantsVersion = true
            default: return .failure(CLIUsageError(message: "unknown option '\(argument)'"))
            }
        }

        if wantsHelp { return .success(.help) }
        if wantsVersion { return .success(.version) }
        guard let command = positionals.first?.lowercased() else {
            return .failure(CLIUsageError(message: "missing command"))
        }
        let operands = Array(positionals.dropFirst())

        func noOperands(_ action: CLIAction) -> Result<CLIAction, CLIUsageError> {
            operands.isEmpty
                ? .success(action)
                : .failure(CLIUsageError(message: "'\(command)' takes no arguments"))
        }

        switch command {
        case "help":
            return .success(.help)
        case "stop":
            return noOperands(.remote(.stop, json: json))
        case "toggle":
            return noOperands(.remote(.toggle, json: json))
        case "status":
            return noOperands(.remote(.status, json: json))
        case "sounds":
            return noOperands(.sounds(json: json))
        case "play":
            guard operands.count <= 1 else {
                return .failure(CLIUsageError(message: "'play' takes at most one sound"))
            }
            guard let name = operands.first else { return .success(.remote(.play(nil), json: json)) }
            switch NoiseType.lookup(name) {
            case .found(let sound):
                return .success(.remote(.play(sound), json: json))
            case .unknown:
                return .failure(CLIUsageError(
                    message: "unknown sound '\(name)' (available: \(NoiseType.cliIDList))"))
            case .ambiguous:
                return .failure(CLIUsageError(
                    message: "'\(name)' matches more than one sound (available: \(NoiseType.cliIDList))"))
            }
        case "volume":
            guard operands.count <= 1 else {
                return .failure(CLIUsageError(message: "'volume' takes one value from 0 to 100"))
            }
            guard let raw = operands.first else { return .success(.volumeQuery(json: json)) }
            let digits = raw.hasSuffix("%") ? String(raw.dropLast()) : raw
            guard let level = Int(digits), (0...100).contains(level) else {
                return .failure(CLIUsageError(
                    message: "volume must be a whole number from 0 to 100 (got '\(raw)')"))
            }
            return .success(.remote(.setVolume(level), json: json))
        default:
            return .failure(CLIUsageError(message: "unknown command '\(command)'"))
        }
    }
}

enum TransportOutcome: Equatable {
    case response(RemoteResponse)
    /// The app couldn't be launched or didn't answer; the text says why.
    case unreachable(String)
}

protocol RemoteTransport {
    func send(_ command: RemoteCommand) -> TransportOutcome
}

struct CLIContext {
    var transport: RemoteTransport
    var version: String
    var out: (String) -> Void
    var err: (String) -> Void
}

enum HushCLI {
    static let helpText = """
    Usage: hush <command> [options]

    Control the Hush menu bar app from the terminal. Hush is launched if it
    isn't already running, and the menu bar icon follows along.

    Commands:
      play [sound]     Start playing, switching to [sound] first if given
      stop             Stop playing
      toggle           Start if stopped, stop if playing
      status           Show whether Hush is playing, the sound, and the volume
      volume [0-100]   Set the volume; with no value, print the current volume
      sounds           List the available sounds

    Options:
      --json           Print JSON instead of text
      -h, --help       Show this help
      --version        Show the Hush version

    Exit codes:
      0  success
      1  Hush couldn't carry out the command (for example, no audio output)
      2  usage error: bad command or argument
      3  Hush couldn't be launched or didn't answer in time

    Examples:
      hush play                  Resume the last sound
      hush play speech-blocker   Switch to the speech blocker and play
      hush volume 35
      hush status --json
    """

    static func run(arguments: [String], context: CLIContext) -> Int32 {
        switch CLIParser.parse(arguments) {
        case .failure(let error):
            context.err("hush: \(error.message)\nTry 'hush --help' for usage.")
            return CLIExitCode.usage
        case .success(.help):
            context.out(helpText)
            return CLIExitCode.success
        case .success(.version):
            context.out("hush \(context.version)")
            return CLIExitCode.success
        case .success(.sounds(let json)):
            context.out(soundsText(json: json))
            return CLIExitCode.success
        case .success(.volumeQuery(let json)):
            return execute(.status, json: json, context: context) { state in
                json ? jsonText(["volume": state.volume]) : "\(state.volume)"
            }
        case .success(.remote(let command, let json)):
            return execute(command, json: json, context: context) { state in
                json ? jsonText(state) : describe(state)
            }
        }
    }

    private static func execute(
        _ command: RemoteCommand,
        json: Bool,
        context: CLIContext,
        render: (PlaybackSnapshot) -> String
    ) -> Int32 {
        switch context.transport.send(command) {
        case .unreachable(let reason):
            context.err("hush: \(reason)")
            return CLIExitCode.unreachable
        case .response(let response):
            guard response.ok, let state = response.state else {
                context.err("hush: \(response.error ?? "the command failed")")
                return CLIExitCode.failed
            }
            context.out(render(state))
            return CLIExitCode.success
        }
    }

    // MARK: Output

    static func describe(_ state: PlaybackSnapshot) -> String {
        let name = NoiseType.allCases.first(where: { $0.cliID == state.sound })?.rawValue ?? state.sound
        return state.playing
            ? "Hush is playing \(name) at \(state.volume)% volume."
            : "Hush is stopped. Sound: \(name), volume: \(state.volume)%."
    }

    static func soundsText(json: Bool) -> String {
        if json {
            struct Entry: Encodable { var id: String; var name: String }
            return jsonText(NoiseType.allCases.map { Entry(id: $0.cliID, name: $0.rawValue) })
        }
        let width = (NoiseType.allCases.map { $0.cliID.count }.max() ?? 0) + 2
        return NoiseType.allCases.map {
            $0.cliID.padding(toLength: width, withPad: " ", startingAt: 0) + $0.rawValue
        }.joined(separator: "\n")
    }

    private static func jsonText<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

enum HushCLIEntry {
    /// The arguments to run as the command line tool, or nil when the process
    /// should start as the menu bar app. The tool is the app's own executable:
    /// it runs as the CLI when invoked as `hush` (a symlink on PATH) or when
    /// the first argument is `--cli`. Anything else, including a launch from
    /// Finder or `open`, starts the app.
    static func cliArguments(from argv: [String]) -> [String]? {
        guard let invokedAs = argv.first else { return nil }
        if URL(fileURLWithPath: invokedAs).lastPathComponent == "hush" {
            return Array(argv.dropFirst())
        }
        if argv.count > 1, argv[1] == "--cli" {
            return Array(argv.dropFirst(2))
        }
        return nil
    }
}
