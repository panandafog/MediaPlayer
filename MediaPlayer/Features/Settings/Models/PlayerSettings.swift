//
//  PlayerSettings.swift
//  MediaPlayer
//

import Foundation

enum PlayerSettingsKey {
    static let searchBarPosition = "settings.searchBarPosition"
    static let usesLiquidGlassInPlayerWindow = "settings.usesLiquidGlassInPlayerWindow"
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
