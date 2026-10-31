import AppKit

extension AudioEngine: PlaybackControlling {}

/// Kept for the life of the app; `AppDelegate` itself is declared in HushApp.swift.
private var remoteControlServer: RemoteControlServer?

extension AppDelegate {
    /// Applies the saved sound and volume (the popover only does that when it
    /// first appears), then starts listening for commands from the `hush`
    /// tool. A command that launched the app is already waiting on disk, so it
    /// runs here, after the saved settings and before the first window.
    func applicationWillFinishLaunching(_ notification: Notification) {
        HushSettings.restore(into: audioEngine)
        let server = RemoteControlServer(engine: audioEngine)
        remoteControlServer = server
        server.start()
    }
}
