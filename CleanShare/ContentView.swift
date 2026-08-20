//
//  ContentView.swift
//  CleanShare
//
//  Created by Alex on 8/20/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CleanShare")
                    .font(.largeTitle.weight(.semibold))
                Text("Mirror a fixed region of a display into a shareable window.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            if model.displays.count > 1 {
                Picker("Display", selection: $model.selectedDisplayUUID) {
                    ForEach(model.displays) { display in
                        Text("\(display.name) — \(display.detail)")
                            .tag(display.uuid)
                    }
                }
            }

            if let configuration = model.configuration {
                captureDetails(configuration)

                HStack {
                    Button("Start Sharing") {
                        model.startSharing()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isSharing || !model.isSavedDisplayAvailable)

                    if model.isSharing {
                        Button("Stop Sharing") {
                            Task { await model.stopSharing() }
                        }
                    }

                    Button("Change Capture Area") {
                        model.selectCaptureArea()
                    }
                }

                outputControls
            } else {
                Button("Select Capture Area") {
                    model.selectCaptureArea()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.displays.isEmpty)
            }

            GroupBox("Black Screen Panic Hotkey") {
                PanicHotKeyControls()
            }

            if model.permissionState == .required {
                permissionNotice
            }

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 520)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshDisplays()
            model.refreshPermissionState()
            model.refreshLaunchAtLoginState()
        }
    }

    private var outputControls: some View {
        GroupBox("CleanShare Output") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(outputStateColor)
                        .frame(width: 10, height: 10)
                    Text(model.isSharing ? model.presentationState.rawValue : "Not Sharing")
                        .font(.headline)
                }

                HStack {
                    Button(model.isBlackScreen ? "End Black Screen" : "Black Screen") {
                        model.toggleBlackScreen()
                    }
                    .disabled(!model.isSharing)

                    Button(model.isPaused ? "Resume" : "Pause") {
                        model.togglePause()
                    }
                    .disabled(!model.isSharing || model.isBlackScreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var outputStateColor: Color {
        guard model.isSharing else { return .secondary }
        switch model.presentationState {
        case .live: return Color.green
        case .paused: return Color.orange
        case .blackScreen: return Color.red
        }
    }

    @ViewBuilder
    private func captureDetails(_ configuration: CaptureConfiguration) -> some View {
        GroupBox("Saved Capture Area") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Display")
                        .foregroundStyle(.secondary)
                    Text(model.savedDisplay?.name ?? configuration.displayName)
                }
                GridRow {
                    Text("Region")
                        .foregroundStyle(.secondary)
                    if let display = model.savedDisplay {
                        let rect = configuration.sourceRect(for: display)
                        Text("\(Int(rect.width)) × \(Int(rect.height)) points at (\(Int(rect.minX)), \(Int(rect.minY)))")
                    } else {
                        Text("Unavailable — display is disconnected")
                            .foregroundStyle(.red)
                    }
                }
                GridRow {
                    Text("Coordinates")
                        .foregroundStyle(.secondary)
                    Text("Fixed to the display")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var permissionNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "rectangle.inset.filled.and.person.filled")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Screen Recording Permission")
                    .font(.headline)
                Text("macOS must allow CleanShare to capture the selected display region. You will be prompted when sharing starts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open Screen Recording Settings") {
                    model.openScreenRecordingSettings()
                }
            }
        }
        .padding(12)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}
