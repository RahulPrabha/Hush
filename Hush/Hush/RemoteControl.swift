import Foundation

// App side of the command line interface: finds the commands the `hush` tool
// left for it, applies them to the audio engine, and leaves the answers where
// the tool can pick them up.

/// The preferences the popover persists with `@AppStorage`. The remote
/// control writes the same keys, so a volume or sound chosen from the terminal
/// survives a relaunch and shows up in the popover. ContentView.swift spells
/// them out as literals (it is compiled on its own by the App Store panel
/// renderer), so keep them in step.
enum HushSettings {
    static let noiseTypeKey = "selectedNoiseType"
    static let volumeKey = "savedVolume"

    /// Applies the saved sound and volume. The popover only does this when it
    /// first appears, which can be long after launch; the remote control
    /// needs the saved values from the first command on.
    static func restore(into engine: AudioEngine, from defaults: UserDefaults = .standard) {
        if let raw = defaults.string(forKey: noiseTypeKey),
           let type = NoiseType(rawValue: raw),
           engine.noiseType != type {
            engine.noiseType = type
        }
        if let saved = defaults.object(forKey: volumeKey) as? Double {
            let volume = Float(min(max(saved, 0), 1))
            if engine.volume != volume { engine.volume = volume }
        }
    }
}

/// How the `hush` tool and the running app talk: two folders of small JSON
/// files, named by a random token. The tool drops `commands/<token>.json`; the
/// app applies it and leaves `replies/<token>.json`.
///
/// The tool is the app's own sandboxed executable, so both ends share one app
/// container and nothing else can write there: no other app, and no web page,
/// can send Hush a command. There is no URL scheme and no entitlement.
struct CommandChannel {
    let directory: URL

    /// Commands older than this are dropped unread, so one the tool gave up on
    /// (or that outlived a hung app) can't run late.
    static let commandLifetime: TimeInterval = 30

    static let live: CommandChannel = {
        let tmp = FileManager.default.temporaryDirectory
        return CommandChannel(directory: tmp.appendingPathComponent("hush-cli", isDirectory: true))
    }()

    var commandsDirectory: URL { directory.appendingPathComponent("commands", isDirectory: true) }
    var repliesDirectory: URL { directory.appendingPathComponent("replies", isDirectory: true) }

    static func makeToken() -> String {
        UUID().uuidString
    }

    /// Tokens become file names, so only accept a conservative alphabet.
    static func isValid(token: String) -> Bool {
        guard (8...64).contains(token.count) else { return false }
        return token.unicodeScalars.allSatisfy {
            ($0.value >= 0x30 && $0.value <= 0x39)      // 0-9
                || ($0.value >= 0x41 && $0.value <= 0x5A) // A-Z
                || ($0.value >= 0x61 && $0.value <= 0x7A) // a-z
                || $0 == "-"
        }
    }

    private func commandFile(_ token: String) -> URL {
        commandsDirectory.appendingPathComponent("\(token).json")
    }

    private func replyFile(_ token: String) -> URL {
        repliesDirectory.appendingPathComponent("\(token).json")
    }

    private func createDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: commandsDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: repliesDirectory, withIntermediateDirectories: true)
    }

    // MARK: Tool side

    func submit(_ command: RemoteCommand, token: String) throws {
        guard Self.isValid(token: token) else { return }
        try createDirectories()
        // Atomic, so the app never reads half a file.
        try JSONEncoder().encode(command).write(to: commandFile(token), options: .atomic)
    }

    /// Takes back a command the app hasn't picked up yet. False if it already has.
    @discardableResult
    func withdraw(token: String) -> Bool {
        guard Self.isValid(token: token) else { return false }
        return (try? FileManager.default.removeItem(at: commandFile(token))) != nil
    }

    /// Returns the answer for `token` and removes it, or nil if it hasn't
    /// arrived (or can't be read).
    func takeReply(token: String) -> RemoteResponse? {
        guard Self.isValid(token: token) else { return nil }
        let url = replyFile(token)
        guard let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(RemoteResponse.self, from: data) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return response
    }

    // MARK: App side

    struct PendingCommand {
        var token: String
        var command: Result<RemoteCommand, Error>
    }

    /// Collects and removes every waiting command, oldest first. Files with an
    /// unusable name, and commands past their lifetime, are discarded.
    func takePendingCommands(now: Date = Date()) -> [PendingCommand] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: commandsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        var pending: [(modified: Date, entry: PendingCommand)] = []
        for file in files where file.pathExtension == "json" {
            let token = file.deletingPathExtension().lastPathComponent
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? now
            let data = try? Data(contentsOf: file)
            try? fm.removeItem(at: file)
            guard Self.isValid(token: token),
                  now.timeIntervalSince(modified) <= Self.commandLifetime,
                  let data else { continue }
            let command = Result { try JSONDecoder().decode(RemoteCommand.self, from: data) }
            pending.append((modified, PendingCommand(token: token, command: command)))
        }
        return pending.sorted { $0.modified < $1.modified }.map(\.entry)
    }

    func writeReply(_ response: RemoteResponse, token: String) throws {
        guard Self.isValid(token: token) else { return }
        try createDirectories()
        try JSONEncoder().encode(response).write(to: replyFile(token), options: .atomic)
    }

    /// Drops answers nobody collected (the tool gave up or was interrupted).
    func removeStaleReplies(olderThan age: TimeInterval = 60, now: Date = Date()) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: repliesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for file in files where file.pathExtension == "json" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, now.timeIntervalSince(modified) > age {
                try? fm.removeItem(at: file)
            }
        }
    }
}

/// Applies commands. Playback goes through the engine's `PlaybackCoordinator`,
/// the same object the menu bar icon reads, so a command can never leave the
/// icon disagreeing with the audio, and it gets the coordinator's handling of a
/// `stop` followed straight away by a `play`. Sound and volume are the
/// engine's own settings.
struct RemoteControlHandler {
    let engine: AudioEngine
    var defaults: UserDefaults = .standard

    private var playback: PlaybackCoordinator { engine.playback }

    func perform(_ command: RemoteCommand) -> RemoteResponse {
        switch command {
        case .play(let sound):
            if let sound { select(sound) }
            playback.play()
            if !playback.isPlaying { return startFailure() }

        case .stop:
            playback.stop()

        case .toggle:
            let wasPlaying = playback.isPlaying
            playback.toggle()
            if !wasPlaying && !playback.isPlaying { return startFailure() }

        case .status:
            break

        case .setVolume(let percent):
            let volume = Float(min(max(percent, 0), 100)) / 100
            engine.volume = volume
            defaults.set(Double(volume), forKey: HushSettings.volumeKey)
        }
        return .success(snapshot())
    }

    private func select(_ sound: NoiseType) {
        // Reassigning the same type would still reset the noise generator.
        if engine.noiseType != sound { engine.noiseType = sound }
        defaults.set(sound.rawValue, forKey: HushSettings.noiseTypeKey)
    }

    private func startFailure() -> RemoteResponse {
        .failure("Hush couldn't start audio output.", state: snapshot())
    }

    private func snapshot() -> PlaybackSnapshot {
        PlaybackSnapshot(
            playing: playback.isPlaying,
            sound: engine.noiseType.cliID,
            volume: Int((engine.volume * 100).rounded())
        )
    }
}

/// Watches the commands folder and runs whatever the `hush` tool leaves in it.
/// Everything happens on `queue` (the main queue in the app), where the audio
/// engine lives.
final class RemoteControlServer {
    private let handler: RemoteControlHandler
    private let channel: CommandChannel
    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?

    init(
        engine: AudioEngine,
        channel: CommandChannel = .live,
        defaults: UserDefaults = .standard,
        queue: DispatchQueue = .main
    ) {
        self.handler = RemoteControlHandler(engine: engine, defaults: defaults)
        self.channel = channel
        self.queue = queue
    }

    deinit {
        source?.cancel()
    }

    /// Starts watching, then runs anything already waiting (a command that
    /// launched the app is on disk before the app is up). Call on `queue`.
    func start() {
        arm()
        drain()
    }

    /// Runs every waiting command and writes its reply. Call on `queue`.
    func drain() {
        channel.removeStaleReplies()
        for pending in channel.takePendingCommands() {
            let response: RemoteResponse
            switch pending.command {
            case .success(let command):
                response = handler.perform(command)
            case .failure(let error):
                response = .failure(error.localizedDescription)
            }
            try? channel.writeReply(response, token: pending.token)
        }
    }

    /// Opens the commands folder for events. If the folder is removed or
    /// replaced (the system can clear temporary files), starts over.
    private func arm() {
        source?.cancel()
        source = nil
        try? FileManager.default.createDirectory(at: channel.commandsDirectory, withIntermediateDirectories: true)
        let descriptor = open(channel.commandsDirectory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            if !source.data.isDisjoint(with: [.delete, .rename, .revoke]) {
                self.arm()
            }
            self.drain()
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
