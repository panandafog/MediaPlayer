//
//  SongArtwork.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct SongArtwork: View {
    let artwork: Artwork?
    let size: CGFloat

    var body: some View {
        Group {
            if let artwork {
                ArtworkImage(artwork, width: size, height: size)
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.secondary.opacity(0.12))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
