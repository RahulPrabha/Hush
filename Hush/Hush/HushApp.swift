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
            button.toolTip = "Hush"
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)
        let hosting = NSHostingController(rootView: ContentView(
            audioEngine: audioEngine,
            onHeightChange: { [weak self] h in self?.contentHeightChanged(to: h) }
        ))
        // Don't let the hosting controller push its preferred size to the
        // popover: that reports the post-animation target height in one jump,
        // so the window snaps while the content is still animating (or, on
        // some macOS versions, gets stretch-animated by the popover). The
        // GeometryReader callback above resizes the popover frame-by-frame
        // in lockstep with SwiftUI's own height animation instead.
        hosting.sizingOptions = []
        popover.contentViewController = hosting

        // Update icon when playing state changes
        audioEngine.$isPlaying.sink { [weak self] isPlaying in
            DispatchQueue.main.async {
                self?.updateIcon(isPlaying: isPlaying)
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateIcon(isPlaying: Bool) {
        let canvasSize = NSSize(width: 18, height: 18)
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let symbol = NSImage(
            systemSymbolName: isPlaying ? "ear.badge.waveform" : "ear",
            accessibilityDescription: "Hush"
        )?.withSymbolConfiguration(config) else { return }

        // Both symbols share the same ear glyph in their top-left corner; the
        // "waveform" badge only extends down and to the right. Centering each
        // symbol by its own (differently sized) bounding box would shift the
        // ear when toggling — the icon appears to "hop". Instead, anchor every
        // state's top-left to the plain ear's centered position so the ear
        // stays put and only the badge appears/disappears.
        let earSize = NSImage(systemSymbolName: "ear", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?.size ?? symbol.size
        let anchorX = (canvasSize.width - earSize.width) / 2
        let topGap = (canvasSize.height - earSize.height) / 2

        let canvas = NSImage(size: canvasSize)
        canvas.lockFocus()
        let s = symbol.size
        symbol.draw(in: NSRect(
            x: anchorX,
            y: canvasSize.height - topGap - s.height,
            width: s.width,
            height: s.height
        ))
        canvas.unlockFocus()
        canvas.isTemplate = true
        statusItem.button?.image = canvas
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

    private var contentHeight: CGFloat = 480

    private func contentHeightChanged(to height: CGFloat) {
        contentHeight = height
        guard popover.isShown else { return }
        // The GeometryReader callback fires mid-render-pass; resizing the
        // window there makes sublayers commit out of sync (elements briefly
        // render at stale positions). Defer the resize to the next runloop
        // turn so each frame commits atomically.
        DispatchQueue.main.async { [self] in
            let size = NSSize(width: 360, height: contentHeight)
            if popover.isShown, popover.contentSize != size {
                popover.contentSize = size
            }
        }
    }

    func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Lay out the SwiftUI content first so the popover opens at the
            // right height (the GeometryReader callback fires during layout).
            popover.contentViewController?.view.layoutSubtreeIfNeeded()
            popover.contentSize = NSSize(width: 360, height: contentHeight)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
