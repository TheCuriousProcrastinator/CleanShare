import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Text("State: \(model.sharingStateLabel)")

            Divider()

            if model.isSharing {
                Button("Stop Sharing") {
                    Task { await model.stopSharing() }
                }

                if model.presentationState == .paused {
                    Button("Resume") {
                        model.togglePause()
                    }
                } else if model.presentationState == .live {
                    Button("Pause") {
                        model.togglePause()
                    }
                }

                Button(model.isBlackScreen ? "End Black Screen" : "Black Screen") {
                    model.toggleBlackScreen()
                }
            } else {
                Button("Start Sharing") {
                    model.startSharing()
                }
                .disabled(!model.canStartSharing)
            }

            Button("Change Capture Area") {
                model.selectCaptureArea()
            }
            .disabled(model.displays.isEmpty)

            Divider()

            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }

            Toggle("Launch at Login", isOn: launchAtLoginBinding)

            if model.launchAtLoginState == .requiresApproval {
                Button("Approve Launch at Login…") {
                    model.openLoginItemsSettings()
                }
            }

            if model.launchAtLoginErrorMessage != nil {
                Text("Launch at Login Error — Open Settings for details")
            }

            Divider()

            Button("Quit CleanShare") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            model.refreshDisplays()
            model.refreshLaunchAtLoginState()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginState.isRegistered },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }
}
