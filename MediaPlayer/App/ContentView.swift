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
#if os(macOS)
    @ObservedObject var mainWindowNavigation: MainWindowNavigation
#endif
    @State private var navigationPath: [LibraryNavigationDestination] = []
    @State private var isShowingNowPlaying = false
#if os(iOS)
    @AppStorage(PlayerSettingsKey.searchBarPosition) private var searchBarPosition =
        SearchBarPosition.top.rawValue
    @State private var isShowingSettings = false
    @State private var pendingNowPlayingDestination: LibraryNavigationDestination?
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
        .sheet(
            isPresented: $isShowingNowPlaying,
            onDismiss: openPendingNowPlayingDestination
        ) {
            NowPlayingFullScreenView(
                player: player,
                onOpenArtist: openArtistFromNowPlaying,
                onOpenAlbum: openAlbumFromNowPlaying
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSettings) {
            PlayerSettingsView()
        }
#endif
        .task {
            await loadLibraryAndRestorePlayback()
#if os(macOS)
            openRequestedMainWindowDestination()
#endif
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
#if os(macOS)
        .onChange(of: mainWindowNavigation.request) {
            openRequestedMainWindowDestination()
        }
#endif
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

        if let destinationIndex = navigationPath.lastIndex(of: destination) {
            navigationPath.removeSubrange(
                navigationPath.index(after: destinationIndex)..<navigationPath.endIndex
            )
        } else {
            navigationPath.append(destination)
        }
    }

#if os(macOS)
    private func openRequestedMainWindowDestination() {
        guard let request = mainWindowNavigation.request else {
            return
        }

        open(request.destination)
        mainWindowNavigation.consume(request.id)
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

    private func openArtistFromNowPlaying(_ song: Song) {
        guard let artist = library.artist(containing: song) else {
            return
        }

        closeNowPlayingAndOpen(.artist(artist.id))
    }

    private func openAlbumFromNowPlaying(_ song: Song) {
        guard let album = library.album(containing: song) else {
            return
        }

        closeNowPlayingAndOpen(.album(album.id))
    }

    private func closeNowPlayingAndOpen(_ destination: LibraryNavigationDestination) {
        pendingNowPlayingDestination = destination
        isShowingNowPlaying = false
    }

    private func openPendingNowPlayingDestination() {
        guard let destination = pendingNowPlayingDestination else {
            return
        }

        pendingNowPlayingDestination = nil
        open(destination)
    }
#endif
}

#Preview {
#if os(macOS)
    ContentView(
        player: MusicPlayerViewModel(),
        library: MusicLibraryViewModel(),
        mainWindowNavigation: MainWindowNavigation()
    )
#else
    ContentView(player: MusicPlayerViewModel(), library: MusicLibraryViewModel())
#endif
}
