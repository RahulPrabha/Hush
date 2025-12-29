import SwiftUI

@main
struct WhiteNoiseApp: App {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var hotkeyManager = HotkeyManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView(audioEngine: audioEngine)
        } label: {
            Image(systemName: audioEngine.isPlaying ? "waveform" : "waveform.slash")
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // Setup hotkey after a brief delay to ensure audioEngine is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            hotkeyManager.onToggle = { [weak audioEngine] in
                audioEngine?.toggle()
            }
        }
    }
}
