//
//  NowPlayingFullScreenView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

#if os(iOS)
import MusicKit
import SwiftUI

struct NowPlayingFullScreenView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var player: MusicPlayerViewModel
    @ObservedObject var library: MusicLibraryViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            NowPlayingView(
                player: player,
                onOpenArtist: openArtist,
                onOpenAlbum: openAlbum
            )
                .toolbar {
                    if navigationPath.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: dismiss.callAsFunction) {
                                Label("Back", systemImage: "chevron.left")
                            }
                        }
                    }
                }
                .navigationDestination(for: LibraryNavigationDestination.self) { destination in
                    LibraryNavigationDestinationView(
                        destination: destination,
                        library: library,
                        currentSongState: player.currentSongState,
                        onPlay: play
                    )
                }
        }
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

        navigationPath.append(LibraryNavigationDestination.artist(artist.id))
    }

    private func openAlbum(for song: Song) {
        guard let album = library.album(containing: song) else {
            return
        }

        navigationPath.append(LibraryNavigationDestination.album(album.id))
    }
}
#endif
