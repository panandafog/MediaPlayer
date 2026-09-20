//
//  PlayerSettings.swift
//  MediaPlayer
//

import Foundation

enum PlayerSettingsKey {
    static let librarySection = "settings.library.section"
    static let librarySortOption = "settings.library.sortOption"
    static let searchBarPosition = "settings.searchBarPosition"
    static let smartArtistSeparatorCharacters =
        "settings.smartArtistSeparatorCharacters"
    static let usesSmartArtistGrouping = "settings.usesSmartArtistGrouping"
    static let usesLiquidGlassInPlayerWindow = "settings.usesLiquidGlassInPlayerWindow"
}

nonisolated enum SmartArtistGroupingSettings {
    static let defaultSeparatorCharacters = ",;&/"

    static func normalizedSeparatorCharacters(_ value: String) -> String {
        var seenCharacters: Set<Character> = []

        return String(value.filter { character in
            guard !character.isWhitespace else {
                return false
            }

            return seenCharacters.insert(character).inserted
        })
    }
}

#if os(iOS)
enum SearchBarPosition: String, CaseIterable, Identifiable {
    case bottom
    case top

    var id: Self { self }

    var title: String {
        switch self {
        case .bottom:
            "Bottom"
        case .top:
            "Top"
        }
    }
}
#endif
