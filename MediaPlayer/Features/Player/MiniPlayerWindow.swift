//
//  MiniPlayerWindow.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

#if os(macOS)
import SwiftUI

struct MiniPlayerWindow: View {
    static let id = "mini-player"

    @ObservedObject var player: MusicPlayerViewModel

    var body: some View {
        NowPlayingView(player: player)
            .frame(
                minWidth: 320,
                idealWidth: 380,
                maxWidth: 460,
                minHeight: 480,
                idealHeight: 560,
                maxHeight: 680
            )
    }
}
#endif
