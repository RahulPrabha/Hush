import Foundation

/// The hardware-facing half of playback: something that can be started and
/// stopped and can say whether it is really producing output.
protocol PlaybackBackend: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop()
}

/// Owns the play/stop lifecycle so the user-visible "playing" state can never
/// disagree with the backend.
///
/// `isPlaying` is not a flag toggled by `play()` and `stop()`: it is derived
/// from what the user wants and whether the backend is really running.
/// Stopping fades out for `fadeOutDelay` before the backend is torn down; any
/// later `play()`, `stop()`, `restart()` or `suspend()` supersedes that
/// pending teardown, so it can never halt an output the user has since
/// started again.
final class PlaybackCoordinator {
    static let fadeOutDelay: TimeInterval = 0.3

    /// Called on the calling thread whenever `isPlaying` changes.
    var onChange: ((Bool) -> Void)?

    private(set) var isPlaying = false
    /// What the user last asked for, independent of the backend.
    private(set) var wantsPlayback = false

    private let backend: PlaybackBackend
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    /// Bumped by every lifecycle call; delayed work only runs if it still
    /// holds the latest value.
    private var generation = 0
    /// True between a restart tearing the backend down and bringing it back.
    private var isRestarting = false

    init(
        backend: PlaybackBackend,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.backend = backend
        self.schedule = schedule
    }

    func toggle() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    func play() {
        wantsPlayback = true
        generation += 1
        isRestarting = false
        startBackendIfNeeded()
        refresh()
    }

    func stop() {
        wantsPlayback = false
        isRestarting = false
        generation += 1
        let token = generation
        refresh()

        // Let the render callback fade out before the output goes away.
        schedule(Self.fadeOutDelay) { [weak self] in
            guard let self, self.generation == token else { return }
            self.backend.stop()
            self.refresh()
        }
    }

    /// The output changed underneath us (device or sample-rate change):
    /// rebuild it after a brief settle, if the user still wants sound.
    func restart() {
        guard wantsPlayback else { return }
        generation += 1
        let token = generation
        backend.stop()
        isRestarting = true
        refresh()

        schedule(Self.fadeOutDelay) { [weak self] in
            guard let self, self.generation == token else { return }
            self.isRestarting = false
            self.startBackendIfNeeded()
            self.refresh()
        }
    }

    /// Silence the output but remember that the user still wants sound.
    func suspend() {
        generation += 1
        isRestarting = false
        backend.stop()
        refresh()
    }

    /// Bring the output back after a `suspend()`, if the user still wants it.
    func resumeIfIntended() {
        guard wantsPlayback else { return }
        generation += 1
        isRestarting = false
        startBackendIfNeeded()
        refresh()
    }

    private func startBackendIfNeeded() {
        guard !backend.isRunning else { return }
        do {
            try backend.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func refresh() {
        let playing = wantsPlayback && (backend.isRunning || isRestarting)
        guard playing != isPlaying else { return }
        isPlaying = playing
        onChange?(playing)
    }
}
