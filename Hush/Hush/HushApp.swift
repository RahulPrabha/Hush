import SwiftUI
import AppKit
import Combine

@main
struct HushApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let audioEngine = AudioEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: 24)

        if let button = statusItem.button {
            button.frame = NSRect(x: 0, y: 0, width: 24, height: 22)
            updateIcon(isPlaying: false)
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: ContentView(audioEngine: audioEngine))

        // Update icon when playing state changes
        audioEngine.$isPlaying.sink { [weak self] isPlaying in
            DispatchQueue.main.async {
                self?.updateIcon(isPlaying: isPlaying)
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateIcon(isPlaying: Bool) {
        let image = NSImage(
            systemSymbolName: isPlaying ? "waveform" : "waveform.slash",
            accessibilityDescription: "Hush"
        )
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click - toggle audio
            audioEngine.toggle()
        } else {
            // Left click - show popover
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
