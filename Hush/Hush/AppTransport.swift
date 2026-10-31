import AppKit

/// Hands a command to the running Hush app (launching it when needed) by
/// writing it into the app's own sandbox container, then waits for the app's
/// answer there. See `CommandChannel`.
///
/// This runs inside the same sandboxed executable as the app itself, so it
/// shares the app's container. No URL scheme, no entitlement, and nothing
/// outside the container is involved.
struct AppTransport: RemoteTransport {
    var appURL: URL? = AppLocation.bundleURL()
    var channel: CommandChannel = .live
    /// How long to wait for the app to launch and answer.
    var timeout: TimeInterval = 10

    func send(_ command: RemoteCommand) -> TransportOutcome {
        guard let appURL else {
            return .unreachable("couldn't find Hush.app from \(CommandLine.arguments[0]).")
        }
        // Answers that arrived after an earlier invocation gave up.
        channel.removeStaleReplies()

        // Write the command first: an app that starts because of this call
        // looks for waiting commands as it comes up.
        let token = CommandChannel.makeToken()
        do {
            try channel.submit(command, token: token)
        } catch {
            return .unreachable("couldn't write a command for Hush: \(error.localizedDescription)")
        }

        let launch = LaunchResult()
        if !Self.isRunning(appURL) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false  // don't steal focus from the terminal
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                launch.finish(error)
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Spin the run loop so Launch Services can call back.
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            if let error = launch.error {
                channel.withdraw(token: token)
                return .unreachable("couldn't launch Hush at \(appURL.path): \(error.localizedDescription)")
            }
            if let response = channel.takeReply(token: token) {
                return .response(response)
            }
        }
        // Don't let the command run later, after the caller has been told it failed.
        channel.withdraw(token: token)
        return .unreachable("Hush didn't answer within \(Int(timeout)) seconds.")
    }

    private static func isRunning(_ appURL: URL) -> Bool {
        let target = appURL.resolvingSymlinksInPath().path
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.resolvingSymlinksInPath().path == target
        }
    }
}

/// Carries the launch call's result across threads.
private final class LaunchResult {
    private let lock = NSLock()
    private var failure: Error?

    var error: Error? {
        lock.lock(); defer { lock.unlock() }
        return failure
    }

    func finish(_ error: Error?) {
        lock.lock(); defer { lock.unlock() }
        failure = error
    }
}

enum AppLocation {
    /// The `.app` this executable lives in, found from the resolved
    /// executable path. When the tool is started through the `hush` symlink,
    /// `Bundle.main` can't be trusted: the sandbox won't let it read the
    /// directory the link lives in, and it comes back empty.
    static func bundleURL() -> URL? {
        var size: UInt32 = 0
        _NSGetExecutablePath(nil, &size)
        var path = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&path, &size) == 0,
              let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        // .../Hush.app/Contents/MacOS/Hush
        let app = URL(fileURLWithPath: String(cString: resolved))
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return app.pathExtension == "app" ? app : nil
    }
}
