import AppKit

/// Delivers a command to the running Hush app (launching it when needed) as a
/// `hush://` URL, then waits for the app's answer in the reply mailbox.
///
/// This runs inside the same sandboxed executable as the app itself, so the
/// URL goes through Launch Services like any other app's, and the mailbox is
/// in the app's own container. No entitlements are involved.
struct AppTransport: RemoteTransport {
    var appURL: URL? = AppLocation.bundleURL()
    var mailbox: ReplyMailbox = .live
    /// How long to wait for the app to launch and answer.
    var timeout: TimeInterval = 10

    func send(_ command: RemoteCommand) -> TransportOutcome {
        guard let appURL else {
            return .unreachable("couldn't find Hush.app from \(CommandLine.arguments[0]).")
        }
        // Answers that arrived after an earlier invocation gave up.
        mailbox.removeStale()
        let token = ReplyMailbox.makeToken()
        let url = command.url(replyToken: token)

        let opened = OpenResult()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false  // don't steal focus from the terminal
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
            opened.finish(error)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Spin the run loop so Launch Services can call back.
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            if let error = opened.error {
                return .unreachable("couldn't open Hush at \(appURL.path): \(error.localizedDescription)")
            }
            if let response = mailbox.take(token: token) {
                return .response(response)
            }
        }
        return .unreachable("Hush didn't answer within \(Int(timeout)) seconds.")
    }
}

/// Carries the open call's result across threads.
private final class OpenResult {
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
