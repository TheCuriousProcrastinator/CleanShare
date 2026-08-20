import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable

    var isRegistered: Bool {
        self == .enabled || self == .requiresApproval
    }

    var description: String {
        switch self {
        case .notRegistered:
            "CleanShare will not open automatically when you log in."
        case .enabled:
            "CleanShare will open automatically when you log in."
        case .requiresApproval:
            "CleanShare is registered, but requires approval in System Settings."
        case .unavailable:
            "Launch at Login is unavailable for this copy of CleanShare."
        }
    }
}

@MainActor
final class LaunchAtLoginManager {
    private let service = SMAppService.mainApp

    var state: LaunchAtLoginState {
        switch service.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard !state.isRegistered else { return }
            try service.register()
        } else {
            guard state.isRegistered else { return }
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
