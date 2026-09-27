//
//  MusicLibraryGrouping.swift
//  MediaPlayer
//
//

import Foundation
import MusicKit

nonisolated struct LibraryArtist: Identifiable, Sendable {
    let name: String
    let songs: [Song]
    let albums: [LibraryAlbum]
    let primaryGenreName: String?
    let totalDuration: TimeInterval?

    var id: String {
        name
    }

    var artwork: Artwork? {
        albums.first?.artwork ?? songs.first?.artwork
    }
}

nonisolated struct LibraryAlbum: Identifiable, Sendable {
    nonisolated struct ID: Hashable, Sendable {
        let artistName: String
        let title: String
    }

    let id: ID
    let title: String
    let artistName: String
    let artwork: Artwork?
    let songs: [Song]
    let releaseYear: Int?
    let primaryGenreName: String?
    let totalDuration: TimeInterval?
}

nonisolated enum MusicLibraryGrouping {
    static func groups(
        from songs: [Song],
        usesSmartArtistGrouping: Bool = false,
        artistSeparatorCharacters: String =
            SmartArtistGroupingSettings.defaultSeparatorCharacters
    ) -> (artists: [LibraryArtist], albums: [LibraryAlbum]) {
        let albums = albums(from: songs)
        return (
            artists(
                from: songs,
                albums: albums,
                usesSmartArtistGrouping: usesSmartArtistGrouping,
                artistSeparatorCharacters: artistSeparatorCharacters
            ),
            albums
        )
    }

    static func artistNames(
        for song: Song,
        usesSmartArtistGrouping: Bool,
        artistSeparatorCharacters: String =
            SmartArtistGroupingSettings.defaultSeparatorCharacters
    ) -> [String] {
        let fallbackName = displayArtistName(song.artistName)
        guard usesSmartArtistGrouping else {
            return [fallbackName]
        }

        let structuredNames = uniqueArtistNames(
            song.artists?.map(\.name) ?? []
        )
        if !structuredNames.isEmpty {
            return structuredNames
        }

        let parsedNames = CombinedArtistNameParser.names(
            from: fallbackName,
            separatorCharacters: artistSeparatorCharacters
        )
        return parsedNames
    }

    private static func albums(from songs: [Song]) -> [LibraryAlbum] {
        let artistNamesByAlbumTitle = Dictionary(
            grouping: songs,
            by: { displayAlbumTitle($0.albumTitle) }
        )
        .mapValues { albumSongs in
            Set(albumSongs.map { displayArtistName($0.artistName) })
        }

        return Dictionary(grouping: songs) { song in
            let title = displayAlbumTitle(song.albumTitle)
            let artistName = displayArtistName(song.artistName)
            return LibraryAlbum.ID(
                artistName: song.albumTitle?.isEmpty == false
                    ? AlbumArtistNameResolver.canonicalName(
                        for: artistName,
                        among: artistNamesByAlbumTitle[title] ?? []
                    )
                    : artistName,
                title: title
            )
        }
        .map { id, songs in
            let metadata = LibraryGroupMetadata(songs: songs)
            return LibraryAlbum(
                id: id,
                title: id.title,
                artistName: id.artistName,
                artwork: songs.compactMap(\.artwork).first,
                songs: songs.sorted(by: isAlbumTrackBefore),
                releaseYear: metadata.releaseYear,
                primaryGenreName: metadata.primaryGenreName,
                totalDuration: metadata.totalDuration
            )
        }
        .sorted(by: isAlbumBefore)
    }

    private static func artists(
        from songs: [Song],
        albums: [LibraryAlbum],
        usesSmartArtistGrouping: Bool,
        artistSeparatorCharacters: String
    ) -> [LibraryArtist] {
        var songsByArtist: [String: [Song]] = [:]
        for song in songs {
            for artistName in artistNames(
                for: song,
                usesSmartArtistGrouping: usesSmartArtistGrouping,
                artistSeparatorCharacters: artistSeparatorCharacters
            ) {
                songsByArtist[artistName, default: []].append(song)
            }
        }

        return songsByArtist
        .map { name, songs in
            let songIDs = Set(songs.map(\.id))
            let metadata = LibraryGroupMetadata(songs: songs)
            return LibraryArtist(
                name: name,
                songs: songs.sorted(by: MusicLibrarySortOption.title.areInIncreasingOrder),
                albums: albums.filter { album in
                    album.songs.contains { songIDs.contains($0.id) }
                },
                primaryGenreName: metadata.primaryGenreName,
                totalDuration: metadata.totalDuration
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

    private static func uniqueArtistNames(_ names: [String]) -> [String] {
        var normalizedNames: Set<String> = []

        return names.compactMap { name in
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                return nil
            }

            let normalizedName = trimmedName.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            guard normalizedNames.insert(normalizedName).inserted else {
                return nil
            }

            return trimmedName
        }
    }
}

nonisolated enum AlbumArtistNameResolver {
    static func canonicalName(for artistName: String, among albumArtistNames: Set<String>) -> String {
        albumArtistNames
            .filter { isCollaborationVariant(artistName, of: $0) }
            .min { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.localizedStandardCompare(rhs) == .orderedAscending
                    : lhs.count < rhs.count
            }
            ?? artistName
    }

    private static func isCollaborationVariant(_ name: String, of baseName: String) -> Bool {
        guard !baseName.isEmpty,
              baseName != "Unknown Artist",
              let prefix = name.range(
                  of: baseName,
                  options: [.anchored, .caseInsensitive, .diacriticInsensitive]
              ),
              prefix.upperBound < name.endIndex else {
            return false
        }

        let suffix = String(name[prefix.upperBound...])
        return suffix.range(
            of: #"^\s+(?:feat(?:uring)?|ft|with)\.?\s+\S"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil || suffix.range(
            of: #"^(?:\s*[,;&]\s*\S|\s+/\s+\S)"#,
            options: .regularExpression
        ) != nil
    }
}

nonisolated struct LibraryGroupMetadata {
    let releaseYear: Int?
    let primaryGenreName: String?
    let totalDuration: TimeInterval?

    init(songs: [Song]) {
        let years = Set(songs.compactMap { song in
            song.releaseDate.map { Calendar.current.component(.year, from: $0) }
        })
        releaseYear = years.count == 1 ? years.first : nil

        let genreCounts = songs.reduce(into: [String: Int]()) { counts, song in
            for genre in Set(song.genreNames.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                counts[genre, default: 0] += 1
            }
        }
        let leadingGenre = genreCounts.max { lhs, rhs in
            lhs.value == rhs.value
                ? lhs.key.localizedStandardCompare(rhs.key) == .orderedDescending
                : lhs.value < rhs.value
        }
        primaryGenreName = leadingGenre.flatMap { entry in
            entry.value * 2 > songs.count ? entry.key : nil
        }

        let durations = songs.compactMap(\.duration)
        if !songs.isEmpty,
           durations.count == songs.count,
           durations.allSatisfy({ $0.isFinite && $0 >= 0 }) {
            totalDuration = durations.reduce(0, +)
        } else {
            totalDuration = nil
        }
    }
}

nonisolated enum CombinedArtistNameParser {
    static func names(
        from artistName: String,
        separatorCharacters: String =
            SmartArtistGroupingSettings.defaultSeparatorCharacters
    ) -> [String] {
        let separators = Set(
            SmartArtistGroupingSettings
                .normalizedSeparatorCharacters(separatorCharacters)
        )
        let normalizedCharacters = String(artistName.map { character in
            separators.contains(character) ? normalizedDelimiter : character
        })
        let normalizedSeparators = normalizedCharacters.replacingOccurrences(
            of: wordSeparatorPattern,
            with: String(normalizedDelimiter),
            options: [.regularExpression, .caseInsensitive]
        )
        let components = normalizedSeparators.components(
            separatedBy: String(normalizedDelimiter)
        )

        var normalizedNames: Set<String> = []
        let names: [String] = components.compactMap { component -> String? in
            let name = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return nil
            }

            let normalizedName = name.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            guard normalizedNames.insert(normalizedName).inserted else {
                return nil
            }

            return name
        }

        return names.isEmpty ? [artistName] : names
    }

    private static let wordSeparatorPattern =
        #"\s+(?:feat(?:uring)?|ft|with)\.?\s+"#
    private static let normalizedDelimiter: Character = "\u{001F}"
}
