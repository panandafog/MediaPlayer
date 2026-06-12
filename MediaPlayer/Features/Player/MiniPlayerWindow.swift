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

    @ObservedObject var player: MusicPlayerViewModel
    @ObservedObject var library: MusicLibraryViewModel
    @State private var navigationPath: [LibraryNavigationDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            NowPlayingView(
                player: player,
                onOpenArtist: openArtist,
                onOpenAlbum: openAlbum
            )
            .navigationDestination(for: LibraryNavigationDestination.self) { destination in
                LibraryNavigationDestinationView(
                    destination: destination,
                    library: library,
                    currentSongState: player.currentSongState,
                    onPlay: play
                )
            }
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

    private func play(_ song: Song, in queue: [Song]) {
        Task {
            await player.play(song, in: queue)
        }
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
        guard navigationPath.last != destination else {
            return
        }

        navigationPath.append(destination)
    }
}
#endif
