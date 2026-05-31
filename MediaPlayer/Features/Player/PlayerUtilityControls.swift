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
    let onShowQueue: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AudioRoutePickerButton(usesGlassBackground: true)

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
    let onShowQueue: () -> Void

    var body: some View {
        Menu {
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
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 30, height: 30)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("More Player Options")
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
