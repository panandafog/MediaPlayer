//
//  LibraryNavigationDestination.swift
//  MediaPlayer
//
//  Created by Codex on 12.06.2026.
//

import MusicKit
import SwiftUI

enum LibraryNavigationDestination: Hashable {
    case artist(LibraryArtist.ID)
    case album(LibraryAlbum.ID)
}

struct LibraryNavigationDestinationView: View {
    let destination: LibraryNavigationDestination
    @ObservedObject var library: MusicLibraryViewModel
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

    @ViewBuilder
    var body: some View {
        switch destination {
        case let .artist(id):
            if let artist = library.artist(id: id) {
                ArtistDetailView(
                    artist: artist,
                    currentSongState: currentSongState,
                    onPlay: onPlay
                )
            } else {
                unavailableView
            }
        case let .album(id):
            if let album = library.album(id: id) {
                AlbumDetailView(
                    album: album,
                    currentSongState: currentSongState,
                    onPlay: onPlay
                )
            } else {
                unavailableView
            }
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "Item Unavailable",
            systemImage: "music.note",
            description: Text("This item is no longer available in your music library.")
        )
    }
}
