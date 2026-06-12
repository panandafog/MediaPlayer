//
//  MusicLibraryViewModel.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Combine
import Foundation
import MusicKit
import OSLog

@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published private(set) var authorizationStatus = MusicAuthorization.currentStatus
    @Published private(set) var songs: [Song] = []
    @Published private(set) var filteredSongs: [Song] = []
    @Published private(set) var filteredArtists: [LibraryArtist] = []
    @Published private(set) var filteredAlbums: [LibraryAlbum] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var filteredPlaylists: [Playlist] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            refreshFilteredContent(debounce: true)
        }
    }
    @Published var sortOption: MusicLibrarySortOption = .title {
        didSet {
            refreshFilteredContent()
        }
    }
    @Published var section: MusicLibrarySection = .songs

    private let service: any MusicLibraryLoading
    private var songsBySortOption: [MusicLibrarySortOption: [Song]] = [:]
    private var artists: [LibraryArtist] = []
    private var albums: [LibraryAlbum] = []
    private var filteringTask: Task<Void, Never>?
    private var hasLoadedLibrary = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PlayerApp",
        category: "MusicLibrary"
    )

    init(service: any MusicLibraryLoading = MusicKitLibraryService()) {
        self.service = service
    }

    var sortedSongs: [Song] {
        songsBySortOption[sortOption] ?? []
    }

    var isEmpty: Bool {
        songs.isEmpty && playlists.isEmpty
    }

    private func refreshFilteredContent(debounce: Bool = false) {
        filteringTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            filteredSongs = sortedSongs
            filteredArtists = artists
            filteredAlbums = albums
            filteredPlaylists = playlists
            return
        }

        let songs = sortedSongs
        let artists = artists
        let albums = albums
        let playlists = playlists

        filteringTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            guard !Task.isCancelled else {
                return
            }

            let filteredContent = await Task.detached(priority: .userInitiated) {
                MusicLibraryFiltering.filteredContent(
                    query: query,
                    songs: songs,
                    artists: artists,
                    albums: albums,
                    playlists: playlists
                )
            }.value

            guard !Task.isCancelled else {
                return
            }

            self?.applyFilteredContent(filteredContent)
        }
    }

    func loadIfAuthorized() async {
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .authorized else {
            return
        }

        guard !hasLoadedLibrary else {
            return
        }

        await loadLibrary()
    }

    func requestAuthorization() async {
        authorizationStatus = await MusicAuthorization.request()
        guard authorizationStatus == .authorized else {
            return
        }

        await loadLibrary()
    }

    func loadLibrary() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            async let loadedSongs = service.fetchSongs()
            async let loadedPlaylists = service.fetchPlaylists()

            let (songs, playlists) = try await (loadedSongs, loadedPlaylists)
            let content = await Task.detached(priority: .userInitiated) {
                MusicLibraryContent.build(from: songs)
            }.value

            apply(content, songs: songs, playlists: playlists)
            hasLoadedLibrary = true
        } catch {
            report("Could not load your music library.", error: error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func report(_ message: String, error: Error) {
        logger.error("\(message, privacy: .public) \(error.localizedDescription, privacy: .public)")
        errorMessage = message
    }

    private func apply(
        _ content: MusicLibraryContent,
        songs: [Song],
        playlists: [Playlist]
    ) {
        self.songs = songs
        self.playlists = playlists
        songsBySortOption = content.songsBySortOption
        artists = content.artists
        albums = content.albums
        refreshFilteredContent()
    }

    private func applyFilteredContent(_ content: MusicLibraryFilteredContent) {
        filteredSongs = content.songs
        filteredArtists = content.artists
        filteredAlbums = content.albums
        filteredPlaylists = content.playlists
    }
}
