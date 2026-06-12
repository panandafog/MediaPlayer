//
//  MediaPlayerApp.swift
//  MediaPlayer
//
//  Created by Andrey Pantyuhin on 31.05.2026.
//

import SwiftUI

@main
struct MediaPlayerApp: App {
    @StateObject private var player = MusicPlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(player: player)
        }

#if os(macOS)
        Window("Mini Player", id: MiniPlayerWindow.id) {
            MiniPlayerWindow(player: player)
        }
        .defaultSize(width: 380, height: 560)
        .windowResizability(.contentSize)

        Settings {
            PlayerSettingsView()
        }
#endif
    }
}
