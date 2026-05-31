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
    let isCurrent: Bool
    let onPlay: () -> Void

    static func == (lhs: SongRow, rhs: SongRow) -> Bool {
        lhs.song.id == rhs.song.id
            && lhs.song.title == rhs.song.title
            && lhs.song.artistName == rhs.song.artistName
            && lhs.song.albumTitle == rhs.song.albumTitle
            && lhs.song.duration == rhs.song.duration
            && lhs.isCurrent == rhs.isCurrent
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                SongArtwork(artwork: song.artwork, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .fontWeight(isCurrent ? .semibold : .regular)
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

                if isCurrent {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Now playing")
                }

                Text(TrackDurationFormatter.string(from: song.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
