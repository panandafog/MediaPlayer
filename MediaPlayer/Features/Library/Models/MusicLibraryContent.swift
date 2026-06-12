//
//  MusicLibraryContent.swift
//  MediaPlayer
//
//  Created by Codex on 01.06.2026.
//

import Foundation
import MusicKit

nonisolated struct MusicLibraryContent: Sendable {
    let songsBySortOption: [MusicLibrarySortOption: [Song]]
    let artists: [LibraryArtist]
    let albums: [LibraryAlbum]

    static func build(from songs: [Song]) -> Self {
        let songsBySortOption = Dictionary(
            uniqueKeysWithValues: MusicLibrarySortOption.allCases.map { option in
                (option, songs.sorted(by: option.areInIncreasingOrder))
            }
        )
        let groups = MusicLibraryGrouping.groups(from: songs)

        return Self(
            songsBySortOption: songsBySortOption,
            artists: groups.artists,
            albums: groups.albums
        )
    }
}

nonisolated struct MusicLibraryFilteredContent: Sendable {
    let songs: [Song]
    let artists: [LibraryArtist]
    let albums: [LibraryAlbum]
    let playlists: [Playlist]
}

nonisolated enum MusicLibraryFiltering {
    static func filteredContent(
        query: String,
        songs: [Song],
        artists: [LibraryArtist],
        albums: [LibraryAlbum],
        playlists: [Playlist]
    ) -> MusicLibraryFilteredContent {
        MusicLibraryFilteredContent(
            songs: songs.filter { song in
                song.title.localizedCaseInsensitiveContains(query)
                    || song.artistName.localizedCaseInsensitiveContains(query)
                    || song.albumTitle?.localizedCaseInsensitiveContains(query) == true
            },
            artists: artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(query)
            },
            albums: albums.filter { album in
                album.title.localizedCaseInsensitiveContains(query)
                    || album.artistName.localizedCaseInsensitiveContains(query)
            },
            playlists: playlists.filter { playlist in
                playlist.name.localizedCaseInsensitiveContains(query)
                    || playlist.curatorName?.localizedCaseInsensitiveContains(query) == true
            }
        )
    }
}
