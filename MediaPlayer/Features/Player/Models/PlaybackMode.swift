//
//  PlaybackMode.swift
//  MediaPlayer
//

import MusicKit

enum PlaybackMode: String, CaseIterable, Identifiable, Sendable {
    case normal
    case shuffle
    case repeatQueue
    case repeatOne

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .normal:
            "Normal"
        case .shuffle:
            "Shuffle"
        case .repeatQueue:
            "Repeat Queue"
        case .repeatOne:
            "Repeat One"
        }
    }

    var systemImage: String {
        switch self {
        case .normal:
            "arrow.right"
        case .shuffle:
            "shuffle"
        case .repeatQueue:
            "repeat"
        case .repeatOne:
            "repeat.1"
        }
    }

    var nativeRepeatMode: MusicPlayer.RepeatMode {
        switch self {
        case .repeatQueue:
            .all
        case .repeatOne:
            .one
        case .normal, .shuffle:
            .none
        }
    }
}
