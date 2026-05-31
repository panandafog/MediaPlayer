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
    @ObservedObject var playbackTime: PlaybackTimeState
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                PlaybackProgressSlider(
                    playbackTime: playbackTime.value,
                    duration: song.duration,
                    onSeek: onSeek
                )

                HStack(spacing: 12) {
                    SongArtwork(artwork: song.artwork, size: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

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
            .background(.regularMaterial)
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
