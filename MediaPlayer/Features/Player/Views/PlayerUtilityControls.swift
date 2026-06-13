//
//  PlayerUtilityControls.swift
//  MediaPlayer
//
//  Created by Codex on 01.06.2026.
//

import MusicKit
import SwiftUI

struct PlayerUtilityControls: View {
    let song: Song
    let playbackMode: PlaybackMode
    let onSelectPlaybackMode: (PlaybackMode) -> Void
    let onShowQueue: () -> Void

    var body: some View {
        HStack(spacing: 14) {
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

            TrackShareButton(song: song)
        }
    }
}

struct CompactPlayerOptionsMenu: View {
    let song: Song
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

            if let url = song.url {
                ShareLink(item: url) {
                    Label("Share Track Link", systemImage: "square.and.arrow.up")
                }
            } else {
                Button(action: {}) {
                    Label("Track Link Unavailable", systemImage: "square.and.arrow.up")
                }
                .disabled(true)
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
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
    }

#if os(macOS)
    private var macOSOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            if let url = song.url {
                ShareLink(item: url) {
                    Label("Share Track Link", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {}) {
                    Label("Track Link Unavailable", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
        .padding(10)
        .frame(width: 190)
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
                .frame(width: 42, height: 42)
        }
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
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(title)
    }
}

private struct TrackShareButton: View {
    let song: Song

    @ViewBuilder
    var body: some View {
        if let url = song.url {
            ShareLink(item: url) {
                label
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Share Track Link")
        } else {
            Button(action: {}) {
                label
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(true)
            .accessibilityLabel("Track Link Unavailable")
        }
    }

    private var label: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.title3)
            .frame(width: 42, height: 42)
    }
}
