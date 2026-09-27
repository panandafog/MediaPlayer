//
//  SongListPresentation.swift
//  MediaPlayer
//

import CoreGraphics
import Foundation
import MusicKit

enum SongListContext: Equatable {
    case library
    case artist(String)
    case album
    case playlist

    var showsAlbum: Bool { self != .album }

    func showsArtist(for song: Song) -> Bool {
        guard case let .artist(name) = self else { return true }
        return song.artistName.localizedStandardCompare(name) != .orderedSame
    }
}

enum SongListField: String, CaseIterable, Hashable, Identifiable {
    case releaseYear
    case genre
    case playCount
    case dateAdded
    case lastPlayed

    static let defaultOrder: [Self] = allCases
    static let defaultEnabled: [Self] = [.releaseYear, .genre]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .releaseYear: "Year"
        case .genre: "Genre"
        case .playCount: "Plays"
        case .dateAdded: "Date Added"
        case .lastPlayed: "Last Played"
        }
    }

    var width: CGFloat {
        switch self {
        case .releaseYear: 58
        case .genre: 128
        case .playCount: 64
        case .dateAdded, .lastPlayed: 100
        }
    }

    func value(for song: Song) -> String? {
        switch self {
        case .releaseYear:
            song.releaseDate.map { String(Calendar.current.component(.year, from: $0)) }
        case .genre:
            song.genreNames.isEmpty ? nil : song.genreNames.joined(separator: ", ")
        case .playCount:
            song.playCount.map { String($0) }
        case .dateAdded:
            song.libraryAddedDate?.formatted(date: .numeric, time: .omitted)
        case .lastPlayed:
            song.lastPlayedDate?.formatted(date: .numeric, time: .omitted)
        }
    }

    static func order(from storedValue: String) -> [Self] {
        let stored = storedValue.split(separator: ",").compactMap { Self(rawValue: String($0)) }
        var unique: [Self] = []
        for field in stored + allCases where !unique.contains(field) {
            unique.append(field)
        }
        return unique
    }

    static func enabled(from storedValue: String) -> Set<Self> {
        Set(storedValue.split(separator: ",").compactMap { Self(rawValue: String($0)) })
    }

    static func storageValue(_ fields: [Self]) -> String {
        fields.map(\.rawValue).joined(separator: ",")
    }
}

struct SongListLayout: Equatable {
    enum Density: Equatable {
        case compact
        case regular
        case expanded
    }

    let density: Density
    let fields: [SongListField]
    let inlineFields: [SongListField]
    let showsAlbum: Bool
    let showsAlbumColumn: Bool
    let showsDuration: Bool
    let showsInfoButton: Bool
    let columnScale: CGFloat

    var albumColumnWidth: CGFloat {
        (density == .expanded ? 176 : 136) * columnScale
    }

    func width(for field: SongListField) -> CGFloat {
        field.width * columnScale
    }

    init(
        availableWidth: CGFloat,
        textScale: CGFloat,
        context: SongListContext,
        orderedFields: [SongListField],
        showsAlbum: Bool = true,
        showsDuration: Bool = true,
        showsInfoButton: Bool = true
    ) {
        columnScale = max(textScale, 1)
        let effectiveWidth = availableWidth / columnScale
        self.showsAlbum = showsAlbum && context.showsAlbum
        self.showsDuration = showsDuration
        self.showsInfoButton = showsInfoButton

        if effectiveWidth < 520 {
            density = .compact
        } else if effectiveWidth < 760 {
            density = .regular
        } else {
            density = .expanded
        }

        showsAlbumColumn = self.showsAlbum && density != .compact

        guard density == .expanded else {
            fields = []
            inlineFields = orderedFields
            return
        }

        inlineFields = []

        // Reserve room for artwork, title/artist, and the enabled fixed controls.
        var reservedWidth: CGFloat = 560
        if showsAlbumColumn { reservedWidth += 160 }
        if !showsDuration { reservedWidth -= 56 }
        if !showsInfoButton { reservedWidth -= 40 }
        var remainingWidth = effectiveWidth - reservedWidth
        var visibleFields: [SongListField] = []
        for field in orderedFields {
            let requiredWidth = field.width + 12
            guard remainingWidth >= requiredWidth else { break }
            visibleFields.append(field)
            remainingWidth -= requiredWidth
        }
        fields = visibleFields
    }
}
