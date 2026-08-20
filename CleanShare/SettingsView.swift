import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("General") {
                LaunchAtLoginSettings()
            }

            Section("Black Screen Panic Hotkey") {
                PanicHotKeyControls()
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 300)
        .onAppear {
            model.refreshLaunchAtLoginState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshLaunchAtLoginState()
        }
    }
}

struct PanicHotKeyControls: View {
    @EnvironmentObject private var model: AppModel
    @State private var isChangingShortcut = false

    var body: some View {
        HStack {
            Text(model.panicShortcut.displayString)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            Spacer()

            Button("Change…") {
                isChangingShortcut = true
            }

            Button("Reset to Default") {
                model.resetPanicShortcut()
            }
            .disabled(model.panicShortcut == .default)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isChangingShortcut) {
            ShortcutRecorderSheet(currentShortcut: model.panicShortcut) { shortcut in
                model.changePanicShortcut(to: shortcut)
            }
        }
    }
}

private struct LaunchAtLoginSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at Login", isOn: launchAtLoginBinding)

            Text(model.launchAtLoginState.description)
                .font(.callout)
                .foregroundStyle(
                    model.launchAtLoginState == .requiresApproval ? Color.orange : Color.secondary
                )

            if model.launchAtLoginState == .requiresApproval {
                Button("Open Login Items Settings") {
                    model.openLoginItemsSettings()
                }
            }

            if let errorMessage = model.launchAtLoginErrorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginState.isRegistered },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }
}
