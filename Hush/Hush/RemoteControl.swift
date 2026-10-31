import Foundation

// App side of the command line interface: applies a `RemoteCommand` to the
// audio engine and leaves the answer where the `hush` tool can pick it up.

/// The slice of `AudioEngine` the remote control needs, so tests can drive the
/// handler with a fake instead of real audio output.
protocol PlaybackControlling: AnyObject {
    var isPlaying: Bool { get }
    /// Linear gain, 0...1.
    var volume: Float { get set }
    var noiseType: NoiseType { get set }
    func play()
    func stop()
    func toggle()
}

/// The preferences the popover persists with `@AppStorage`. The remote
/// control writes the same keys, so a volume or sound chosen from the terminal
/// survives a relaunch and shows up in the popover. ContentView.swift spells
/// them out as literals (it is compiled on its own by the App Store panel
/// renderer), so keep them in step; a test checks.
enum HushSettings {
    static let noiseTypeKey = "selectedNoiseType"
    static let volumeKey = "savedVolume"

    /// Applies the saved sound and volume. The popover only does this when it
    /// first appears, which can be long after launch; the remote control
    /// needs the saved values from the first command on.
    static func restore(into engine: PlaybackControlling, from defaults: UserDefaults = .standard) {
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

/// Where the app leaves its answer to a command. The CLI and the app run the
/// same sandboxed executable, so both see the same container and the answer
/// travels as a plain file; no entitlement is involved.
struct ReplyMailbox {
    let directory: URL

    static let live: ReplyMailbox = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ReplyMailbox(directory: caches.appendingPathComponent("hush-cli", isDirectory: true))
    }()

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

    static func token(in url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == RemoteCommand.replyQueryName })?.value,
              isValid(token: value) else { return nil }
        return value
    }

    private func file(for token: String) -> URL {
        directory.appendingPathComponent("\(token).json")
    }

    func write(_ response: RemoteResponse, token: String) throws {
        guard Self.isValid(token: token) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Atomic, so the reader never sees half a file.
        try JSONEncoder().encode(response).write(to: file(for: token), options: .atomic)
    }

    /// Returns the answer for `token` and removes it, or nil if it hasn't
    /// arrived (or can't be read).
    func take(token: String) -> RemoteResponse? {
        guard Self.isValid(token: token) else { return nil }
        let url = file(for: token)
        guard let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(RemoteResponse.self, from: data) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return response
    }

    /// Drops answers nobody collected (the CLI gave up or was interrupted).
    func removeStale(olderThan age: TimeInterval = 60, now: Date = Date()) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
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

struct RemoteControlHandler {
    let engine: PlaybackControlling
    var defaults: UserDefaults = .standard
    var mailbox: ReplyMailbox = .live

    /// Handles one `hush://` URL and, if it carries a reply token, leaves the
    /// answer in the mailbox. Returns the answer for callers that want it.
    @discardableResult
    func handle(url: URL) -> RemoteResponse {
        let response: RemoteResponse
        do {
            response = perform(try RemoteCommand(url: url))
        } catch {
            response = .failure(error.localizedDescription, state: snapshot())
        }
        if let token = ReplyMailbox.token(in: url) {
            mailbox.removeStale()
            try? mailbox.write(response, token: token)
        }
        return response
    }

    func perform(_ command: RemoteCommand) -> RemoteResponse {
        switch command {
        case .play(let sound):
            if let sound { select(sound) }
            engine.play()
            if !engine.isPlaying { return startFailure() }

        case .stop:
            engine.stop()

        case .toggle:
            let wasPlaying = engine.isPlaying
            engine.toggle()
            if !wasPlaying && !engine.isPlaying { return startFailure() }

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
            playing: engine.isPlaying,
            sound: engine.noiseType.cliID,
            volume: Int((engine.volume * 100).rounded())
        )
    }
}
