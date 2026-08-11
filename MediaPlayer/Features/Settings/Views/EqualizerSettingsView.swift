//
//  EqualizerSettingsView.swift
//  MediaPlayer
//

import SwiftUI

struct EqualizerSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            LabeledContent("Playback Support") {
                Text("Requires Local Engine")
                    .foregroundStyle(.secondary)
            }

            ForEach(EqualizerBand.allCases) { band in
                EqualizerBandSlider(band: band)
            }

            Button("Reset Preset", action: resetPreset)

            Text(
                "MusicKit playback does not expose an audio processing pipeline. "
                    + "This preset is saved for the local-file playback engine."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func resetPreset() {
        for band in EqualizerBand.allCases {
            UserDefaults.standard.set(0.0, forKey: band.defaultsKey)
        }
    }
}

private struct EqualizerBandSlider: View {
    let band: EqualizerBand

    @AppStorage private var gain: Double

    init(band: EqualizerBand) {
        self.band = band
        _gain = AppStorage(wrappedValue: 0.0, band.defaultsKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.bandSpacing) {
            HStack {
                Text(band.title)

                Spacer()

                Text("\(gain.formatted(.number.precision(.fractionLength(1)))) dB")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $gain,
                in: EqualizerRange.minimumGain...EqualizerRange.maximumGain,
                step: EqualizerRange.step
            )
        }
    }
}

private enum Layout {
    static let sectionSpacing: CGFloat = 16
    static let bandSpacing: CGFloat = 6
}

private enum EqualizerRange {
    static let minimumGain = -12.0
    static let maximumGain = 12.0
    static let step = 0.5
}

#Preview {
    Form {
        Section("Equalizer") {
            EqualizerSettingsView()
        }
    }
}
