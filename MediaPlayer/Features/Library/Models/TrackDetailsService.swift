//
//  TrackDetailsService.swift
//  MediaPlayer
//

import MusicKit

struct TrackDetailsService {
    func load(for song: Song) async -> TrackDetails {
        let librarySong = (try? await fetchLibrarySong(id: song.id)) ?? song

        // These requests run only for the opened track, not for every library row.
        async let relatedSong = loadRelationships(for: librarySong)
        async let extendedSong = loadExtendedAttributes(for: librarySong)

        return TrackDetails(
            song: librarySong,
            relatedSong: await relatedSong,
            extendedSong: await extendedSong
        )
    }

    private func fetchLibrarySong(id: MusicItemID) async throws -> Song? {
        var request = MusicLibraryRequest<Song>()
        request.limit = 1
        request.filter(matching: \.id, equalTo: id)
        let response = try await request.response()
        return response.items.first
    }

    private func loadRelationships(for song: Song) async -> Song? {
        try? await song.with(
            .albums, .artists, .genres, .composers, .musicVideos, .station,
            preferredSource: .library
        )
    }

    private func loadExtendedAttributes(for song: Song) async -> Song? {
        try? await song.with(
            .audioVariants,
            preferredSource: .library
        )
    }
}
