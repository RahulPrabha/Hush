import SwiftUI

func formatFreq(_ freq: Float) -> String {
    if freq >= 1000 {
        return String(format: "%.0fk", freq / 1000)
    }
    return String(format: "%.0f", freq)
}

struct ContentView: View {
    @ObservedObject var audioEngine: AudioEngine
    @AppStorage("selectedNoiseType") private var selectedNoiseType = "White"
    @AppStorage("savedVolume") private var savedVolume = 0.5

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("White Noise")
                    .font(.headline)
                Spacer()
                Text(audioEngine.isPlaying ? "Playing" : "Stopped")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Noise Type Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Noise Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Noise Type", selection: $audioEngine.noiseType) {
                    ForEach(NoiseType.allCases) { type in
                        HStack {
                            Text(type.rawValue)
                            Text("- \(type.description)")
                                .foregroundColor(.secondary)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Divider()

            // Cutoff control for Brown noise
            if audioEngine.noiseType == .brown {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Low-Pass Cutoff")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(audioEngine.brownCutoff)) Hz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    HStack(spacing: 8) {
                        Text("20")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Slider(value: Binding(
                            get: { Double(audioEngine.brownCutoff) },
                            set: { audioEngine.brownCutoff = Float($0) }
                        ), in: 20...500)

                        Text("500")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
            }


            // Volume Control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(audioEngine.volume * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Slider(value: $audioEngine.volume, in: 0...1)
                        .onChange(of: audioEngine.volume) { newValue in
                            savedVolume = Double(newValue)
                        }

                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Divider()

            // Play/Pause Button
            Button(action: { audioEngine.toggle() }) {
                HStack {
                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    Text(audioEngine.isPlaying ? "Pause" : "Play")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])

            // Keyboard Shortcut Info
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.secondary)
                Text("Global shortcut:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Cmd + Shift + W")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }

            Divider()

            // Quit Button
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            // Restore saved preferences
            if let type = NoiseType(rawValue: selectedNoiseType) {
                audioEngine.noiseType = type
            }
            audioEngine.volume = Float(savedVolume)
        }
        .onChange(of: audioEngine.noiseType) { newType in
            selectedNoiseType = newType.rawValue
        }
    }
}
