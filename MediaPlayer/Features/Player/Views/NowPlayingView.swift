//
//  NowPlayingView.swift
//  MediaPlayer
//
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
        VStack(spacing: NowPlayingContentMetrics.compactDetailsSpacing) {
            Text(song.title)
                .font(.headline)
                .lineLimit(
                    showsPlaybackControl
                        ? NowPlayingContentMetrics.compactTitleLineLimit
                        : NowPlayingContentMetrics.minimalTitleLineLimit
                )
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
        VStack(spacing: NowPlayingContentMetrics.metadataSpacing) {
            Text(song.title)
                .font(.title2.weight(.semibold))
                .lineLimit(NowPlayingContentMetrics.titleLineLimit)
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

private enum NowPlayingContentMetrics {
    static let compactDetailsSpacing: CGFloat = 12
    static let metadataSpacing: CGFloat = 6
    static let compactTitleLineLimit = 3
    static let minimalTitleLineLimit = 2
    static let titleLineLimit = 2
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
        if usesHorizontalLayout,
           validWidth >= Constants.fullHorizontalMinimumWidth,
           validHeight >= Constants.fullHorizontalMinimumHeight {
            return .fullHorizontal
        }

        if !usesHorizontalLayout,
           validWidth >= Constants.fullVerticalMinimumWidth,
           validHeight >= Constants.fullVerticalMinimumHeight {
            return .fullVertical
        }

        if usesHorizontalLayout,
           validWidth >= Constants.compactHorizontalMinimumWidth,
           validHeight >= Constants.compactHorizontalMinimumHeight {
            return .compactHorizontal
        }

        if !usesHorizontalLayout,
           validWidth >= Constants.compactVerticalMinimumWidth,
           validHeight >= Constants.compactVerticalMinimumHeight {
            return .compactVertical
        }

        return usesHorizontalLayout ? .minimalHorizontal : .minimalVertical
#else
        return usesHorizontalLayout ? .fullHorizontal : .fullVertical
#endif
    }

    private var isCompact: Bool {
        availableSize.height < Constants.compactHeightThreshold
    }

    var outerPadding: CGFloat {
        isCompact ? Constants.compactOuterPadding : Constants.regularOuterPadding
    }

    var contentSpacing: CGFloat {
        isCompact ? Constants.compactContentSpacing : Constants.regularContentSpacing
    }

    var columnSpacing: CGFloat {
        isCompact ? Constants.compactColumnSpacing : Constants.regularColumnSpacing
    }

    var controlSpacing: CGFloat {
        isCompact ? Constants.compactControlSpacing : Constants.regularControlSpacing
    }

    var artworkSize: CGFloat {
        if usesHorizontalLayout {
            return max(
                min(
                    (validWidth - outerPadding * 2 - columnSpacing) / 2,
                    validHeight - outerPadding * 2,
                    Constants.maximumHorizontalArtworkSize
                ),
                Constants.minimumDimension
            )
        }

        return max(
            min(
                validWidth - outerPadding * 2,
                validHeight
                    * (isCompact
                        ? Constants.compactArtworkHeightRatio
                        : Constants.regularArtworkHeightRatio),
                Constants.maximumVerticalArtworkSize
            ),
            Constants.minimumDimension
        )
    }

    var compactPadding: CGFloat {
        usesConstrainedCompactLayout
            ? Constants.constrainedCompactPadding
            : Constants.regularCompactPadding
    }

    var compactSpacing: CGFloat {
        usesConstrainedCompactLayout
            ? Constants.constrainedCompactSpacing
            : Constants.regularCompactSpacing
    }

    var compactArtworkSize: CGFloat {
        if usesHorizontalLayout {
            return max(
                min(
                    (validWidth - compactPadding * 2 - compactSpacing) / 2,
                    validHeight - compactPadding * 2,
                    Constants.maximumCompactArtworkSize
                ),
                Constants.minimumDimension
            )
        }

        let reservedHeight = layout == .compactVertical
            ? Constants.compactDetailsReservedHeight
            : Constants.minimalDetailsReservedHeight

        return max(
            min(
                validWidth - compactPadding * 2,
                validHeight - compactPadding * 2 - compactSpacing - reservedHeight,
                Constants.maximumCompactArtworkSize
            ),
            Constants.minimumDimension
        )
    }

    private var usesConstrainedCompactLayout: Bool {
        min(validWidth, validHeight) < Constants.constrainedCompactSizeThreshold
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

    private enum Constants {
        static let fullHorizontalMinimumWidth: CGFloat = 520
        static let fullHorizontalMinimumHeight: CGFloat = 300
        static let fullVerticalMinimumWidth: CGFloat = 300
        static let fullVerticalMinimumHeight: CGFloat = 450
        static let compactHorizontalMinimumWidth: CGFloat = 300
        static let compactHorizontalMinimumHeight: CGFloat = 150
        static let compactVerticalMinimumWidth: CGFloat = 180
        static let compactVerticalMinimumHeight: CGFloat = 240

        static let compactHeightThreshold: CGFloat = 650
        static let compactOuterPadding: CGFloat = 16
        static let regularOuterPadding: CGFloat = 24
        static let compactContentSpacing: CGFloat = 12
        static let regularContentSpacing: CGFloat = 20
        static let compactColumnSpacing: CGFloat = 20
        static let regularColumnSpacing: CGFloat = 32
        static let compactControlSpacing: CGFloat = 30
        static let regularControlSpacing: CGFloat = 42

        static let maximumHorizontalArtworkSize: CGFloat = 460
        static let maximumVerticalArtworkSize: CGFloat = 380
        static let compactArtworkHeightRatio: CGFloat = 0.38
        static let regularArtworkHeightRatio: CGFloat = 0.46
        static let minimumDimension: CGFloat = 1

        static let constrainedCompactSizeThreshold: CGFloat = 240
        static let constrainedCompactPadding: CGFloat = 10
        static let regularCompactPadding: CGFloat = 16
        static let constrainedCompactSpacing: CGFloat = 8
        static let regularCompactSpacing: CGFloat = 16
        static let maximumCompactArtworkSize: CGFloat = 360
        static let compactDetailsReservedHeight: CGFloat = 120
        static let minimalDetailsReservedHeight: CGFloat = 34
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
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonBorderShape(.circle)
        .accessibilityLabel(title)
    }

    private var buttonSize: CGFloat {
        isPrimary
            ? PlayerControlMetrics.primaryButtonSize
            : PlayerControlMetrics.regularButtonSize
    }
}
