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
    let onOpenArtist: ((Song) -> Void)?
    let onOpenAlbum: ((Song) -> Void)?
    @State private var isShowingQueue = false

    init(
        player: MusicPlayerViewModel,
        onOpenArtist: ((Song) -> Void)? = nil,
        onOpenAlbum: ((Song) -> Void)? = nil
    ) {
        self.player = player
        self.onOpenArtist = onOpenArtist
        self.onOpenAlbum = onOpenAlbum
    }

    var body: some View {
        Group {
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
                    onSeek: player.seek,
                    onShowQueue: {
                        isShowingQueue = true
                    },
                    onOpenArtist: onOpenArtist,
                    onOpenAlbum: onOpenAlbum
                )
            } else {
                ContentUnavailableView(
                    "Nothing Playing",
                    systemImage: "music.note",
                    description: Text("Choose a track from your library to start playback.")
                )
            }
        }
        .sheet(isPresented: $isShowingQueue) {
            PlaybackQueueView(player: player)
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
    let onShowQueue: () -> Void
    let onOpenArtist: ((Song) -> Void)?
    let onOpenAlbum: ((Song) -> Void)?

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
                    PlayerMetadataLink(
                        title: song.artistName,
                        font: .headline,
                        foregroundStyle: .secondary,
                        action: onOpenArtist.map { action in
                            { action(song) }
                        }
                    )
                    PlayerMetadataLink(
                        title: song.albumTitle ?? "Unknown Album",
                        font: .subheadline,
                        foregroundStyle: .tertiary,
                        action: onOpenAlbum.map { action in
                            { action(song) }
                        }
                    )
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

                PlayerUtilityControls(
                    song: song,
                    onShowQueue: onShowQueue
                )
            }
            .padding(metrics.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct PlayerMetadataLink<S: ShapeStyle>: View {
    let title: String
    let font: Font
    let foregroundStyle: S
    let action: (() -> Void)?

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        Text(title)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineLimit(1)
            .contentShape(Rectangle())
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
