//
//  NowPlayingView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var player: MusicPlayerViewModel

    var body: some View {
        if let song = player.currentSong {
            NowPlayingContent(
                song: song,
                isPlaying: player.isPlaying,
                playbackTime: player.playbackTime,
                onPrevious: {
                    Task {
                        await player.skipToPreviousSong()
                    }
                },
                onTogglePlayback: {
                    Task {
                        await player.togglePlayback()
                    }
                },
                onNext: {
                    Task {
                        await player.skipToNextSong()
                    }
                },
                onSeek: player.seek
            )
        } else {
            ContentUnavailableView(
                "Nothing Playing",
                systemImage: "music.note",
                description: Text("Choose a track from your library to start playback.")
            )
        }
    }
}

private struct NowPlayingContent: View {
    let song: Song
    let isPlaying: Bool
    @ObservedObject var playbackTime: PlaybackTimeState
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = NowPlayingLayoutMetrics(availableSize: geometry.size)

            VStack(spacing: metrics.contentSpacing) {
                SongArtwork(
                    artwork: song.artwork,
                    size: metrics.artworkSize,
                    usesHighResolutionSource: true
                )

                VStack(spacing: 6) {
                    Text(song.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(song.artistName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(song.albumTitle ?? "Unknown Album")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                PlaybackProgressSlider(
                    playbackTime: playbackTime.value,
                    duration: song.duration,
                    onSeek: onSeek
                )

                HStack(spacing: metrics.controlSpacing) {
                    LargePlayerControlButton(
                        title: "Previous track",
                        systemImage: "backward.fill",
                        action: onPrevious
                    )
                    LargePlayerControlButton(
                        title: isPlaying ? "Pause" : "Play",
                        systemImage: isPlaying ? "pause.fill" : "play.fill",
                        isPrimary: true,
                        action: onTogglePlayback
                    )
                    LargePlayerControlButton(
                        title: "Next track",
                        systemImage: "forward.fill",
                        action: onNext
                    )
                }
            }
            .padding(metrics.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct NowPlayingLayoutMetrics {
    let availableSize: CGSize

    private var isCompact: Bool {
        availableSize.height < 650
    }

    var outerPadding: CGFloat {
        isCompact ? 16 : 24
    }

    var contentSpacing: CGFloat {
        isCompact ? 12 : 20
    }

    var controlSpacing: CGFloat {
        isCompact ? 30 : 42
    }

    var artworkSize: CGFloat {
        max(
            min(
                validWidth - outerPadding * 2,
                validHeight * (isCompact ? 0.38 : 0.46),
                380
            ),
            1
        )
    }

    private var validWidth: CGFloat {
        availableSize.width.isFinite ? max(availableSize.width, 0) : 0
    }

    private var validHeight: CGFloat {
        availableSize.height.isFinite ? max(availableSize.height, 0) : 0
    }
}

private struct LargePlayerControlButton: View {
    let title: String
    let systemImage: String
    var isPrimary = false
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if isPrimary {
            button
                .buttonStyle(.glassProminent)
        } else {
            button
                .buttonStyle(.glass)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(isPrimary ? .title : .title2)
                .frame(width: isPrimary ? 54 : 42, height: isPrimary ? 54 : 42)
        }
        .buttonBorderShape(.circle)
        .accessibilityLabel(title)
    }
}
