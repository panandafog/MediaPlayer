//
//  PlaybackProgressSlider.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct PlaybackProgressSlider: View {
    let playbackTime: TimeInterval
    let duration: TimeInterval?
    let onSeek: (TimeInterval) -> Void

    @State private var sliderValue: TimeInterval = 0
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: $sliderValue,
                in: 0...maximumTime,
                onEditingChanged: handleEditingChanged
            )
            .disabled(!hasKnownDuration)
            .accessibilityLabel("Playback position")
            .accessibilityValue(TrackDurationFormatter.string(from: sliderValue))

            HStack {
                Text(TrackDurationFormatter.string(from: sliderValue))
                Spacer()
                Text(TrackDurationFormatter.string(from: duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .onAppear {
            syncSliderValue()
        }
        .onChange(of: playbackTime) {
            syncSliderValue()
        }
        .onChange(of: duration) {
            syncSliderValue()
        }
    }

    private var hasKnownDuration: Bool {
        guard let duration else {
            return false
        }

        return duration.isFinite && duration > 0
    }

    private var maximumTime: TimeInterval {
        hasKnownDuration ? duration ?? 1 : 1
    }

    private func handleEditingChanged(_ editing: Bool) {
        isEditing = editing

        if !editing {
            onSeek(sliderValue)
        }
    }

    private func syncSliderValue() {
        guard !isEditing else {
            return
        }

        sliderValue = PlaybackProgress.normalizedTime(playbackTime, duration: duration)
    }
}
