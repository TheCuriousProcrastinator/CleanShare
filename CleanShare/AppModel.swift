import AppKit
import Combine
import CoreGraphics

@MainActor
final class AppModel: ObservableObject {
    enum PermissionState {
        case granted
        case required
    }

    enum PresentationState: String {
        case live = "Live"
        case paused = "Paused"
        case blackScreen = "Black Screen"
    }

    @Published private(set) var configuration: CaptureConfiguration?
    @Published private(set) var displays: [DisplayDescriptor] = []
    @Published var selectedDisplayUUID = ""
    @Published private(set) var isSharing = false
    @Published private(set) var permissionState: PermissionState = .required
    @Published private(set) var isPaused = false
    @Published private(set) var isBlackScreen = false
    @Published private(set) var panicShortcut = GlobalHotKey.default
    @Published var statusMessage: String?

    private let store = CaptureConfigurationStore()
    private let selectionController = RegionSelectionController()
    private let captureManager = ScreenCaptureManager()
    private let outputController = OutputWindowController()
    private let hotKeyStore = GlobalHotKeyStore()
    private let hotKeyManager = GlobalHotKeyManager()
    private var captureGeneration = 0

    init() {
        configuration = store.load()
        panicShortcut = hotKeyStore.load() ?? .default
        refreshDisplays()
        refreshPermissionState()

        captureManager.onFrame = { [weak outputController] sampleBuffer in
            outputController?.enqueue(sampleBuffer)
        }
        captureManager.onStreamError = { [weak self] error in
            guard let self else { return }
            self.isSharing = false
            self.resetPresentationState()
            self.outputController.close()
            self.statusMessage = "Capture stopped: \(error.localizedDescription)"
        }
        outputController.onUserClose = { [weak self] in
            Task { await self?.stopSharing(closeOutput: false) }
        }
        hotKeyManager.onPressed = { [weak self] in
            self?.toggleBlackScreen()
        }
        do {
            try hotKeyManager.register(panicShortcut)
        } catch {
            statusMessage = "The panic hotkey could not be registered: \(error.localizedDescription)"
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

    var presentationState: PresentationState {
        if isBlackScreen { return .blackScreen }
        if isPaused { return .paused }
        return .live
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
        resetPresentationState()
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
        resetPresentationState()
        if closeOutput {
            outputController.close()
        }
        statusMessage = "Sharing stopped."
    }

    func toggleBlackScreen() {
        guard isSharing else { return }
        if isBlackScreen {
            isBlackScreen = false
            isPaused = false
        } else {
            isBlackScreen = true
        }
        applyPresentationState()
        statusMessage = isBlackScreen
            ? "CleanShare Output is black."
            : (isPaused ? "CleanShare Output is paused." : "CleanShare Output is live.")
    }

    func togglePause() {
        guard isSharing, !isBlackScreen else { return }
        isPaused.toggle()
        applyPresentationState()
        statusMessage = isPaused
            ? "CleanShare Output is paused on the last captured frame."
            : "CleanShare Output is live."
    }

    @discardableResult
    func changePanicShortcut(to shortcut: GlobalHotKey) -> Bool {
        guard shortcut.isValid else { return false }
        guard shortcut != panicShortcut else { return true }
        do {
            try hotKeyManager.register(shortcut)
            panicShortcut = shortcut
            hotKeyStore.save(shortcut)
            statusMessage = "Panic hotkey changed to \(shortcut.displayString)."
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    func resetPanicShortcut() {
        _ = changePanicShortcut(to: .default)
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

    private func applyPresentationState() {
        outputController.updatePresentation(
            isPaused: isPaused,
            isBlackScreen: isBlackScreen
        )
    }

    private func resetPresentationState() {
        isPaused = false
        isBlackScreen = false
        applyPresentationState()
    }
}
