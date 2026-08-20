import AppKit
import SwiftUI

struct ShortcutRecorderSheet: View {
    let currentShortcut: GlobalHotKey
    let onSave: (GlobalHotKey) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var validationMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard")
                .font(.system(size: 34))
                .foregroundStyle(.tint)

            Text("Press a New Shortcut")
                .font(.title2.weight(.semibold))

            Text("Current shortcut: \(currentShortcut.displayString)\nPress Escape to cancel.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            ShortcutKeyCaptureView(
                onShortcut: { shortcut in
                    if onSave(shortcut) {
                        dismiss()
                    } else {
                        validationMessage = "That shortcut could not be registered. Try another combination."
                    }
                },
                onInvalid: {
                    validationMessage = "Use at least one modifier key. Function keys can be used alone."
                },
                onCancel: { dismiss() }
            )
            .frame(width: 1, height: 1)

            Text(validationMessage ?? "Waiting for keyboard input…")
                .font(.callout)
                .foregroundStyle(validationMessage == nil ? Color.secondary : Color.red)
                .frame(minHeight: 20)

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(28)
        .frame(width: 420, height: 280)
    }
}

private struct ShortcutKeyCaptureView: NSViewRepresentable {
    let onShortcut: (GlobalHotKey) -> Void
    let onInvalid: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        update(nsView)
    }

    private func update(_ view: ShortcutCaptureNSView) {
        view.onShortcut = onShortcut
        view.onInvalid = onInvalid
        view.onCancel = onCancel
    }
}

private final class ShortcutCaptureNSView: NSView {
    var onShortcut: ((GlobalHotKey) -> Void)?
    var onInvalid: (() -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        handle(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        handle(event)
        return true
    }

    private func handle(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        guard let shortcut = GlobalHotKey.from(event: event) else {
            onInvalid?()
            return
        }
        onShortcut?(shortcut)
    }
}
