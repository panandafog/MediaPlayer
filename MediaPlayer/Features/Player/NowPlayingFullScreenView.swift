//
//  NowPlayingFullScreenView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

#if os(iOS)
import SwiftUI

struct NowPlayingFullScreenView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var player: MusicPlayerViewModel

    var body: some View {
        NavigationStack {
            NowPlayingView(player: player)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: dismiss.callAsFunction) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
        }
    }
}
#endif
