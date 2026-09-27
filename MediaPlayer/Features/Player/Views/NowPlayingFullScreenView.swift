//
//  NowPlayingFullScreenView.swift
//  MediaPlayer
//
//

#if os(iOS)
import MusicKit
import SwiftUI

struct NowPlayingFullScreenView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var player: MusicPlayerViewModel
    let onOpenArtist: (Song) -> Void
    let onOpenAlbum: (Song) -> Void

    var body: some View {
        NavigationStack {
            NowPlayingView(
                player: player,
                onOpenArtist: onOpenArtist,
                onOpenAlbum: onOpenAlbum
            )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: dismiss.callAsFunction) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
        }
        .tint(nil)
    }
}
#endif
