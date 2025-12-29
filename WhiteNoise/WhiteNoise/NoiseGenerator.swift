import Foundation
import AVFoundation

enum NoiseType: String, CaseIterable, Identifiable {
    case white = "White"
    case pink = "Pink"
    case brown = "Brown"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .white: return "Flat, crisp"
        case .pink: return "Balanced, natural"
        case .brown: return "Deep, rumbling"
        }
    }
}

class NoiseGenerator {
    private var pinkState: [Float] = [0, 0, 0, 0, 0, 0, 0]
    private var brownState: Float = 0

    func reset() {
        pinkState = [0, 0, 0, 0, 0, 0, 0]
        brownState = 0
    }

    func generateSample(type: NoiseType) -> Float {
        switch type {
        case .white:
            return generateWhiteNoise()
        case .pink:
            return generatePinkNoise()
        case .brown:
            return generateBrownNoise()
        }
    }

    // White noise: random values with flat frequency spectrum
    private func generateWhiteNoise() -> Float {
        return Float.random(in: -1...1)
    }

    // Pink noise: 1/f spectrum using Voss-McCartney algorithm
    private func generatePinkNoise() -> Float {
        let white = Float.random(in: -1...1)

        // Paul Kellet's refined method
        pinkState[0] = 0.99886 * pinkState[0] + white * 0.0555179
        pinkState[1] = 0.99332 * pinkState[1] + white * 0.0750759
        pinkState[2] = 0.96900 * pinkState[2] + white * 0.1538520
        pinkState[3] = 0.86650 * pinkState[3] + white * 0.3104856
        pinkState[4] = 0.55000 * pinkState[4] + white * 0.5329522
        pinkState[5] = -0.7616 * pinkState[5] - white * 0.0168980

        let pink = pinkState[0] + pinkState[1] + pinkState[2] + pinkState[3] + pinkState[4] + pinkState[5] + pinkState[6] + white * 0.5362
        pinkState[6] = white * 0.115926

        return pink * 0.11 // Normalize
    }

    // Brown noise: 1/f^2 spectrum (integrated white noise)
    private func generateBrownNoise() -> Float {
        let white = Float.random(in: -1...1)
        brownState = (brownState + (0.02 * white)) / 1.02
        return brownState * 3.5 // Normalize
    }
}
