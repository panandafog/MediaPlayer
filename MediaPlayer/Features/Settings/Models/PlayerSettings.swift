//
//  PlayerSettings.swift
//  MediaPlayer
//

import Foundation

enum PlayerSettingsKey {
    static let searchBarPosition = "settings.searchBarPosition"
    static let equalizerGainPrefix = "settings.equalizer.gain."
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

enum EqualizerBand: String, CaseIterable, Identifiable {
    case hz60
    case hz150
    case hz400
    case khz1
    case khz2Point4
    case khz15

    var id: Self { self }

    var title: String {
        switch self {
        case .hz60:
            "60 Hz"
        case .hz150:
            "150 Hz"
        case .hz400:
            "400 Hz"
        case .khz1:
            "1 kHz"
        case .khz2Point4:
            "2.4 kHz"
        case .khz15:
            "15 kHz"
        }
    }

    var defaultsKey: String {
        PlayerSettingsKey.equalizerGainPrefix + rawValue
    }
}
