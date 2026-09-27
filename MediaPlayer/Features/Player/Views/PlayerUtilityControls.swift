//
//  PlayerUtilityControls.swift
//  MediaPlayer
//
//

import SwiftUI

struct PlayerUtilityControls: View {
    let playbackMode: PlaybackMode
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void
    let onShowTrackInfo: () -> Void

    var body: some View {
        HStack(spacing: Layout.controlSpacing) {
            AudioRoutePickerButton(usesGlassBackground: true)

            PlaybackModeMenu(
                playbackMode: playbackMode,
                onSelect: onSelectPlaybackMode
            )

            UtilityButton(
                title: "Playing Next",
                systemImage: "list.bullet",
                action: onShowQueue
            )

            UtilityButton(
                title: "Track Info",
                systemImage: "info.circle",
                action: onShowTrackInfo
            )
        }
    }
}

struct CompactPlayerOptionsMenu: View {
    let playbackMode: PlaybackMode
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void
#if os(macOS)
    @State private var isShowingOptions = false
#endif

    @ViewBuilder
    var body: some View {
#if os(macOS)
        Button {
            isShowingOptions.toggle()
        } label: {
            compactMenuLabel
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $isShowingOptions, arrowEdge: .bottom) {
            macOSOptionsPopover
        }
        .accessibilityLabel("More Player Options")
#else
        Menu {
            PlaybackModeMenuContent(
                playbackMode: playbackMode,
                onSelect: onSelectPlaybackMode
            )

            Divider()

            Button(action: onShowQueue) {
                Label("Playing Next", systemImage: "list.bullet")
            }
        } label: {
            compactMenuLabel
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("More Player Options")
#endif
    }

    private var compactMenuLabel: some View {
        Image(systemName: "ellipsis.circle")
            .font(.title3)
            .frame(
                width: PlayerControlMetrics.compactButtonSize,
                height: PlayerControlMetrics.compactButtonSize
            )
            .contentShape(Rectangle())
    }

#if os(macOS)
    private var macOSOptionsPopover: some View {
        VStack(alignment: .leading, spacing: Layout.popoverRowSpacing) {
            ForEach(PlaybackMode.allCases) { mode in
                Button {
                    isShowingOptions = false
                    onSelectPlaybackMode(mode)
                } label: {
                    Label {
                        Text(mode.title)
                    } icon: {
                        Image(systemName: mode == playbackMode ? "checkmark" : mode.systemImage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button {
                isShowingOptions = false
                onShowQueue()
            } label: {
                Label("Playing Next", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(Layout.popoverPadding)
        .frame(width: Layout.popoverWidth)
    }
#endif
}

private struct PlaybackModeMenu: View {
    let playbackMode: PlaybackMode
    let onSelect: (PlaybackMode) -> Void

    var body: some View {
        Menu {
            PlaybackModeMenuContent(
                playbackMode: playbackMode,
                onSelect: onSelect
            )
        } label: {
            Image(systemName: playbackMode.systemImage)
                .font(.title3)
                .frame(
                    width: PlayerControlMetrics.regularButtonSize,
                    height: PlayerControlMetrics.regularButtonSize
                )
        }
        .menuIndicator(.hidden)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Listening Mode: \(playbackMode.title)")
    }
}

private struct PlaybackModeMenuContent: View {
    let playbackMode: PlaybackMode
    let onSelect: (PlaybackMode) -> Void

    var body: some View {
        ForEach(PlaybackMode.allCases) { mode in
            Button {
                onSelect(mode)
            } label: {
                Label {
                    Text(mode.title)
                } icon: {
                    Image(systemName: mode == playbackMode ? "checkmark" : mode.systemImage)
                }
            }
        }
    }
}

private struct UtilityButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(
                    width: PlayerControlMetrics.regularButtonSize,
                    height: PlayerControlMetrics.regularButtonSize
                )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(title)
    }
}

private enum Layout {
    static let controlSpacing: CGFloat = 14
    static let popoverRowSpacing: CGFloat = 4
    static let popoverPadding: CGFloat = 10
    static let popoverWidth: CGFloat = 190
}
