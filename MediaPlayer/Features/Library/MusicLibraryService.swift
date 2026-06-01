//
//  MusicLibraryService.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit

protocol MusicLibraryLoading {
    @concurrent func fetchSongs() async throws -> [Song]

    @concurrent func fetchPlaylists() async throws -> [Playlist]

    @concurrent func fetchSongs(in playlist: Playlist) async throws -> [Song]
}

struct MusicKitLibraryService: MusicLibraryLoading {
    nonisolated init() {}

    @concurrent func fetchSongs() async throws -> [Song] {
        let pageSize = 100
        var offset = 0
        var loadedSongs: [Song] = []

        while true {
            var request = MusicLibraryRequest<Song>()
            request.limit = pageSize
            request.offset = offset
            request.sort(by: \.title, ascending: true)

            let response = try await request.response()
            let page = Array(response.items)
            loadedSongs.append(contentsOf: page)

            guard page.count == pageSize else {
                return loadedSongs
            }

            offset += page.count
        }
    }

    @concurrent func fetchPlaylists() async throws -> [Playlist] {
        let pageSize = 100
        var offset = 0
        var loadedPlaylists: [Playlist] = []

        while true {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = pageSize
            request.offset = offset
            request.sort(by: \.name, ascending: true)

            let response = try await request.response()
            let page = Array(response.items)
            loadedPlaylists.append(contentsOf: page)

            guard page.count == pageSize else {
                return loadedPlaylists
            }

            offset += page.count
        }
    }

    @concurrent func fetchSongs(in playlist: Playlist) async throws -> [Song] {
        let playlist = try await playlist.with(.tracks, preferredSource: .library)
        guard var tracks = playlist.tracks else {
            return []
        }

        while tracks.hasNextBatch, let nextBatch = try await tracks.nextBatch() {
            tracks += nextBatch
        }

        return tracks.compactMap(\.song)
    }
}

private extension Track {
    nonisolated var song: Song? {
        guard case let .song(song) = self else {
            return nil
        }

        return song
    }
}
