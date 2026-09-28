//
//  NowPlayingView.swift
//  MediaPlayer
//
//

import Combine
import Foundation
import MusicKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct NowPlayingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var artworkAccentTheme: ArtworkAccentTheme
    @ObservedObject var player: MusicPlayerViewModel
    let onOpenArtist: ((Song) -> Void)?
    let onOpenAlbum: ((Song) -> Void)?
    @State private var isShowingQueue = false
    @State private var detailsSong: Song?
    @State private var artworkLoadState = HighResolutionArtworkState()

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
                    artworkLoadState: $artworkLoadState,
                    accentColor: artworkAccentTheme.color,
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
                    onShowTrackInfo: {
                        detailsSong = song
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
        .background {
            if let artwork = player.currentSong?.artwork {
                PlayerArtworkBackground(artwork: artwork)
            }
        }
        .environment(
            \.colorScheme,
            player.currentSong?.artwork == nil ? colorScheme : .dark
        )
        .sheet(isPresented: $isShowingQueue) {
            PlaybackQueueView(player: player)
        }
        .sheet(item: $detailsSong) { song in
            TrackDetailsView(song: song)
        }
    }
}

struct PlayerArtworkBackground: View {
    let artwork: Artwork

    var body: some View {
        GeometryReader { geometry in
            let dimension = max(geometry.size.width, geometry.size.height)
                + BackgroundStyle.blurInset * 2

            HighResolutionArtworkImage(
                artwork: artwork,
                size: dimension,
                maximumPixelDimension: BackgroundStyle.maximumPixelDimension
            )
            .blur(radius: BackgroundStyle.blurRadius)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(BackgroundStyle.topDimming),
                        .black.opacity(BackgroundStyle.bottomDimming)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private enum BackgroundStyle {
    static let blurRadius: CGFloat = 35
    static let blurInset: CGFloat = 50
    static let maximumPixelDimension = 1600
    static let topDimming = 0.5
    static let bottomDimming = 0.68
}

private struct NowPlayingContent: View {
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    let song: Song
    let isPlaying: Bool
    let playbackMode: PlaybackMode
    @ObservedObject var playbackTime: PlaybackTimeState
    let artworkLoadState: Binding<HighResolutionArtworkState>
    let accentColor: Color?
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void
    let onShowTrackInfo: () -> Void
    let onOpenArtist: ((Song) -> Void)?
    let onOpenAlbum: ((Song) -> Void)?
    @StateObject private var immersiveControls = ImmersiveControlsVisibility()

    var body: some View {
        GeometryReader { geometry in
            let metrics = NowPlayingLayoutMetrics(availableSize: geometry.size)

            Group {
                switch metrics.layout {
                case .immersive:
                    immersiveLayout(metrics: metrics)
                case .fullHorizontal:
                    horizontalLayout(metrics: metrics)
                case .fullVertical:
                    verticalLayout(metrics: metrics)
                case .compactHorizontal:
                    compactHorizontalLayout(metrics: metrics, showsTransportControls: true)
                case .compactVertical:
                    compactVerticalLayout(metrics: metrics, showsTransportControls: true)
                case .minimalWideHorizontal:
                    minimalWideHorizontalLayout(metrics: metrics)
                case .minimalHorizontal:
                    compactHorizontalLayout(metrics: metrics, showsTransportControls: false)
                case .minimalVertical:
                    compactVerticalLayout(metrics: metrics, showsTransportControls: false)
                }
            }
            .onChange(
                of: metrics.layout == .immersive && !accessibilityEnabled,
                initial: true
            ) { _, shouldAutoHide in
                if shouldAutoHide {
                    immersiveControls.activate()
                } else {
                    immersiveControls.deactivate()
                }
            }
        }
        .onDisappear {
            immersiveControls.deactivate()
        }
#if os(macOS)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
        ) { _ in
            immersiveControls.restoreCursor()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
        ) { _ in
            immersiveControls.restoreCursor()
        }
#endif
    }

    private func immersiveLayout(metrics: NowPlayingLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: metrics.immersiveColumnSpacing) {
                artwork(size: metrics.immersiveArtworkSize)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                immersiveMetadata(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: NowPlayingContentMetrics.immersiveControlSpacing) {
                HStack {
                    transportControls(spacing: NowPlayingContentMetrics.immersiveTransportSpacing)

                    Spacer(minLength: NowPlayingContentMetrics.immersiveControlSpacing)

                    PlayerUtilityControls(
                        playbackMode: playbackMode,
                        onSelectPlaybackMode: onSelectPlaybackMode,
                        onShowQueue: onShowQueue,
                        onShowTrackInfo: onShowTrackInfo
                    )
                }

                PlaybackProgressSlider(
                    playbackTime: playbackTime.value,
                    duration: song.duration,
                    onSeek: onSeek
                )
                .id(song.id)
                .tint(accentColor ?? .accentColor)
            }
            .frame(
                height: immersiveControls.isVisible
                    ? metrics.immersiveControlsHeight
                    : 0,
                alignment: .bottom
            )
            .opacity(immersiveControls.isVisible ? 1 : 0)
            .allowsHitTesting(immersiveControls.isVisible)
            .accessibilityHidden(!immersiveControls.isVisible)
        }
        .padding(metrics.immersiveOuterPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                immersiveControls.pointerMoved(to: location)
            case .ended:
                immersiveControls.pointerLeft()
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                immersiveControls.recordActivity()
            }
        )
    }

    private func immersiveMetadata(metrics: NowPlayingLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: NowPlayingContentMetrics.immersiveMetadataSpacing) {
            Text(song.title)
                .font(.system(size: metrics.immersiveTitleSize, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            PlayerMetadataLink(
                title: song.artistName,
                font: .system(size: metrics.immersiveArtistSize, weight: .medium),
                foregroundStyle: .secondary,
                action: onOpenArtist.map { action in
                    { action(song) }
                }
            )

            PlayerMetadataLink(
                title: song.albumTitle ?? "Unknown Album",
                font: .system(size: metrics.immersiveAlbumSize),
                foregroundStyle: .tertiary,
                action: onOpenAlbum.map { action in
                    { action(song) }
                }
            )
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
        showsTransportControls: Bool
    ) -> some View {
        VStack(spacing: metrics.compactSpacing) {
            artwork(size: metrics.compactArtworkSize)
            compactDetails(
                showsTransportControls: showsTransportControls,
                titleLineLimit: showsTransportControls
                    ? NowPlayingContentMetrics.compactTitleLineLimit
                    : NowPlayingContentMetrics.minimalTitleLineLimit
            )
        }
        .padding(metrics.compactPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactHorizontalLayout(
        metrics: NowPlayingLayoutMetrics,
        showsTransportControls: Bool
    ) -> some View {
        HStack(spacing: metrics.compactSpacing) {
            artwork(size: metrics.compactArtworkSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            compactDetails(
                showsTransportControls: showsTransportControls,
                titleLineLimit: NowPlayingContentMetrics.horizontalTitleLineLimit
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(metrics.compactPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func minimalWideHorizontalLayout(metrics: NowPlayingLayoutMetrics) -> some View {
        HStack(spacing: metrics.compactSpacing) {
            artwork(
                size: min(
                    metrics.compactArtworkSize,
                    NowPlayingContentMetrics.wideMinimalArtworkMaximumSize
                )
            )

            VStack(alignment: .leading, spacing: NowPlayingContentMetrics.metadataSpacing) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(song.artistName) · \(song.albumTitle ?? "Unknown Album")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            transportControls(spacing: NowPlayingContentMetrics.compactControlSpacing)
        }
        .padding(metrics.compactPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func artwork(size: CGFloat) -> some View {
        SongArtwork(
            artwork: song.artwork,
            size: size,
            usesHighResolutionSource: true,
            highResolutionState: artworkLoadState
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
            .id(song.id)
            .tint(accentColor ?? .accentColor)

            transportControls(spacing: metrics.controlSpacing)

            PlayerUtilityControls(
                playbackMode: playbackMode,
                onSelectPlaybackMode: onSelectPlaybackMode,
                onShowQueue: onShowQueue,
                onShowTrackInfo: onShowTrackInfo
            )

            Spacer(minLength: 0)
        }
    }

    private func compactDetails(
        showsTransportControls: Bool,
        titleLineLimit: Int
    ) -> some View {
        VStack(spacing: NowPlayingContentMetrics.compactDetailsSpacing) {
            Text(song.title)
                .font(.headline)
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.center)

            if showsTransportControls {
                PlaybackProgressSlider(
                    playbackTime: playbackTime.value,
                    duration: song.duration,
                    onSeek: onSeek
                )
                .id(song.id)
                .tint(accentColor ?? .accentColor)

                transportControls(spacing: NowPlayingContentMetrics.compactControlSpacing)
            } else {
                LargePlayerControlButton(
                    title: isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    isPrimary: true,
                    size: PlayerControlMetrics.regularButtonSize,
                    accentColor: accentColor,
                    action: onTogglePlayback
                )
            }
        }
    }

    private func transportControls(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            LargePlayerControlButton(
                title: "Previous track",
                systemImage: "backward.fill",
                action: onPrevious
            )
            LargePlayerControlButton(
                title: isPlaying ? "Pause" : "Play",
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                isPrimary: true,
                accentColor: accentColor,
                action: onTogglePlayback
            )
            LargePlayerControlButton(
                title: "Next track",
                systemImage: "forward.fill",
                action: onNext
            )
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
    static let compactDetailsSpacing: CGFloat = 8
    static let compactControlSpacing: CGFloat = 8
    static let immersiveControlSpacing: CGFloat = 24
    static let immersiveTransportSpacing: CGFloat = 20
    static let immersiveMetadataSpacing: CGFloat = 18
    static let metadataSpacing: CGFloat = 6
    static let wideMinimalArtworkMaximumSize: CGFloat = 96
    static let horizontalTitleLineLimit = 1
    static let compactTitleLineLimit = 3
    static let minimalTitleLineLimit = 2
    static let titleLineLimit = 2
}

@MainActor
private final class ImmersiveControlsVisibility: ObservableObject {
    @Published private(set) var isVisible = true

    private var isActive = false
    private var lastActivityAt = Date()
    private var lastPointerLocation: CGPoint?
    private var hideTask: Task<Void, Never>?
#if os(macOS)
    private var cursorIsHidden = false
#endif

    func activate() {
        guard !isActive else {
            return
        }

        isActive = true
        lastActivityAt = Date()
        isVisible = true
        scheduleHide()
    }

    func deactivate() {
#if os(macOS)
        restoreCursor()
#endif
        guard isActive else {
            return
        }

        isActive = false
        hideTask?.cancel()
        hideTask = nil
        lastPointerLocation = nil
        isVisible = true
    }

    func recordActivity() {
#if os(macOS)
        restoreCursor()
#endif
        guard isActive else {
            return
        }

        lastActivityAt = Date()
        if !isVisible {
            withAnimation(.easeInOut(duration: Constants.fadeDuration)) {
                isVisible = true
            }
        }
        scheduleHide()
    }

    func pointerMoved(to location: CGPoint) {
        guard lastPointerLocation != location else {
            return
        }

        lastPointerLocation = location
        recordActivity()
    }

    func pointerLeft() {
        lastPointerLocation = nil
#if os(macOS)
        restoreCursor()
#endif
    }

#if os(macOS)
    func restoreCursor() {
        guard cursorIsHidden else {
            return
        }

        NSCursor.setHiddenUntilMouseMoves(false)
        cursorIsHidden = false
    }

    private func hideCursorIfNeeded() {
        guard !cursorIsHidden,
              lastPointerLocation != nil,
              NSApp.isActive,
              let keyWindow = NSApp.keyWindow,
              keyWindow.frame.contains(NSEvent.mouseLocation) else {
            return
        }

        NSCursor.setHiddenUntilMouseMoves(true)
        cursorIsHidden = true
    }
#endif

    private func scheduleHide() {
        guard hideTask == nil else {
            return
        }

        hideTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            while self.isActive {
                let remaining =
                    Constants.inactivityInterval
                        - Date().timeIntervalSince(self.lastActivityAt)
                if remaining <= 0 {
                    withAnimation(.easeInOut(duration: Constants.fadeDuration)) {
                        self.isVisible = false
                    }
#if os(macOS)
                    self.hideCursorIfNeeded()
#endif
                    self.hideTask = nil
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    private enum Constants {
        static let inactivityInterval: TimeInterval = 4
        static let fadeDuration: TimeInterval = 0.35
    }
}

enum NowPlayingLayout: Equatable {
    case immersive
    case fullVertical
    case fullHorizontal
    case compactVertical
    case compactHorizontal
    case minimalVertical
    case minimalWideHorizontal
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

struct NowPlayingLayoutMetrics {
    let availableSize: CGSize

    var layout: NowPlayingLayout {
        if validWidth >= Constants.immersiveMinimumWidth,
           validHeight >= Constants.immersiveMinimumHeight {
            return .immersive
        }

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

        if usesHorizontalLayout,
           validWidth >= Constants.minimalWideHorizontalMinimumWidth,
           validHeight >= Constants.minimalWideHorizontalMinimumHeight {
            return .minimalWideHorizontal
        }

        return usesHorizontalLayout ? .minimalHorizontal : .minimalVertical
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

    var immersiveOuterPadding: CGFloat {
        min(max(validWidth * Constants.immersiveOuterPaddingRatio, 36), 80)
    }

    var immersiveColumnSpacing: CGFloat {
        min(max(validWidth * Constants.immersiveColumnSpacingRatio, 48), 88)
    }

    var immersiveControlsHeight: CGFloat {
        Constants.immersiveControlsHeight
    }

    var immersiveArtworkSize: CGFloat {
        let widthLimit =
            (validWidth - immersiveOuterPadding * 2 - immersiveColumnSpacing) / 2
        let heightLimit =
            (validHeight - immersiveOuterPadding * 2 - immersiveControlsHeight)
                * Constants.immersiveArtworkHeightRatio

        return max(
            min(widthLimit, heightLimit, Constants.maximumImmersiveArtworkSize),
            Constants.minimumDimension
        )
    }

    var immersiveTitleSize: CGFloat {
        min(max(validWidth * 0.038, 42), 72)
    }

    var immersiveArtistSize: CGFloat {
        min(max(validWidth * 0.022, 26), 40)
    }

    var immersiveAlbumSize: CGFloat {
        min(max(validWidth * 0.017, 21), 30)
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
        static let immersiveMinimumWidth: CGFloat = 880
        static let immersiveMinimumHeight: CGFloat = 560
        static let immersiveOuterPaddingRatio: CGFloat = 0.04
        static let immersiveColumnSpacingRatio: CGFloat = 0.05
        static let immersiveControlsHeight: CGFloat = 150
        static let immersiveArtworkHeightRatio: CGFloat = 0.85
        static let maximumImmersiveArtworkSize: CGFloat = 720
        static let fullHorizontalMinimumWidth: CGFloat = 520
        static let fullHorizontalMinimumHeight: CGFloat = 300
        static let fullVerticalMinimumWidth: CGFloat = 300
        static let fullVerticalMinimumHeight: CGFloat = 450
        static let compactHorizontalMinimumWidth: CGFloat = 360
        static let compactHorizontalMinimumHeight: CGFloat = 170
        static let compactVerticalMinimumWidth: CGFloat = 180
        static let compactVerticalMinimumHeight: CGFloat = 300
        static let minimalWideHorizontalMinimumWidth: CGFloat = 440
        static let minimalWideHorizontalMinimumHeight: CGFloat = 80

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
        static let compactDetailsReservedHeight: CGFloat = 180
        static let minimalDetailsReservedHeight: CGFloat = 100
    }
}

private struct LargePlayerControlButton: View {
    let title: String
    let systemImage: String
    var isPrimary = false
    var size: CGFloat? = nil
    var accentColor: Color? = nil
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if isPrimary {
            button
                .buttonStyle(.glassProminent)
                .tint(accentColor ?? .accentColor)
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
        size ?? (isPrimary
            ? PlayerControlMetrics.primaryButtonSize
            : PlayerControlMetrics.regularButtonSize)
    }
}
