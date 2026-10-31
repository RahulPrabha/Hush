import AppKit

extension AudioEngine: PlaybackControlling {}

extension AppDelegate {
    /// AppKit delivers the `hush://` URL that launched the app after this
    /// call and before `applicationDidFinishLaunching`, so this is where the
    /// saved sound and volume have to be applied for that first command to
    /// see them. (The popover only applies them when it first appears.)
    func applicationWillFinishLaunching(_ notification: Notification) {
        HushSettings.restore(into: audioEngine)
    }

    /// `hush://` URLs: from the `hush` command line tool, or from anything
    /// else that opens one (Shortcuts, Raycast, a Stream Deck button).
    func application(_ application: NSApplication, open urls: [URL]) {
        let handler = RemoteControlHandler(engine: audioEngine)
        for url in urls where RemoteCommand.handles(url) {
            handler.handle(url: url)
        }
    }
}
