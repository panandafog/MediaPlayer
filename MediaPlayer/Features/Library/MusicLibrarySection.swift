//
//  MusicLibrarySection.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

enum MusicLibrarySection: String, CaseIterable, Identifiable {
    case songs
    case artists
    case albums

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .songs:
            "Songs"
        case .artists:
            "Artists"
        case .albums:
            "Albums"
        }
    }

    var systemImage: String {
        switch self {
        case .songs:
            "music.note.list"
        case .artists:
            "music.mic"
        case .albums:
            "square.stack"
        }
    }

}

enum ArtistLibrarySection: String, CaseIterable, Identifiable {
    case songs
    case albums

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .songs:
            "Songs"
        case .albums:
            "Albums"
        }
    }

    var systemImage: String {
        switch self {
        case .songs:
            "music.note.list"
        case .albums:
            "square.stack"
        }
    }
}
