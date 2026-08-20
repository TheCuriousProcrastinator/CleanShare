import AppKit
import Carbon
import Foundation

struct GlobalHotKey: Codable, Equatable {
    static let `default` = GlobalHotKey(
        keyCode: 11,
        carbonModifiers: UInt32(optionKey | cmdKey),
        keyLabel: "B"
    )

    let keyCode: UInt32
    let carbonModifiers: UInt32
    let keyLabel: String

    var displayString: String {
        var value = ""
        if carbonModifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value + keyLabel
    }

    var isValid: Bool {
        guard !keyLabel.isEmpty else { return false }
        if carbonModifiers != 0 { return true }
        guard keyLabel.first == "F" else { return false }
        return Int(keyLabel.dropFirst()) != nil
    }

    static func from(event: NSEvent) -> GlobalHotKey? {
        guard let label = keyLabel(for: event), !label.isEmpty else { return nil }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }

        let shortcut = GlobalHotKey(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers,
            keyLabel: label
        )
        return shortcut.isValid ? shortcut : nil
    }

    private static func keyLabel(for event: NSEvent) -> String? {
        if let specialKey = specialKeyLabels[event.keyCode] {
            return specialKey
        }

        guard let characters = event.charactersIgnoringModifiers,
              let first = characters.first,
              !first.isNewline,
              !first.isWhitespace else {
            return event.keyCode == 49 ? "Space" : nil
        }
        return String(first).uppercased()
    }

    private static let specialKeyLabels: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        71: "Clear", 76: "Enter", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Forward Delete", 119: "End", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
        97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]
}

struct GlobalHotKeyStore {
    private static let storageKey = "panicHotKey.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> GlobalHotKey? {
        guard let data = defaults.data(forKey: Self.storageKey),
              let shortcut = try? JSONDecoder().decode(GlobalHotKey.self, from: data),
              shortcut.isValid else {
            return nil
        }
        return shortcut
    }

    func save(_ shortcut: GlobalHotKey) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@MainActor
final class GlobalHotKeyManager {
    var onPressed: (() -> Void)?

    nonisolated fileprivate static let signature: OSType = 0x434C5348 // "CLSH"
    nonisolated fileprivate static let identifier: UInt32 = 1

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var handlerInstallationStatus: OSStatus = OSStatus(eventInternalErr)

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        handlerInstallationStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            cleanShareHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func register(_ shortcut: GlobalHotKey) throws {
        guard shortcut.isValid else { throw GlobalHotKeyError.invalidShortcut }
        guard handlerInstallationStatus == noErr else {
            throw GlobalHotKeyError.registrationFailed(handlerInstallationStatus)
        }

        var newHotKey: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyNoOptions),
            &newHotKey
        )
        guard status == noErr, let newHotKey else {
            throw GlobalHotKeyError.registrationFailed(status)
        }

        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = newHotKey
    }

    fileprivate func handlePress() {
        onPressed?()
    }
}

enum GlobalHotKeyError: LocalizedError {
    case invalidShortcut
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            "Choose a shortcut with a modifier key, or use a function key."
        case .registrationFailed:
            "macOS could not register that global shortcut. Try another combination."
        }
    }
}

nonisolated private func cleanShareHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr,
          hotKeyID.signature == GlobalHotKeyManager.signature,
          hotKeyID.id == GlobalHotKeyManager.identifier else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<GlobalHotKeyManager>
        .fromOpaque(userData)
        .takeUnretainedValue()
    Task { @MainActor in
        manager.handlePress()
    }
    return noErr
}
