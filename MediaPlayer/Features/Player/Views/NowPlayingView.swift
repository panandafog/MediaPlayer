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
                    playbackMode: player.playbackMode,
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
                    onSelectPlaybackMode: player.setPlaybackMode,
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
    let playbackMode: PlaybackMode
    @ObservedObject var playbackTime: PlaybackTimeState
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void
    let onOpenArtist: ((Song) -> Void)?
    let onOpenAlbum: ((Song) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let metrics = NowPlayingLayoutMetrics(availableSize: geometry.size)

            switch metrics.layout {
            case .fullHorizontal:
                horizontalLayout(metrics: metrics)
            case .fullVertical:
                verticalLayout(metrics: metrics)
            case .compactHorizontal:
                compactHorizontalLayout(metrics: metrics, showsPlaybackControl: true)
            case .compactVertical:
                compactVerticalLayout(metrics: metrics, showsPlaybackControl: true)
            case .minimalHorizontal:
                compactHorizontalLayout(metrics: metrics, showsPlaybackControl: false)
            case .minimalVertical:
                compactVerticalLayout(metrics: metrics, showsPlaybackControl: false)
            }
        }
    }

    private func verticalLayout(metrics: NowPlayingLayoutMetrics) -> some View {
        VStack(spacing: metrics.contentSpacing) {
            artwork(size: metrics.artworkSize)
            detailsAndControls(metrics: metrics)
        }
        .padding(metrics.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func horizontalLayout(metrics: NowPlayingLayoutMetrics) -> some View {
        HStack(spacing: metrics.columnSpacing) {
            artwork(size: metrics.artworkSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            detailsAndControls(metrics: metrics)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(metrics.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactVerticalLayout(
        metrics: NowPlayingLayoutMetrics,
        showsPlaybackControl: Bool
    ) -> some View {
        VStack(spacing: metrics.compactSpacing) {
            artwork(size: metrics.compactArtworkSize)
            compactDetails(showsPlaybackControl: showsPlaybackControl)
        }
        .padding(metrics.compactPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactHorizontalLayout(
        metrics: NowPlayingLayoutMetrics,
        showsPlaybackControl: Bool
    ) -> some View {
        HStack(spacing: metrics.compactSpacing) {
            artwork(size: metrics.compactArtworkSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            compactDetails(showsPlaybackControl: showsPlaybackControl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(metrics.compactPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func artwork(size: CGFloat) -> some View {
        SongArtwork(
            artwork: song.artwork,
            size: size,
            usesHighResolutionSource: true
        )
    }

    private func detailsAndControls(metrics: NowPlayingLayoutMetrics) -> some View {
        VStack(spacing: metrics.contentSpacing) {
            Spacer(minLength: 0)

            metadata

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
                playbackMode: playbackMode,
                onSelectPlaybackMode: onSelectPlaybackMode,
                onShowQueue: onShowQueue
            )

            Spacer(minLength: 0)
        }
    }

    private func compactDetails(showsPlaybackControl: Bool) -> some View {
        VStack(spacing: 12) {
            Text(song.title)
                .font(.headline)
                .lineLimit(showsPlaybackControl ? 3 : 2)
                .multilineTextAlignment(.center)

            if showsPlaybackControl {
                LargePlayerControlButton(
                    title: isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    isPrimary: true,
                    action: onTogglePlayback
                )
            }
        }
    }

    private var metadata: some View {
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
    }
}

private enum NowPlayingLayout: Equatable {
    case fullVertical
    case fullHorizontal
    case compactVertical
    case compactHorizontal
    case minimalVertical
    case minimalHorizontal
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

    var layout: NowPlayingLayout {
#if os(macOS)
        if usesHorizontalLayout, validWidth >= 520, validHeight >= 300 {
            return .fullHorizontal
        }

        if !usesHorizontalLayout, validWidth >= 300, validHeight >= 450 {
            return .fullVertical
        }

        if usesHorizontalLayout, validWidth >= 300, validHeight >= 150 {
            return .compactHorizontal
        }

        if !usesHorizontalLayout, validWidth >= 180, validHeight >= 240 {
            return .compactVertical
        }

        return usesHorizontalLayout ? .minimalHorizontal : .minimalVertical
#else
        return usesHorizontalLayout ? .fullHorizontal : .fullVertical
#endif
    }

    private var isCompact: Bool {
        availableSize.height < 650
    }

    var outerPadding: CGFloat {
        isCompact ? 16 : 24
    }

    var contentSpacing: CGFloat {
        isCompact ? 12 : 20
    }

    var columnSpacing: CGFloat {
        isCompact ? 20 : 32
    }

    var controlSpacing: CGFloat {
        isCompact ? 30 : 42
    }

    var artworkSize: CGFloat {
        if usesHorizontalLayout {
            return max(
                min(
                    (validWidth - outerPadding * 2 - columnSpacing) / 2,
                    validHeight - outerPadding * 2,
                    460
                ),
                1
            )
        }

        return max(
            min(
                validWidth - outerPadding * 2,
                validHeight * (isCompact ? 0.38 : 0.46),
                380
            ),
            1
        )
    }

    var compactPadding: CGFloat {
        min(validWidth, validHeight) < 240 ? 10 : 16
    }

    var compactSpacing: CGFloat {
        min(validWidth, validHeight) < 240 ? 8 : 16
    }

    var compactArtworkSize: CGFloat {
        if usesHorizontalLayout {
            return max(
                min(
                    (validWidth - compactPadding * 2 - compactSpacing) / 2,
                    validHeight - compactPadding * 2,
                    360
                ),
                1
            )
        }

        let reservedHeight: CGFloat = layout == .compactVertical ? 120 : 34

        return max(
            min(
                validWidth - compactPadding * 2,
                validHeight - compactPadding * 2 - compactSpacing - reservedHeight,
                360
            ),
            1
        )
    }

    private var usesHorizontalLayout: Bool {
        validWidth > validHeight
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
