// Renders the real Hush ContentView offscreen to a PNG, for make_screenshots.py.
// Built and run by render_panels.sh together with the app's own sources; never
// touches the screen, so nothing but the panel can end up in a capture.
//
// Usage: render_panel <out.png> <Brown|"Speech Blocker"> <dark|light> <on|off>
// The language comes from the usual -AppleLanguages "(de)" launch argument.
import AppKit
import ServiceManagement
import SwiftUI

/// Stands in for the type that HushApp.swift defines next to the @main entry.
final class PopoverState: ObservableObject {
    @Published var isShown = false
}

/// A login item that is already on or off, so the switch renders without
/// registering anything with the system.
private struct FakeLoginItem: LoginItemService {
    let status: SMAppService.Status
    func register() throws {}
    func unregister() throws {}
}

let args = CommandLine.arguments
guard args.count >= 5 else {
    FileHandle.standardError.write(Data("usage: render_panel <out.png> <noise> <dark|light> <on|off>\n".utf8))
    exit(2)
}
let (out, noise, scheme, login) = (args[1], args[2], args[3], args[4])

let defaults = UserDefaults.standard
defaults.set(noise, forKey: "selectedNoiseType")
defaults.set(0.5, forKey: "savedVolume")
defaults.set(scheme == "dark", forKey: "isDarkMode")

let engine = AudioEngine()
engine.isPlaying = true   // shows the "Playing" pill and the live spectrum shape
let root = ContentView(
    audioEngine: engine,
    popoverState: PopoverState(),
    launchAtLogin: LaunchAtLogin(service: FakeLoginItem(status: login == "on" ? .enabled : .notRegistered))
)

// ImageRenderer draws the SwiftUI tree directly. Caching an NSHostingView's
// display instead leaves stray hairlines at the ends of the status pill.
// onAppear does not run here, so apply the state it would set.
engine.noiseType = NoiseType(rawValue: noise) ?? .brown
engine.volume = 0.5

let png: Data? = MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: root.environment(\.colorScheme, scheme == "dark" ? .dark : .light))
    renderer.scale = 2
    return renderer.cgImage.flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
}
guard let png else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
