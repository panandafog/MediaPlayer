//
//  SongListView.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct SongListView: View {
    @State private var selectedSong: Song?

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
                HStack(spacing: 8) {
                    SongRow(
                        song: song,
                        currentSongState: currentSongState,
                        onPlay: { onPlay(song, queue) }
                    )
                    .equatable()

                    Button {
                        selectedSong = song
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Track info: \(song.title)")
                }
                .contextMenu {
                    Button {
                        selectedSong = song
                    } label: {
                        Label("Track Info", systemImage: "info.circle")
                    }
                }
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
        .avoidsPlayerAccessory()
        .sheet(item: $selectedSong) { song in
            TrackDetailsView(song: song)
        }
    }
}
