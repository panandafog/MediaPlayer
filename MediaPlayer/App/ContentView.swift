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
    @State private var bottomAccessoryHeight: CGFloat = 0
    @State private var isShowingNowPlaying = false
    @AppStorage(PlayerSettingsKey.smartArtistSeparatorCharacters)
    private var smartArtistSeparatorCharacters =
        SmartArtistGroupingSettings.defaultSeparatorCharacters
    @AppStorage(PlayerSettingsKey.usesSmartArtistGrouping)
    private var usesSmartArtistGrouping = false
    @AppStorage(PlayerSettingsKey.resumesPlaybackOnLaunch)
    private var resumesPlaybackOnLaunch = false
#if os(iOS)
    @State private var isShowingSettings = false
    @State private var pendingNowPlayingDestination: LibraryNavigationDestination?
#endif

    var body: some View {
#if os(iOS)
        GeometryReader { geometry in
            let bottomInset = geometry.safeAreaInsets.bottom
            // A keyboard inset is much larger than the device's bottom edge inset.
            let deviceBottomInset =
                bottomInset < geometry.size.height / 4 ? bottomInset : 0

            content(bottomSafeAreaInset: deviceBottomInset)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height + deviceBottomInset,
                    alignment: .top
                )
        }
#else
        content(bottomSafeAreaInset: 0)
#endif
    }

    private func content(bottomSafeAreaInset: CGFloat) -> some View {
        Group {
#if os(iOS)
            ZStack(alignment: .bottom) {
                navigationContent
                bottomAccessory(bottomSafeAreaInset: bottomSafeAreaInset)
            }
#else
            navigationContent
                .overlay(alignment: .bottom) {
                    bottomAccessory(bottomSafeAreaInset: bottomSafeAreaInset)
                }
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
            updateSmartArtistGrouping()
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
        .onChange(of: usesSmartArtistGrouping) {
            navigationPath.removeAll()
            updateSmartArtistGrouping()
        }
        .onChange(of: smartArtistSeparatorCharacters) {
            navigationPath.removeAll()
            updateSmartArtistGrouping()
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

    private var navigationContent: some View {
        NavigationStack(path: $navigationPath) {
            MusicLibraryView(
                library: library,
                currentSongState: player.currentSongState,
                onPlay: play
            )
            .navigationTitle(library.section.title)
            .toolbar {
#if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    if library.authorizationStatus == .authorized,
                       navigationPath.isEmpty {
                        MacLibrarySearchField(text: $library.searchText)
                            .frame(width: 230)
                    }

                    if library.authorizationStatus == .authorized {
                        libraryMenu
                    }

                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
#else
                if library.authorizationStatus == .authorized {
                    ToolbarItem(placement: .primaryAction) {
                        libraryMenu
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
#endif
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
        .environment(\.playerAccessoryHeight, bottomAccessoryHeight)
#if os(iOS)
        .searchable(
            text: $library.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Track, album, artist, or playlist"
        )
#endif
    }

    private func play(_ song: Song, in queue: [Song]) {
        Task {
            await player.play(song, in: queue)
        }
    }

    private func refreshLibrary() {
        Task {
            await library.loadLibrary()
            await player.restorePlaybackIfNeeded(
                from: library.songs,
                startsPlaying: resumesPlaybackOnLaunch
            )
        }
    }

    private var libraryMenu: some View {
        MusicLibraryMenu(
            section: $library.section,
            sortOption: $library.sortOption,
            isRefreshing: library.isLoading,
            onRefresh: refreshLibrary
        )
    }

    private func loadLibraryAndRestorePlayback() async {
        await library.loadIfAuthorized()
        await player.restorePlaybackIfNeeded(
            from: library.songs,
            startsPlaying: resumesPlaybackOnLaunch
        )
    }

    private func updateSmartArtistGrouping() {
        library.configureSmartArtistGrouping(
            isEnabled: usesSmartArtistGrouping,
            separatorCharacters: smartArtistSeparatorCharacters
        )
    }

    private func openNowPlaying() {
#if os(macOS)
        openWindow(id: PlayerWindow.id)
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

    private func bottomAccessory(bottomSafeAreaInset: CGFloat) -> some View {
        NowPlayingBarContainer(
            player: player,
            bottomSafeAreaInset: bottomSafeAreaInset,
            onOpenDetails: openNowPlaying,
            onOpenArtist: openArtist,
            onOpenAlbum: openAlbum
        )
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.height
        } action: { height in
            bottomAccessoryHeight = height
        }
    }

#if os(iOS)
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
    .environmentObject(ArtworkAccentTheme())
#else
    ContentView(player: MusicPlayerViewModel(), library: MusicLibraryViewModel())
        .environmentObject(ArtworkAccentTheme())
#endif
}
