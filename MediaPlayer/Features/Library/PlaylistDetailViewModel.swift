//
//  PlaylistDetailViewModel.swift
//  MediaPlayer
//
//  Created by Codex on 01.06.2026.
//

import Combine
import Foundation
import MusicKit
import OSLog

@MainActor
final class PlaylistDetailViewModel: ObservableObject {
    @Published private(set) var songs: [Song] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let playlist: Playlist
    private let service: any MusicLibraryLoading
    private var hasLoaded = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PlayerApp",
        category: "Playlist"
    )

    init(
        playlist: Playlist,
        service: any MusicLibraryLoading = MusicKitLibraryService()
    ) {
        self.playlist = playlist
        self.service = service
    }

    func load() async {
        guard !hasLoaded else {
            return
        }

        await reload()
    }

    func reload() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            songs = try await service.fetchSongs(in: playlist)
            hasLoaded = true
        } catch {
            logger.error("Could not load playlist. \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not load this playlist."
        }
    }
}
