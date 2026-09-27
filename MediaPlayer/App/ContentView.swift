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
    @AppStorage(PlayerSettingsKey.searchBarPosition) private var searchBarPosition =
        SearchBarPosition.top.rawValue
    @FocusState private var isBottomSearchFocused: Bool
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
        .playerSearchable(
            text: $library.searchText,
            usesTopSearch: usesTopSearch
        )
#endif
        .overlay(alignment: .bottom) {
            bottomAccessory
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    bottomAccessoryHeight = height
                }
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

#if os(iOS)
    private var usesTopSearch: Bool {
        selectedSearchBarPosition == .top
    }
#endif

    private var bottomAccessory: some View {
        VStack(spacing: 0) {
            NowPlayingBarContainer(
                player: player,
                onOpenDetails: openNowPlaying,
                onOpenArtist: openArtist,
                onOpenAlbum: openAlbum
            )
#if os(iOS)
            if selectedSearchBarPosition == .bottom {
                bottomSearchBar
            }
#endif
        }
#if os(iOS)
        .safeAreaPadding(.bottom)
#endif
    }

#if os(iOS)
    private var selectedSearchBarPosition: SearchBarPosition {
        SearchBarPosition(rawValue: searchBarPosition) ?? .top
    }

    private var bottomSearchBar: some View {
        HStack(spacing: BottomSearchLayout.spacing) {
            HStack(spacing: BottomSearchLayout.spacing) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "Track, album, artist, or playlist",
                    text: $library.searchText
                )
                .focused($isBottomSearchFocused)
                .submitLabel(.search)

                if !library.searchText.isEmpty {
                    Button {
                        library.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Search")
                }
            }
            .padding(.horizontal, BottomSearchLayout.fieldHorizontalPadding)
            .frame(height: BottomSearchLayout.fieldHeight)
            .glassEffect(.regular, in: Capsule())

            if isBottomSearchFocused {
                Button("Cancel") {
                    library.searchText = ""
                    isBottomSearchFocused = false
                }
            }
        }
        .padding(.horizontal, BottomSearchLayout.horizontalPadding)
        .padding(.bottom, BottomSearchLayout.bottomPadding)
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

#if os(iOS)
private enum BottomSearchLayout {
    static let spacing: CGFloat = 8
    static let fieldHorizontalPadding: CGFloat = 12
    static let fieldHeight: CGFloat = 44
    static let horizontalPadding: CGFloat = 10
    static let bottomPadding: CGFloat = 8
}
#endif

#if os(iOS)
private extension View {
    @ViewBuilder
    func playerSearchable(
        text: Binding<String>,
        usesTopSearch: Bool
    ) -> some View {
        if usesTopSearch {
            searchable(
                text: text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Track, album, artist, or playlist"
            )
        } else {
            self
        }
    }
}
#endif

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
