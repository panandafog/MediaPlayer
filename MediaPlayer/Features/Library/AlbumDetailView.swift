//
//  AlbumDetailView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct AlbumDetailView: View {
    let album: LibraryAlbum
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

    var body: some View {
        SongListView(
            songs: album.songs,
            queue: album.songs,
            currentSongState: currentSongState,
            onPlay: onPlay
        )
        .navigationTitle(album.title)
    }
}
