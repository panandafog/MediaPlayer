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
    @StateObject private var library = MusicLibraryViewModel()
#if os(macOS)
    @StateObject private var mainWindowNavigation = MainWindowNavigation()
#endif

    var body: some Scene {
#if os(macOS)
        Window("Media Player", id: MainWindowNavigation.windowID) {
            ContentView(
                player: player,
                library: library,
                mainWindowNavigation: mainWindowNavigation
            )
            .frame(minWidth: 300, minHeight: 300)
        }
        .windowResizability(.contentMinSize)

        Window("Player", id: PlayerWindow.id) {
            PlayerWindow(
                player: player,
                library: library,
                mainWindowNavigation: mainWindowNavigation
            )
            .windowFullScreenBehavior(.enabled)
        }
        .defaultSize(width: 380, height: 560)
        .windowResizability(.contentMinSize)

        Settings {
            PlayerSettingsView()
        }
#else
        WindowGroup {
            ContentView(player: player, library: library)
        }
#endif
    }
}
