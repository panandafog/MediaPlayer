//
//  SongListView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct SongListView: View {
    let songs: [Song]
    let queue: [Song]
    let currentSongState: CurrentSongState
    let isLoading: Bool
    let onPlay: (Song, [Song]) -> Void

    init(
        songs: [Song],
        queue: [Song],
        currentSongState: CurrentSongState,
        isLoading: Bool = false,
        onPlay: @escaping (Song, [Song]) -> Void
    ) {
        self.songs = songs
        self.queue = queue
        self.currentSongState = currentSongState
        self.isLoading = isLoading
        self.onPlay = onPlay
    }

    var body: some View {
        List {
            ForEach(songs) { song in
                SongRow(
                    song: song,
                    currentSongState: currentSongState,
                    onPlay: { onPlay(song, queue) }
                )
                .equatable()
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
}
