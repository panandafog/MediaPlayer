//
//  MusicLibraryService.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit

protocol MusicLibraryLoading {
    @MainActor
    func fetchSongs() async throws -> [Song]
}

struct MusicKitLibraryService: MusicLibraryLoading {
    nonisolated init() {}

    @MainActor
    func fetchSongs() async throws -> [Song] {
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
}
