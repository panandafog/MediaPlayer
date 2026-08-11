//
//  AudioRoutePickerButton.swift
//  MediaPlayer
//
//

import AVKit
import SwiftUI

struct AudioRoutePickerButton: View {
    var usesGlassBackground = false

    @ViewBuilder
    var body: some View {
        if usesGlassBackground {
            routePicker
                .frame(
                    width: PlayerControlMetrics.compactButtonSize,
                    height: PlayerControlMetrics.compactButtonSize
                )
                .frame(
                    width: PlayerControlMetrics.regularButtonSize,
                    height: PlayerControlMetrics.regularButtonSize
                )
                .padding(PlayerControlMetrics.glassButtonPadding)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            routePicker
                .frame(
                    width: PlayerControlMetrics.compactButtonSize,
                    height: PlayerControlMetrics.compactButtonSize
                )
        }
    }

    private var routePicker: some View {
        PlatformAudioRoutePicker()
            .accessibilityLabel("Choose Audio Output")
    }
}

#if os(iOS)
private struct PlatformAudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.prioritizesVideoDevices = false
        routePicker.tintColor = .label
        routePicker.activeTintColor = .systemBlue
        return routePicker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#elseif os(macOS)
private struct PlatformAudioRoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.isRoutePickerButtonBordered = false
        return routePicker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
#endif
