import Foundation
import AVFoundation

enum NoiseType: String, CaseIterable, Identifiable {
    case white = "White"
    case pink = "Pink"
    case brown = "Brown"
    case speechBlocker = "Speech Blocker"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .white: return "Flat, crisp"
        case .pink: return "Balanced, natural"
        case .brown: return "Deep, rumbling"
        case .speechBlocker: return "Masks voices"
        }
    }

    // 10-band EQ levels
    // Frequencies: 20Hz, 60Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 17kHz
    var eqLevels: [Float]? {
        switch self {
        case .brown:
            // Exact values from browser
            return [0.614, 0.564, 0.515, 0.466, 0.417, 0.368, 0.331, 0.294, 0.258, 0.221]
        case .speechBlocker:
            return [0.14, 0.22, 0.28, 0.40, 0.46, 0.42, 0.28, 0.21, 0.13, 0.05]
        default:
            return nil
        }
    }

    var usesEqualizer: Bool {
        return eqLevels != nil
    }
}

// Biquad bandpass filter for each frequency band
class BiquadFilter {
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0
    private var a1: Float = 0, a2: Float = 0
    private var x1: Float = 0, x2: Float = 0
    private var y1: Float = 0, y2: Float = 0

    init(frequency: Float, q: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = (sinOmega / 2.0) / a0
        b1 = 0.0
        b2 = (-sinOmega / 2.0) / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    func process(_ input: Float) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        return output
    }

    func reset() {
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
    }
}

// Biquad bandpass filter for speech blocker
class BandPassFilter {
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0
    private var a1: Float = 0, a2: Float = 0
    private var x1: Float = 0, x2: Float = 0
    private var y1: Float = 0, y2: Float = 0
    private var sampleRate: Float

    init(center: Float, q: Float = 1.0, sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        setCenter(center, q: q)
    }

    func setCenter(_ center: Float, q: Float = 1.0) {
        let omega = 2.0 * Float.pi * center / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = alpha / a0
        b1 = 0.0
        b2 = -alpha / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    func process(_ input: Float) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        return output
    }

    func reset() {
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
    }
}

// Biquad low-pass filter for brown noise
class LowPassFilter {
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0
    private var a1: Float = 0, a2: Float = 0
    private var x1: Float = 0, x2: Float = 0
    private var y1: Float = 0, y2: Float = 0
    private var sampleRate: Float

    init(cutoff: Float, q: Float = 0.707, sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        setCutoff(cutoff, q: q)
    }

    func setCutoff(_ cutoff: Float, q: Float = 0.707) {
        let omega = 2.0 * Float.pi * cutoff / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = ((1.0 - cosOmega) / 2.0) / a0
        b1 = (1.0 - cosOmega) / a0
        b2 = ((1.0 - cosOmega) / 2.0) / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    func process(_ input: Float) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        return output
    }

    func reset() {
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
    }
}

class NoiseGenerator {
    private var pinkState: [Float] = [0, 0, 0, 0, 0, 0, 0]
    private var brownState: Float = 0

    // 10-band equalizer filters
    private var bandFilters: [BiquadFilter] = []
    let frequencies: [Float] = [20, 60, 125, 250, 500, 1000, 2000, 4000, 8000, 17000]
    private let sampleRate: Float = 44100

    // Custom EQ levels for tuning
    var customLevels: [Float] = [0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15]

    // Low-pass filter for brown noise
    private var brownLowPass: LowPassFilter
    var brownCutoff: Float = 500 {
        didSet {
            brownLowPass.setCutoff(brownCutoff)
        }
    }

    // Bandpass filter for speech blocker
    private var speechBandPass: BandPassFilter
    var speechCenter: Float = 200 {
        didSet {
            speechBandPass.setCenter(speechCenter, q: speechQ)
        }
    }
    var speechQ: Float = 1.82 {
        didSet {
            speechBandPass.setCenter(speechCenter, q: speechQ)
        }
    }

    init() {
        brownLowPass = LowPassFilter(cutoff: 500, sampleRate: sampleRate)
        speechBandPass = BandPassFilter(center: 200, q: 1.82, sampleRate: sampleRate)
        setupFilters()
    }

    private func setupFilters() {
        // Q factor for bandpass - lower Q = wider band
        // Very wide bands for smooth, flat coverage
        let qFactors: [Float] = [0.3, 0.3, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.3, 0.3]

        bandFilters = zip(frequencies, qFactors).map { freq, q in
            BiquadFilter(frequency: freq, q: q, sampleRate: sampleRate)
        }
    }

    func reset() {
        pinkState = [0, 0, 0, 0, 0, 0, 0]
        brownState = 0
        bandFilters.forEach { $0.reset() }
        brownLowPass.reset()
        speechBandPass.reset()
    }

    func generateSample(type: NoiseType, useCustomLevels: Bool = false) -> Float {
        switch type {
        case .white:
            return generateWhiteNoise()
        case .pink:
            return generatePinkNoise()
        case .brown:
            return generateBrownNoise()
        case .speechBlocker:
            return generateSpeechBlocker()
        }
    }

    // Speech blocker: pink noise shaped by 10-band EQ
    // Uses pink noise base for softer sound
    private func generateSpeechBlocker() -> Float {
        // Flattened EQ curve - boost outer bands for wider, fuller sound
        // Frequencies: 20Hz, 60Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 17kHz
        let speechLevels: [Float] = [0.08, 0.12, 0.16, 0.20, 0.22, 0.20, 0.16, 0.12, 0.08, 0.04]
        return generateEqualizedNoise(levels: speechLevels, usePinkBase: true) * 3.0
    }

    // Brown noise: integrated white noise with low-pass filter
    private func generateBrownNoise() -> Float {
        let white = Float.random(in: -1...1)
        // Integrate white noise (random walk)
        brownState = brownState + (0.02 * white)
        // Leaky integrator to prevent DC drift
        brownState = brownState * 0.998
        // Apply low-pass filter to cut highs
        let filtered = brownLowPass.process(brownState)
        return filtered * 2.5
    }

    // Generate noise shaped by 10-band EQ
    private func generateEqualizedNoise(levels: [Float], usePinkBase: Bool = false, useBrownBase: Bool = false, source: Float? = nil) -> Float {
        let noiseSource: Float
        if let source = source {
            noiseSource = source
        } else if useBrownBase {
            noiseSource = generateBrownNoise()
        } else if usePinkBase {
            noiseSource = generatePinkNoise()
        } else {
            noiseSource = Float.random(in: -1...1)
        }

        var output: Float = 0
        for (i, filter) in bandFilters.enumerated() {
            let filtered = filter.process(noiseSource)
            output += filtered * levels[i]
        }

        // Normalize output - the mixing can get loud
        return output * 0.8
    }

    // White noise: random values with flat frequency spectrum
    private func generateWhiteNoise() -> Float {
        return Float.random(in: -1...1)
    }

    // Pink noise: 1/f spectrum using Paul Kellet's refined method
    private func generatePinkNoise() -> Float {
        let white = Float.random(in: -1...1)

        pinkState[0] = 0.99886 * pinkState[0] + white * 0.0555179
        pinkState[1] = 0.99332 * pinkState[1] + white * 0.0750759
        pinkState[2] = 0.96900 * pinkState[2] + white * 0.1538520
        pinkState[3] = 0.86650 * pinkState[3] + white * 0.3104856
        pinkState[4] = 0.55000 * pinkState[4] + white * 0.5329522
        pinkState[5] = -0.7616 * pinkState[5] - white * 0.0168980

        let pink = pinkState[0] + pinkState[1] + pinkState[2] + pinkState[3] + pinkState[4] + pinkState[5] + pinkState[6] + white * 0.5362
        pinkState[6] = white * 0.115926

        return pink * 0.11
    }
}
