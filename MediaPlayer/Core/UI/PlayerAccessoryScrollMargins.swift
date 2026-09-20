//
//  PlayerAccessoryScrollMargins.swift
//  MediaPlayer
//

import SwiftUI

private struct PlayerAccessoryHeightKey: EnvironmentKey {
    nonisolated static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var playerAccessoryHeight: CGFloat {
        get { self[PlayerAccessoryHeightKey.self] }
        set { self[PlayerAccessoryHeightKey.self] = newValue }
    }
}

private struct PlayerAccessoryScrollMargins: ViewModifier {
    @Environment(\.playerAccessoryHeight) private var playerAccessoryHeight

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: max(playerAccessoryHeight, 0))
                    .accessibilityHidden(true)
            }
#else
        content
            .contentMargins(
                .bottom,
                playerAccessoryHeight,
                for: .scrollContent
            )
            .contentMargins(
                .bottom,
                playerAccessoryHeight,
                for: .scrollIndicators
            )
#endif
    }
}

extension View {
    func avoidsPlayerAccessory() -> some View {
        modifier(PlayerAccessoryScrollMargins())
    }
}
