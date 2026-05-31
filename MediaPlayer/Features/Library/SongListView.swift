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
    let currentSong: Song?
    let isLoading: Bool
    let onPlay: (Song, [Song]) -> Void

    init(
        songs: [Song],
        queue: [Song],
        currentSong: Song?,
        isLoading: Bool = false,
        onPlay: @escaping (Song, [Song]) -> Void
    ) {
        self.songs = songs
        self.queue = queue
        self.currentSong = currentSong
        self.isLoading = isLoading
        self.onPlay = onPlay
    }

    var body: some View {
        List {
            ForEach(songs) { song in
                SongRow(
                    song: song,
                    isCurrent: currentSong?.id == song.id,
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
