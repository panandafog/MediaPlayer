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
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            PlaybackProgressSlider(
                playbackTime: playbackTime.value,
                duration: song.duration,
                onSeek: onSeek
            )

            HStack(spacing: 10) {
                trackSummary
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                if layout.showsUtilityActions {
                    AudioRoutePickerButton()
                    CompactPlayerOptionsMenu(
                        song: song,
                        playbackMode: playbackMode,
                        onSelectPlaybackMode: onSelectPlaybackMode,
                        onShowQueue: onShowQueue
                    )
                }

#if os(macOS)
                if layout.showsMiniPlayer {
                    PlayerControlButton(
                        title: "Open Mini Player",
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
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture(perform: handleBackgroundTap)
        }
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            availableWidth = width
        }
    }

    private var layout: NowPlayingBarLayout {
        NowPlayingBarLayout(availableWidth: availableWidth)
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

private enum NowPlayingBarLayout {
    case expanded
    case withoutUtilityActions
    case transportOnly
    case playbackOnly

    init(availableWidth: CGFloat) {
        switch availableWidth {
        case 540...:
            self = .expanded
        case 440...:
            self = .withoutUtilityActions
        case 360...:
            self = .transportOnly
        default:
            self = .playbackOnly
        }
    }

    var showsUtilityActions: Bool {
        self == .expanded
    }

    var showsMiniPlayer: Bool {
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
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
    }
}
