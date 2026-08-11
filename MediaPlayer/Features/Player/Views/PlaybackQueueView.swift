//
//  PlaybackQueueView.swift
//  MediaPlayer
//
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
        .frame(
            minWidth: Layout.minimumWidth,
            minHeight: Layout.minimumHeight
        )
    }
}

private struct PlaybackQueueRow: View {
    let song: Song
    var isCurrent = false

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            SongArtwork(artwork: song.artwork, size: Layout.artworkSize)

            VStack(alignment: .leading, spacing: Layout.metadataSpacing) {
                Text(song.title)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Layout.minimumTrailingSpacing)

            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Now Playing")
            }
        }
        .contentShape(Rectangle())
    }
}

private enum Layout {
    static let minimumWidth: CGFloat = 320
    static let minimumHeight: CGFloat = 360
    static let rowSpacing: CGFloat = 12
    static let artworkSize: CGFloat = 44
    static let metadataSpacing: CGFloat = 3
    static let minimumTrailingSpacing: CGFloat = 8
}
