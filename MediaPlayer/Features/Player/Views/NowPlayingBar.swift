//
//  NowPlayingBar.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct NowPlayingBar: View {
    let song: Song
    let isPlaying: Bool
    let playbackMode: PlaybackMode
    @ObservedObject var playbackTime: PlaybackTimeState
    let bottomSafeAreaInset: CGFloat
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void
    let onOpenDetails: () -> Void
    let onOpenTrackInfo: (Song) -> Void
    let onOpenArtist: (Song) -> Void
    let onOpenAlbum: (Song) -> Void
    @State private var availableWidth: CGFloat = 0
#if os(iOS)
    @State private var bottomCornerInset: CGFloat = 0
#endif

    var body: some View {
        VStack(spacing: Layout.sectionSpacing) {
            PlaybackProgressSlider(
                playbackTime: playbackTime.value,
                duration: song.duration,
                onSeek: onSeek
            )
            .id(song.id)

            HStack(spacing: Layout.controlSpacing) {
                trackSummary
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                Spacer(minLength: Layout.minimumControlSpacing)

                if layout.showsUtilityActions {
                    AudioRoutePickerButton()
                    CompactPlayerOptionsMenu(
                        playbackMode: playbackMode,
                        onSelectPlaybackMode: onSelectPlaybackMode,
                        onShowQueue: onShowQueue
                    )
                }

#if os(macOS)
                if layout.showsPlayerWindow {
                    PlayerControlButton(
                        title: "Track Info",
                        systemImage: "info.circle",
                        action: { onOpenTrackInfo(song) }
                    )
                    PlayerControlButton(
                        title: "Open Player",
                        systemImage: "macwindow",
                        action: onOpenDetails
                    )
                }
#endif
                if layout.showsTrackNavigation {
                    PlayerControlButton(
                        title: "Previous track",
                        systemImage: "backward.fill",
                        action: onPrevious
                    )
                }
                PlayerControlButton(
                    title: isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    action: onTogglePlayback
                )
                if layout.showsTrackNavigation {
                    PlayerControlButton(
                        title: "Next track",
                        systemImage: "forward.fill",
                        action: onNext
                    )
                }
            }
            .tint(.secondary)
        }
        .padding(.horizontal, contentEdgePadding)
        .padding(.top, contentEdgePadding)
        .padding(.bottom, contentBottomPadding)
        .background {
            barShape
                .fill(.clear)
                .contentShape(barShape)
                .onTapGesture(perform: handleBackgroundTap)
        }
        .glassEffect(
            .regular,
            in: barShape
        )
#if os(iOS)
        .onGeometryChange(for: CGFloat.self) { geometry in
            let corners = geometry.containerCornerInsets
            return max(
                max(corners.bottomLeading.width, corners.bottomLeading.height),
                max(corners.bottomTrailing.width, corners.bottomTrailing.height)
            )
        } action: { inset in
            bottomCornerInset = inset
        }
#endif
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.verticalPadding)
        .padding(.bottom, Layout.bottomPadding)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            availableWidth = width
        }
    }

    private var layout: NowPlayingBarLayout {
        NowPlayingBarLayout(
            availableWidth: max(
                availableWidth - 2 * (contentEdgePadding - Layout.contentPadding),
                0
            )
        )
    }

    private var barShape: ConcentricRectangle {
        ConcentricRectangle(uniformMinimumCornerRadius: Layout.minimumCornerRadius)
    }

    private var contentEdgePadding: CGFloat {
#if os(iOS)
        let cornerExtent = max(
            bottomCornerInset,
            bottomSafeAreaInset + Layout.horizontalPadding
        )
        return min(
            max(Layout.contentPadding, cornerExtent / 2),
            Layout.maximumContentEdgePadding
        )
#else
        Layout.contentPadding
#endif
    }

    private var contentBottomPadding: CGFloat {
#if os(iOS)
        max(
            contentEdgePadding,
            bottomSafeAreaInset - Layout.bottomPadding + Layout.safeAreaClearance
        )
#else
        Layout.contentPadding
#endif
    }

    private func handleBackgroundTap() {
#if os(iOS)
        onOpenDetails()
#endif
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
        HStack(spacing: Layout.trackSpacing) {
            SongArtwork(
                artwork: song.artwork,
                size: Layout.artworkSize,
                usesHighResolutionSource: true,
                cornerRadius: max(
                    Layout.minimumArtworkCornerRadius,
                    contentEdgePadding / 2
                )
            )

            VStack(alignment: .leading, spacing: Layout.metadataSpacing) {
#if os(macOS)
                Button {
                    onOpenTrackInfo(song)
                } label: {
                    Text(song.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Track Info")
#else
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
#endif
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

private enum NowPlayingBarLayout {
    case expanded
    case withoutUtilityActions
    case transportOnly
    case playbackOnly

    init(availableWidth: CGFloat) {
        switch availableWidth {
        case Layout.expandedMinimumWidth...:
            self = .expanded
        case Layout.withoutUtilityActionsMinimumWidth...:
            self = .withoutUtilityActions
        case Layout.transportOnlyMinimumWidth...:
            self = .transportOnly
        default:
            self = .playbackOnly
        }
    }

    var showsUtilityActions: Bool {
        self == .expanded
    }

    var showsPlayerWindow: Bool {
        self == .expanded || self == .withoutUtilityActions
    }

    var showsTrackNavigation: Bool {
        self != .playbackOnly
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
                .frame(
                    width: PlayerControlMetrics.compactButtonSize,
                    height: PlayerControlMetrics.compactButtonSize
                )
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
    }
}

private enum Layout {
    static let sectionSpacing: CGFloat = 8
    static let controlSpacing: CGFloat = 10
    static let minimumControlSpacing: CGFloat = 4
    static let contentPadding: CGFloat = 12
    static let minimumCornerRadius: CGFloat = 12
#if os(iOS)
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 16
    static let maximumContentEdgePadding: CGFloat = 30
    static let safeAreaClearance: CGFloat = 4
    static let bottomPadding: CGFloat = horizontalPadding
#else
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 8
    static let bottomPadding: CGFloat = verticalPadding
#endif
    static let trackSpacing: CGFloat = 12
    static let artworkSize: CGFloat = 52
    static let minimumArtworkCornerRadius: CGFloat = 7
    static let metadataSpacing: CGFloat = 3

    static let expandedMinimumWidth: CGFloat = 540
    static let withoutUtilityActionsMinimumWidth: CGFloat = 440
    static let transportOnlyMinimumWidth: CGFloat = 360
}
