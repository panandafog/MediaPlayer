//
//  SongRow.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct SongRow: View, Equatable {
    let song: Song
    let currentSongState: CurrentSongState
    let onPlay: () -> Void

    static func == (lhs: SongRow, rhs: SongRow) -> Bool {
        lhs.song.id == rhs.song.id
            && lhs.song.title == rhs.song.title
            && lhs.song.artistName == rhs.song.artistName
            && lhs.song.albumTitle == rhs.song.albumTitle
            && lhs.song.duration == rhs.song.duration
            && lhs.currentSongState === rhs.currentSongState
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                SongArtwork(artwork: song.artwork, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(song.albumTitle ?? "Unknown Album")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                CurrentSongIndicator(
                    songID: song.id,
                    currentSongState: currentSongState
                )

                Text(TrackDurationFormatter.string(from: song.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CurrentSongIndicator: View {
    let songID: MusicItemID
    @ObservedObject var currentSongState: CurrentSongState

    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .foregroundStyle(.tint)
            .opacity(isCurrent ? 1 : 0)
            .frame(width: 16)
            .accessibilityLabel("Now playing")
            .accessibilityHidden(!isCurrent)
    }

    private var isCurrent: Bool {
        currentSongState.songID == songID
    }
}
