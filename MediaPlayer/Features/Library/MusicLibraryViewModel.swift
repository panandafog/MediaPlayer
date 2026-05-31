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
            rebuildSortedSongs()
            refreshFilteredSongs()
        }
    }
    @Published private(set) var filteredSongs: [Song] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            refreshFilteredSongs()
        }
    }
    @Published var sortOption: MusicLibrarySortOption = .title {
        didSet {
            refreshFilteredSongs()
        }
    }

    private let service: any MusicLibraryLoading
    private var songsBySortOption: [MusicLibrarySortOption: [Song]] = [:]
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

    private func refreshFilteredSongs() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        filteredSongs = query.isEmpty ? sortedSongs : sortedSongs.filter { song in
            song.title.localizedCaseInsensitiveContains(query)
                || song.artistName.localizedCaseInsensitiveContains(query)
                || song.albumTitle?.localizedCaseInsensitiveContains(query) == true
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
}
