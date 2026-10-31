//
//  MediaPlayerApp.swift
//  MediaPlayer
//
//  Created by Andrey Pantyuhin on 31.05.2026.
//

import MusicKit
import SwiftUI

@main
struct MediaPlayerApp: App {
    @StateObject private var player = MusicPlayerViewModel()
    @StateObject private var library = MusicLibraryViewModel()
    @StateObject private var artworkAccentTheme = ArtworkAccentTheme()
#if os(macOS)
    @StateObject private var mainWindowNavigation = MainWindowNavigation()
    @StateObject private var artworkDockIcon = ArtworkDockIconController()
    @StateObject private var tagEditor = TagEditorModel()
#endif

    var body: some Scene {
#if os(macOS)
        Window("Trackfold", id: MainWindowNavigation.windowID) {
            AppAccentRoot(player: player, theme: artworkAccentTheme) {
                ContentView(
                    player: player,
                    library: library,
                    mainWindowNavigation: mainWindowNavigation
                )
                .frame(
                    minWidth: AppLayout.mainWindowMinimumSize.width,
                    minHeight: AppLayout.mainWindowMinimumSize.height
                )
            }
            .environmentObject(tagEditor)
            .modifier(ArtworkDockIconObserver(player: player, controller: artworkDockIcon))
        }
        .windowResizability(.contentMinSize)
        .commands { TagEditorCommands(model: tagEditor) }

        Window("Player", id: PlayerWindow.id) {
            AppAccentRoot(
                player: player,
                theme: artworkAccentTheme,
                appliesArtworkTint: false
            ) {
                PlayerWindow(
                    player: player,
                    library: library,
                    mainWindowNavigation: mainWindowNavigation
                )
                .windowFullScreenBehavior(.enabled)
            }
            .environmentObject(tagEditor)
            .modifier(ArtworkDockIconObserver(player: player, controller: artworkDockIcon))
        }
        .defaultSize(
            width: PlayerWindow.idealSize.width,
            height: PlayerWindow.idealSize.height
        )
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)

        Window("Tag Editor", id: TagEditorModel.windowID) {
            AppAccentRoot(player: player, theme: artworkAccentTheme) {
                TagEditorView(model: tagEditor)
            }
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)

        Settings {
            AppAccentRoot(player: player, theme: artworkAccentTheme) {
                PlayerSettingsView()
            }
            .modifier(ArtworkDockIconObserver(player: player, controller: artworkDockIcon))
        }
#else
        WindowGroup {
            AppAccentRoot(player: player, theme: artworkAccentTheme) {
                ContentView(player: player, library: library)
            }
        }
#endif
    }
}

private struct AppAccentRoot<Content: View>: View {
    @ObservedObject var player: MusicPlayerViewModel
    @ObservedObject var theme: ArtworkAccentTheme
    @AppStorage(PlayerSettingsKey.usesArtworkAccentColor)
    private var usesArtworkAccentColor = true

    let appliesArtworkTint: Bool
    let content: Content

    init(
        player: MusicPlayerViewModel,
        theme: ArtworkAccentTheme,
        appliesArtworkTint: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.player = player
        self.theme = theme
        self.appliesArtworkTint = appliesArtworkTint
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(theme)
            .tint(appliesArtworkTint ? theme.color : nil)
            .onChange(of: player.currentSong?.artwork, initial: true) {
                theme.update(
                    for: player.currentSong?.artwork,
                    enabled: usesArtworkAccentColor
                )
            }
            .onChange(of: usesArtworkAccentColor) {
                theme.update(
                    for: player.currentSong?.artwork,
                    enabled: usesArtworkAccentColor
                )
            }
    }
}

#if os(macOS)
private struct TagEditorCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let model: TagEditorModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Tag Editor…") {
                model.open()
                openWindow(id: TagEditorModel.windowID)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

private struct ArtworkDockIconObserver: ViewModifier {
    @ObservedObject var player: MusicPlayerViewModel
    @AppStorage(PlayerSettingsKey.usesArtworkDockIcon)
    private var usesArtworkDockIcon = true

    let controller: ArtworkDockIconController

    func body(content: Content) -> some View {
        content
            .onChange(of: player.currentSong?.artwork, initial: true) {
                controller.update(
                    for: player.currentSong?.artwork,
                    enabled: usesArtworkDockIcon
                )
            }
            .onChange(of: usesArtworkDockIcon) {
                controller.update(
                    for: player.currentSong?.artwork,
                    enabled: usesArtworkDockIcon
                )
            }
    }
}

private enum AppLayout {
    static let mainWindowMinimumSize = CGSize(width: 300, height: 300)
}
#endif
