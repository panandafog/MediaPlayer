//
//  MiniPlayerWindow.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

#if os(macOS)
import MusicKit
import SwiftUI

struct MiniPlayerWindow: View {
    static let id = "mini-player"

    @Environment(\.openWindow) private var openWindow

    @ObservedObject var player: MusicPlayerViewModel
    @ObservedObject var library: MusicLibraryViewModel
    @ObservedObject var mainWindowNavigation: MainWindowNavigation

    var body: some View {
        NavigationStack {
            NowPlayingView(
                player: player,
                onOpenArtist: openArtist,
                onOpenAlbum: openAlbum
            )
        }
            .task {
                await library.loadIfAuthorized()
            }
            .frame(
                minWidth: 320,
                idealWidth: 380,
                maxWidth: 460,
                minHeight: 480,
                idealHeight: 560,
                maxHeight: 680
            )
    }

    private func openArtist(for song: Song) {
        guard let artist = library.artist(containing: song) else {
            return
        }

        open(.artist(artist.id))
    }

    private func openAlbum(for song: Song) {
        guard let album = library.album(containing: song) else {
            return
        }

        open(.album(album.id))
    }

    private func open(_ destination: LibraryNavigationDestination) {
        mainWindowNavigation.open(destination)
        openWindow(id: MainWindowNavigation.windowID)
    }
}
#endif
