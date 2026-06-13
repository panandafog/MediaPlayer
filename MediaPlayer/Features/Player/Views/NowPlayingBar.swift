//
//  NowPlayingBar.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct NowPlayingBar: View {
    let song: Song
    let isPlaying: Bool
    let playbackMode: PlaybackMode
    @ObservedObject var playbackTime: PlaybackTimeState
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void
    let onOpenDetails: () -> Void
    let onOpenArtist: (Song) -> Void
    let onOpenAlbum: (Song) -> Void

    var body: some View {
        VStack(spacing: 8) {
            PlaybackProgressSlider(
                playbackTime: playbackTime.value,
                duration: song.duration,
                onSeek: onSeek
            )

            HStack(spacing: 10) {
                trackSummary

                Spacer(minLength: 4)

                AudioRoutePickerButton()
                CompactPlayerOptionsMenu(
                    song: song,
                    playbackMode: playbackMode,
                    onSelectPlaybackMode: onSelectPlaybackMode,
                    onShowQueue: onShowQueue
                )
#if os(macOS)
                PlayerControlButton(
                    title: "Open Mini Player",
                    systemImage: "macwindow",
                    action: onOpenDetails
                )
#endif
                PlayerControlButton(
                    title: "Previous track",
                    systemImage: "backward.fill",
                    action: onPrevious
                )
                PlayerControlButton(
                    title: isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    action: onTogglePlayback
                )
                PlayerControlButton(
                    title: "Next track",
                    systemImage: "forward.fill",
                    action: onNext
                )
            }
        }
        .padding(12)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var trackSummary: some View {
#if os(iOS)
        Button(action: onOpenDetails) {
            trackSummaryLabel
        }
        .buttonStyle(.plain)
#else
        trackSummaryLabel
#endif
    }

    private var trackSummaryLabel: some View {
        HStack(spacing: 12) {
            SongArtwork(artwork: song.artwork, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
#if os(macOS)
                Button {
                    onOpenArtist(song)
                } label: {
                    Text(song.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Button {
                    onOpenAlbum(song)
                } label: {
                    Text(song.albumTitle ?? "Unknown Album")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
#else
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
#endif
            }
        }
    }
}

private struct PlayerControlButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
    }
}
