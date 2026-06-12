//
//  PlaybackQueueView.swift
//  MediaPlayer
//
//  Created by Codex on 01.06.2026.
//

import MusicKit
import SwiftUI

struct PlaybackQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: MusicPlayerViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let currentSong = player.currentSong {
                    List {
                        Section("Now Playing") {
                            PlaybackQueueRow(
                                song: currentSong,
                                isCurrent: true
                            )
                        }

                        Section("Up Next") {
                            if player.upNextSongs.isEmpty {
                                Text("The queue ends after the current track.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(player.upNextSongs) { song in
                                    Button {
                                        Task {
                                            await player.playFromCurrentQueue(song)
                                        }
                                    } label: {
                                        PlaybackQueueRow(song: song)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    ContentUnavailableView(
                        "Queue Is Empty",
                        systemImage: "list.bullet",
                        description: Text("Choose a track from your library to start playback.")
                    )
                }
            }
            .navigationTitle("Playing Next")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 360)
    }
}

private struct PlaybackQueueRow: View {
    let song: Song
    var isCurrent = false

    var body: some View {
        HStack(spacing: 12) {
            SongArtwork(artwork: song.artwork, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Now Playing")
            }
        }
        .contentShape(Rectangle())
    }
}
