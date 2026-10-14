import SwiftUI

@main
struct HushApp: App {
    @StateObject private var audioEngine = AudioEngine()

    var body: some Scene {
        WindowGroup {
            ContentView(audioEngine: audioEngine)
        }
    }
}
