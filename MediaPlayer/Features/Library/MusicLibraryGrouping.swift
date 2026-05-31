//
//  MusicLibraryGrouping.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Foundation
import MusicKit

struct LibraryArtist: Identifiable {
    let name: String
    let songs: [Song]
    let albums: [LibraryAlbum]

    var id: String {
        name
    }

    var artwork: Artwork? {
        albums.first?.artwork ?? songs.first?.artwork
    }
}

struct LibraryAlbum: Identifiable {
    struct ID: Hashable {
        let artistName: String
        let title: String
    }

    let id: ID
    let title: String
    let artistName: String
    let artwork: Artwork?
    let songs: [Song]
}

enum MusicLibraryGrouping {
    static func groups(from songs: [Song]) -> (artists: [LibraryArtist], albums: [LibraryAlbum]) {
        let albums = albums(from: songs)
        return (artists(from: songs, albums: albums), albums)
    }

    private static func albums(from songs: [Song]) -> [LibraryAlbum] {
        Dictionary(grouping: songs) { song in
            LibraryAlbum.ID(
                artistName: displayArtistName(song.artistName),
                title: displayAlbumTitle(song.albumTitle)
            )
        }
        .map { id, songs in
            LibraryAlbum(
                id: id,
                title: id.title,
                artistName: id.artistName,
                artwork: songs.compactMap(\.artwork).first,
                songs: songs.sorted(by: isAlbumTrackBefore)
            )
        }
        .sorted(by: isAlbumBefore)
    }

    private static func artists(from songs: [Song], albums: [LibraryAlbum]) -> [LibraryArtist] {
        let albumsByArtist = Dictionary(grouping: albums, by: \.artistName)

        return Dictionary(grouping: songs) { song in
            displayArtistName(song.artistName)
        }
        .map { name, songs in
            LibraryArtist(
                name: name,
                songs: songs.sorted(by: MusicLibrarySortOption.title.areInIncreasingOrder),
                albums: albumsByArtist[name] ?? []
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func isAlbumBefore(_ lhs: LibraryAlbum, _ rhs: LibraryAlbum) -> Bool {
        let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
        guard titleComparison == .orderedSame else {
            return titleComparison == .orderedAscending
        }

        return lhs.artistName.localizedStandardCompare(rhs.artistName) == .orderedAscending
    }

    private static func isAlbumTrackBefore(_ lhs: Song, _ rhs: Song) -> Bool {
        let lhsDiscNumber = lhs.discNumber ?? 1
        let rhsDiscNumber = rhs.discNumber ?? 1
        guard lhsDiscNumber == rhsDiscNumber else {
            return lhsDiscNumber < rhsDiscNumber
        }

        let lhsTrackNumber = lhs.trackNumber ?? .max
        let rhsTrackNumber = rhs.trackNumber ?? .max
        guard lhsTrackNumber == rhsTrackNumber else {
            return lhsTrackNumber < rhsTrackNumber
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func displayArtistName(_ artistName: String) -> String {
        artistName.isEmpty ? "Unknown Artist" : artistName
    }

    private static func displayAlbumTitle(_ albumTitle: String?) -> String {
        guard let albumTitle, !albumTitle.isEmpty else {
            return "Unknown Album"
        }

        return albumTitle
    }
}
