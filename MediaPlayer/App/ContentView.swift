//
//  ContentView.swift
//  MediaPlayer
//
//  Created by Andrey Pantyuhin on 31.05.2026.
//

import MusicKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
#endif

    @StateObject private var library = MusicLibraryViewModel()
    let player: MusicPlayerViewModel
    @State private var isShowingNowPlaying = false

    var body: some View {
        NavigationStack {
            MusicLibraryView(
                library: library,
                currentSongState: player.currentSongState,
                onPlay: play
            )
            .navigationTitle(library.section.title)
            .searchable(
                text: $library.searchText,
                placement: searchFieldPlacement,
                prompt: "Track, album, artist, or playlist"
            )
            .toolbar {
                if library.authorizationStatus == .authorized {
                    ToolbarItem(placement: .primaryAction) {
                        MusicLibraryMenu(
                            section: $library.section,
                            sortOption: $library.sortOption,
                            isRefreshing: library.isLoading,
                            onRefresh: refreshLibrary
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NowPlayingBarContainer(
                player: player,
                onOpenDetails: openNowPlaying
            )
        }
#if os(iOS)
        .fullScreenCover(isPresented: $isShowingNowPlaying) {
            NowPlayingFullScreenView(player: player)
        }
#endif
        .task {
            await library.loadIfAuthorized()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }

            Task {
                await library.loadIfAuthorized()
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        library.clearError()
                    }
                }
            )
        ) {
            Button("OK", action: library.clearError)
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    private func play(_ song: Song, in queue: [Song]) {
        Task {
            await player.play(song, in: queue)
        }
    }

    private func refreshLibrary() {
        Task {
            await library.loadLibrary()
        }
    }

    private func openNowPlaying() {
#if os(macOS)
        openWindow(id: MiniPlayerWindow.id)
#else
        isShowingNowPlaying = true
#endif
    }

    private var searchFieldPlacement: SearchFieldPlacement {
#if os(iOS)
        .navigationBarDrawer(displayMode: .always)
#else
        .automatic
#endif
    }
}

#Preview {
    ContentView(player: MusicPlayerViewModel())
}
