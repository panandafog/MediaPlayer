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
    @Published private(set) var songs: [Song] = [] {
        didSet {
            rebuildLibraryContent()
        }
    }
    @Published private(set) var filteredSongs: [Song] = []
    @Published private(set) var filteredArtists: [LibraryArtist] = []
    @Published private(set) var filteredAlbums: [LibraryAlbum] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            refreshFilteredContent()
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

    private func refreshFilteredContent() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            filteredSongs = sortedSongs
            filteredArtists = artists
            filteredAlbums = albums
            return
        }

        filteredSongs = sortedSongs.filter { song in
            song.title.localizedCaseInsensitiveContains(query)
                || song.artistName.localizedCaseInsensitiveContains(query)
                || song.albumTitle?.localizedCaseInsensitiveContains(query) == true
        }
        filteredArtists = artists.filter { artist in
            artist.name.localizedCaseInsensitiveContains(query)
        }
        filteredAlbums = albums.filter { album in
            album.title.localizedCaseInsensitiveContains(query)
                || album.artistName.localizedCaseInsensitiveContains(query)
        }
    }

    func loadIfAuthorized() async {
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .authorized else {
            return
        }

        await loadSongs()
    }

    func requestAuthorization() async {
        authorizationStatus = await MusicAuthorization.request()
        guard authorizationStatus == .authorized else {
            return
        }

        await loadSongs()
    }

    func loadSongs() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            songs = try await service.fetchSongs()
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

    private func rebuildSortedSongs() {
        songsBySortOption = Dictionary(
            uniqueKeysWithValues: MusicLibrarySortOption.allCases.map { option in
                (option, songs.sorted(by: option.areInIncreasingOrder))
            }
        )
    }

    private func rebuildLibraryContent() {
        rebuildSortedSongs()

        let groups = MusicLibraryGrouping.groups(from: songs)
        artists = groups.artists
        albums = groups.albums

        refreshFilteredContent()
    }
}
