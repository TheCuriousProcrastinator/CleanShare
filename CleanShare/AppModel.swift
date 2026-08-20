import AppKit
import Combine
import CoreGraphics

@MainActor
final class AppModel: ObservableObject {
    enum PermissionState {
        case granted
        case required
    }

    @Published private(set) var configuration: CaptureConfiguration?
    @Published private(set) var displays: [DisplayDescriptor] = []
    @Published var selectedDisplayUUID = ""
    @Published private(set) var isSharing = false
    @Published private(set) var permissionState: PermissionState = .required
    @Published var statusMessage: String?

    private let store = CaptureConfigurationStore()
    private let selectionController = RegionSelectionController()
    private let captureManager = ScreenCaptureManager()
    private let outputController = OutputWindowController()
    private var captureGeneration = 0

    init() {
        configuration = store.load()
        refreshDisplays()
        refreshPermissionState()

        captureManager.onFrame = { [weak outputController] sampleBuffer in
            outputController?.enqueue(sampleBuffer)
        }
        captureManager.onStreamError = { [weak self] error in
            guard let self else { return }
            self.isSharing = false
            self.outputController.close()
            self.statusMessage = "Capture stopped: \(error.localizedDescription)"
        }
        outputController.onUserClose = { [weak self] in
            Task { await self?.stopSharing(closeOutput: false) }
        }
    }

    var savedDisplay: DisplayDescriptor? {
        guard let configuration else { return nil }
        return displays.first { $0.uuid == configuration.displayUUID }
    }

    var selectedDisplay: DisplayDescriptor? {
        displays.first { $0.uuid == selectedDisplayUUID }
    }

    var isSavedDisplayAvailable: Bool {
        configuration == nil || savedDisplay != nil
    }

    func refreshDisplays() {
        displays = DisplayCatalog.connectedDisplays()

        if !displays.contains(where: { $0.uuid == selectedDisplayUUID }) {
            if let configuration,
               displays.contains(where: { $0.uuid == configuration.displayUUID }) {
                selectedDisplayUUID = configuration.displayUUID
            } else {
                selectedDisplayUUID = displays.first?.uuid ?? ""
            }
        }

        if configuration != nil, savedDisplay == nil {
            statusMessage = "The display used by the saved capture area is not connected. Select a new display and choose a new capture area."
        }
    }

    func refreshPermissionState() {
        permissionState = CGPreflightScreenCaptureAccess() ? .granted : .required
    }

    func selectCaptureArea() {
        refreshDisplays()
        guard let display = selectedDisplay, let screen = DisplayCatalog.screen(for: display) else {
            statusMessage = "No usable display is available."
            return
        }

        Task { await stopSharing() }
        selectionController.begin(on: screen) { [weak self] normalizedRect in
            guard let self else { return }
            guard let normalizedRect else {
                self.statusMessage = "Capture-area selection was cancelled."
                return
            }

            let newConfiguration = CaptureConfiguration(
                display: display,
                normalizedRect: normalizedRect
            )
            self.configuration = newConfiguration
            self.store.save(newConfiguration)
            self.statusMessage = "Capture area saved."
        }
    }

    func startSharing() {
        guard !isSharing else { return }
        refreshDisplays()
        guard let configuration, let display = savedDisplay else {
            statusMessage = "The saved display is unavailable. Choose a new capture area."
            return
        }

        guard ensureScreenRecordingPermission() else { return }

        let sourceRect = configuration.sourceRect(for: display)
        outputController.show(aspectRatio: sourceRect.width / sourceRect.height)
        captureGeneration += 1
        let generation = captureGeneration
        isSharing = true
        statusMessage = "Starting capture…"

        Task {
            do {
                try await captureManager.start(configuration: configuration, display: display)
                guard generation == captureGeneration else {
                    await captureManager.stop()
                    return
                }
                statusMessage = "Sharing the saved display region in CleanShare Output."
            } catch {
                guard generation == captureGeneration else { return }
                isSharing = false
                outputController.close()
                refreshPermissionState()
                statusMessage = "Could not start capture: \(error.localizedDescription)"
            }
        }
    }

    func stopSharing(closeOutput: Bool = true) async {
        captureGeneration += 1
        await captureManager.stop()
        isSharing = false
        if closeOutput {
            outputController.close()
        }
        statusMessage = "Sharing stopped."
    }

    func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func ensureScreenRecordingPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            permissionState = .granted
            return true
        }

        let granted = CGRequestScreenCaptureAccess()
        permissionState = granted ? .granted : .required
        if !granted {
            statusMessage = "Screen Recording permission is required. Allow CleanShare in System Settings, then return to the app and try again. macOS may require the app to be reopened."
        }
        return granted
    }
}
