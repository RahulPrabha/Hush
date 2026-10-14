import Foundation
import AVFoundation
import Combine
#if os(iOS)
import MediaPlayer
#endif

class AudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var volume: Float = 0.5 {
        didSet {
            updateVolume()
        }
    }
    @Published var noiseType: NoiseType = .brown {
        didSet {
            // Don't touch generator state here: the render thread may be
            // mid-generateSample. It performs the reset at the next buffer.
            needsGeneratorReset = true
            #if os(iOS)
            updateNowPlaying()
            #endif
        }
    }
    private var needsGeneratorReset = false

    // Custom EQ controls
    @Published var useCustomEQ = true
    @Published var eqLevels: [Float] = [0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15] {
        didSet {
            noiseGeneratorL.customLevels = eqLevels
            noiseGeneratorR.customLevels = eqLevels
        }
    }

    // Brown noise cutoff frequency (Hz)
    @Published var brownCutoff: Float = 500 {
        didSet {
            noiseGeneratorL.brownCutoff = brownCutoff
            noiseGeneratorR.brownCutoff = brownCutoff
        }
    }

    // Speech blocker center frequency and Q
    @Published var speechCenter: Float = 200 {
        didSet {
            noiseGeneratorL.speechCenter = speechCenter
            noiseGeneratorR.speechCenter = speechCenter
        }
    }
    @Published var speechQ: Float = 1.82 {
        didSet {
            noiseGeneratorL.speechQ = speechQ
            noiseGeneratorR.speechQ = speechQ
        }
    }

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    let noiseGeneratorL = NoiseGenerator()  // Left channel
    let noiseGeneratorR = NoiseGenerator()  // Right channel

    var frequencies: [Float] { noiseGeneratorL.frequencies }

    private var fadeLevel: Float = 0
    private let fadeSpeed: Float = 0.0005
    private var shouldBePlaying = false  // Track user intent separately from engine state

    init() {
        setupNotifications()
        #if os(iOS)
        setupAudioSession()
        setupRemoteCommands()
        updateNowPlaying()
        #endif
    }

    private func setupNotifications() {
        // Listen for audio configuration changes (device changes, sample rate changes, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: nil
        )
    }

    @objc private func handleConfigurationChange(_ notification: Notification) {
        // Audio configuration changed (e.g., AirPods switched to mic mode, device changed)
        // Restart the engine to adapt to new sample rate
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.shouldBePlaying else { return }
            #if os(iOS)
            guard self.isPlaying else { return }
            #endif
            self.restartAudioEngine()
        }
    }

    private func restartAudioEngine() {
        // Clean up old engine
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        fadeLevel = 0

        // Restart after a brief delay to let the system settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.shouldBePlaying else { return }
            self.startEngine()
        }
    }

    func toggle() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    func play() {
        #if os(iOS)
        shouldBePlaying = true
        if audioEngine == nil {
            startEngine()
        } else {
            isPlaying = true
            updateNowPlaying()
        }
        #else
        guard !shouldBePlaying else { return }
        shouldBePlaying = true
        startEngine()
        #endif
    }

    private func startEngine() {
        guard shouldBePlaying else { return }

        do {
            #if os(iOS)
            try activateSession()
            #endif

            let engine = AVAudioEngine()

            // Use the hardware's actual sample rate to avoid pitch issues when audio config changes
            let hardwareSampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let sampleRate = hardwareSampleRate > 0 ? hardwareSampleRate : 44100

            // Update noise generators with current sample rate
            noiseGeneratorL.sampleRate = Float(sampleRate)
            noiseGeneratorR.sampleRate = Float(sampleRate)

            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

            let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self else { return noErr }

                if self.needsGeneratorReset {
                    self.needsGeneratorReset = false
                    self.noiseGeneratorL.reset()
                    self.noiseGeneratorR.reset()
                }

                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

                // Get left and right channel buffers
                let leftBuf = ablPointer.count > 0 ? ablPointer[0].mData?.assumingMemoryBound(to: Float.self) : nil
                let rightBuf = ablPointer.count > 1 ? ablPointer[1].mData?.assumingMemoryBound(to: Float.self) : nil

                for frame in 0..<Int(frameCount) {
                    // Fade in/out for smooth transitions
                    if self.isPlaying && self.fadeLevel < 1 {
                        self.fadeLevel = min(1, self.fadeLevel + self.fadeSpeed)
                    } else if !self.isPlaying && self.fadeLevel > 0 {
                        self.fadeLevel = max(0, self.fadeLevel - self.fadeSpeed)
                    }

                    // Generate independent samples for true stereo
                    let sampleL = self.noiseGeneratorL.generateSample(type: self.noiseType, useCustomLevels: self.useCustomEQ)
                    let sampleR = self.noiseGeneratorR.generateSample(type: self.noiseType, useCustomLevels: self.useCustomEQ)

                    let gain = self.volume * self.fadeLevel
                    leftBuf?[frame] = sampleL * gain
                    rightBuf?[frame] = sampleR * gain
                }

                return noErr
            }

            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)

            noiseGeneratorL.reset()
            noiseGeneratorR.reset()

            try engine.start()

            self.audioEngine = engine
            self.sourceNode = source
            self.isPlaying = true
            #if os(iOS)
            updateNowPlaying()
            #endif

        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        shouldBePlaying = false
        isPlaying = false
        #if os(iOS)
        updateNowPlaying()
        #endif

        // Allow fade out before stopping
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            #if os(iOS)
            guard !self.shouldBePlaying else { return }
            #endif
            self.audioEngine?.stop()
            self.audioEngine = nil
            self.sourceNode = nil
            self.fadeLevel = 0
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }

    private func updateVolume() {
        // Volume is applied in the render callback
    }

    deinit {
        audioEngine?.stop()
        NotificationCenter.default.removeObserver(self)
        #if os(iOS)
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        #endif
    }

    #if os(iOS)
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggle()
            return .success
        }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: noiseType.displayName,
            MPMediaItemPropertyArtist: "Hush",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
    }

    private func apply(_ action: PlaybackSessionAction) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch action {
            case .none:
                break
            case .pauseKeepingIntent:
                self.pauseKeepingIntent()
            case .resumeIfIntended:
                guard self.shouldBePlaying else { return }
                if self.audioEngine == nil {
                    self.startEngine()
                }
            case .stop:
                self.stop()
            }
        }
    }

    private func pauseKeepingIntent() {
        isPlaying = false
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        fadeLevel = 0
        updateNowPlaying()
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        let interruption: PlaybackInterruption
        switch type {
        case .began:
            interruption = .began
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            interruption = .ended(shouldResume: options.contains(.shouldResume))
        @unknown default:
            return
        }
        apply(PlaybackSessionPolicy.action(for: interruption))
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        let change: PlaybackRouteChange = reason == .oldDeviceUnavailable ? .oldDeviceUnavailable : .other
        apply(PlaybackSessionPolicy.action(for: change))
    }
    #endif
}
