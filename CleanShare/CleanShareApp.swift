//
//  CleanShareApp.swift
//  CleanShare
//
//  Created by Alex on 8/20/26.
//

import SwiftUI

@main
struct CleanShareApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("CleanShare") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 620, height: 680)

        MenuBarExtra("CleanShare", systemImage: "rectangle.on.rectangle") {
            MenuBarView()
                .environmentObject(model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
