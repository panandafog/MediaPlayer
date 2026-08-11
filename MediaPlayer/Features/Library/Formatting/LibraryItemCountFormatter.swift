//
//  LibraryItemCountFormatter.swift
//  MediaPlayer
//
//

enum LibraryItemCountFormatter {
    static func tracks(_ count: Int) -> String {
        "\(count) \(count == 1 ? "track" : "tracks")"
    }

    static func albums(_ count: Int) -> String {
        "\(count) \(count == 1 ? "album" : "albums")"
    }
}
