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

    let player: MusicPlayerViewModel
    @ObservedObject var library: MusicLibraryViewModel
    @State private var navigationPath: [LibraryNavigationDestination] = []
    @State private var isShowingNowPlaying = false
#if os(iOS)
    @AppStorage(PlayerSettingsKey.searchBarPosition) private var searchBarPosition =
        SearchBarPosition.top.rawValue
    @State private var isShowingSettings = false
#endif

    var body: some View {
        NavigationStack(path: $navigationPath) {
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

                ToolbarItem(placement: .secondaryAction) {
#if os(macOS)
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                    }
#else
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
#endif
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NowPlayingBarContainer(
                player: player,
                onOpenDetails: openNowPlaying,
                onOpenArtist: openArtist,
                onOpenAlbum: openAlbum
            )
#if os(iOS)
            .padding(.bottom, bottomSearchBarClearance)
#endif
        }
#if os(iOS)
        .fullScreenCover(isPresented: $isShowingNowPlaying) {
            NowPlayingFullScreenView(player: player, library: library)
        }
        .sheet(isPresented: $isShowingSettings) {
            PlayerSettingsView()
        }
#endif
        .task {
            await loadLibraryAndRestorePlayback()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                player.refreshPlaybackState()

                Task {
                    await loadLibraryAndRestorePlayback()
                }
            } else {
                player.savePlaybackPosition()
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
            player.restorePlaybackIfNeeded(from: library.songs)
        }
    }

    private func loadLibraryAndRestorePlayback() async {
        await library.loadIfAuthorized()
        player.restorePlaybackIfNeeded(from: library.songs)
    }

    private func openNowPlaying() {
#if os(macOS)
        openWindow(id: MiniPlayerWindow.id)
#else
        isShowingNowPlaying = true
#endif
    }

    private func openArtist(for song: Song) {
#if os(macOS)
        guard let artist = library.artist(containing: song) else {
            return
        }

        open(.artist(artist.id))
#endif
    }

    private func openAlbum(for song: Song) {
#if os(macOS)
        guard let album = library.album(containing: song) else {
            return
        }

        open(.album(album.id))
#endif
    }

#if os(macOS)
    private func open(_ destination: LibraryNavigationDestination) {
        guard navigationPath.last != destination else {
            return
        }

        navigationPath.append(destination)
    }
#endif

    private var searchFieldPlacement: SearchFieldPlacement {
#if os(iOS)
        selectedSearchBarPosition == .top
            ? .navigationBarDrawer(displayMode: .always)
            : .automatic
#else
        .automatic
#endif
    }

#if os(iOS)
    private var selectedSearchBarPosition: SearchBarPosition {
        SearchBarPosition(rawValue: searchBarPosition) ?? .top
    }

    private var bottomSearchBarClearance: CGFloat {
        selectedSearchBarPosition == .bottom ? 56 : 0
    }
#endif
}

#Preview {
    ContentView(player: MusicPlayerViewModel(), library: MusicLibraryViewModel())
}
