import Foundation

/// What the iOS audio session should do in response to a system event.
enum PlaybackSessionAction: Equatable {
    case none
    /// Pause output but remember the user still wants sound, so a later
    /// `resumeIfIntended` can restart it (phone calls, Siri).
    case pauseKeepingIntent
    /// Restart playback only if the user had asked for it.
    case resumeIfIntended
    /// Treat as a user stop (headphones unplugged).
    case stop
}

enum PlaybackInterruption: Equatable {
    case began
    case ended(shouldResume: Bool)
}

enum PlaybackRouteChange: Equatable {
    case oldDeviceUnavailable
    case other
}

enum PlaybackSessionPolicy {
    static func action(for interruption: PlaybackInterruption) -> PlaybackSessionAction {
        switch interruption {
        case .began:
            return .pauseKeepingIntent
        case .ended(let shouldResume):
            return shouldResume ? .resumeIfIntended : .none
        }
    }

    static func action(for routeChange: PlaybackRouteChange) -> PlaybackSessionAction {
        switch routeChange {
        case .oldDeviceUnavailable:
            return .stop
        case .other:
            return .none
        }
    }
}
