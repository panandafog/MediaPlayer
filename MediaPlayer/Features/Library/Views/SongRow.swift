//
//  SongRow.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct SongRow: View, Equatable {
    let song: Song
    let layout: SongListLayout
    let context: SongListContext
    let currentSongState: CurrentSongState
    let onPlay: () -> Void

    static func == (lhs: SongRow, rhs: SongRow) -> Bool {
        lhs.song.id == rhs.song.id
            && lhs.song.title == rhs.song.title
            && lhs.song.artistName == rhs.song.artistName
            && lhs.song.albumTitle == rhs.song.albumTitle
            && lhs.song.duration == rhs.song.duration
            && lhs.song.artwork == rhs.song.artwork
            && lhs.song.releaseDate == rhs.song.releaseDate
            && lhs.song.genreNames == rhs.song.genreNames
            && lhs.song.playCount == rhs.song.playCount
            && lhs.song.libraryAddedDate == rhs.song.libraryAddedDate
            && lhs.song.lastPlayedDate == rhs.song.lastPlayedDate
            && lhs.layout == rhs.layout
            && lhs.context == rhs.context
            && lhs.currentSongState === rhs.currentSongState
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: LibraryRowMetrics.spacing) {
                SongArtwork(artwork: song.artwork, size: LibraryRowMetrics.artworkSize)

                primaryMetadata
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                if layout.showsAlbumColumn {
                    Text(song.albumTitle ?? "Unknown Album")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: layout.albumColumnWidth, alignment: .leading)
                }

                ForEach(layout.fields) { field in
                    Text(field.value(for: song) ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: layout.width(for: field), alignment: .leading)
                }

                CurrentSongIndicator(
                    songID: song.id,
                    currentSongState: currentSongState
                )

                if layout.showsDuration {
                    Text(TrackDurationFormatter.string(from: song.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var primaryMetadata: some View {
        VStack(alignment: .leading, spacing: LibraryRowMetrics.metadataSpacing) {
            Text(song.title)
                .lineLimit(layout.density == .compact ? 2 : 1)

            if layout.density == .compact {
                let parts = [
                    context.showsArtist(for: song) ? song.artistName : nil,
                    layout.showsAlbum ? (song.albumTitle ?? "Unknown Album") : nil
                ].compactMap { $0 }
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if context.showsArtist(for: song) {
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let inlineMetadata {
                Text(inlineMetadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var inlineMetadata: String? {
        let limit = layout.density == .compact ? 1 : 2
        let values = layout.inlineFields.compactMap { field -> String? in
            guard let value = field.value(for: song), !value.isEmpty else { return nil }
            return "\(field.title): \(value)"
        }
        let visibleValues = values.prefix(limit)
        if visibleValues.isEmpty, let firstField = layout.inlineFields.first {
            return "\(firstField.title): —"
        }
        return visibleValues.isEmpty ? nil : visibleValues.joined(separator: " · ")
    }
}

private struct CurrentSongIndicator: View {
    let songID: MusicItemID
    @ObservedObject var currentSongState: CurrentSongState

    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .foregroundStyle(.tint)
            .opacity(isCurrent ? 1 : 0)
            .frame(width: LibraryRowMetrics.currentSongIndicatorWidth)
            .accessibilityLabel("Now playing")
            .accessibilityHidden(!isCurrent)
    }

    private var isCurrent: Bool {
        currentSongState.songID == songID
    }
}
