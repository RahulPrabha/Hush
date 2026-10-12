import Foundation
import Combine
import ServiceManagement

/// The slice of `SMAppService` that launch-at-login needs, so tests can
/// substitute a fake for the real login-item registration.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// What the "Launch at login" setting shows, derived from the system's
/// login-item status rather than a stored preference.
enum LaunchAtLoginState: Equatable {
    case off
    case on
    /// Registered, but the user must allow it in System Settings >
    /// General > Login Items before it takes effect.
    case requiresApproval

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled: self = .on
        case .requiresApproval: self = .requiresApproval
        case .notRegistered, .notFound: self = .off
        @unknown default: self = .off
        }
    }

    /// Whether the toggle reads as switched on. A pending approval counts:
    /// the user asked for it, and switching off withdraws the request.
    var isOn: Bool { self != .off }
}

/// Registers Hush as a login item via `SMAppService.mainApp`, which works in
/// the App Store sandbox without a helper app or LaunchAgent plist.
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var state: LaunchAtLoginState
    /// The last register/unregister failure, cleared whenever the system
    /// state is re-read.
    @Published private(set) var error: String?

    private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        self.state = LaunchAtLoginState(service.status)
    }

    /// Re-reads the system state; the user can change it in System Settings
    /// at any time.
    func refresh() {
        state = LaunchAtLoginState(service.status)
        error = nil
    }

    func setEnabled(_ enabled: Bool) {
        var failure: String?
        do {
            if enabled {
                try service.register()
            } else if LaunchAtLoginState(service.status) != .off {
                try service.unregister()
            }
        } catch {
            failure = error.localizedDescription
        }
        refresh()
        error = failure
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
