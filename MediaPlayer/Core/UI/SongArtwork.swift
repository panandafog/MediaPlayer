//
//  SongArtwork.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct SongArtwork: View {
    let artwork: Artwork?
    let size: CGFloat
    var usesHighResolutionSource = false

    var body: some View {
        Group {
            if let artwork {
                if usesHighResolutionSource {
                    HighResolutionArtworkImage(artwork: artwork, size: safeSize)
                } else {
                    ArtworkImage(artwork, width: safeSize, height: safeSize)
                }
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: safeSize, height: safeSize)
                    .background(.secondary.opacity(Layout.placeholderOpacity))
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
        )
    }

    private var safeSize: CGFloat {
        guard size.isFinite else {
            return 1
        }

        return max(size, 1)
    }
}

private enum Layout {
    static let placeholderOpacity: Double = 0.12
    static let cornerRadius: CGFloat = 7
}

private struct HighResolutionArtworkImage: View {
    @Environment(\.displayScale) private var displayScale

    let artwork: Artwork
    let size: CGFloat

    var body: some View {
        AsyncImage(
            url: artwork.url(width: pixelDimension, height: pixelDimension),
            scale: displayScale
        ) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ArtworkImage(artwork, width: size, height: size)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    private var pixelDimension: Int {
        let requestedDimension = max(Int((size * max(displayScale, 1)).rounded(.up)), 1)
        let maximumDimension = min(artwork.maximumWidth, artwork.maximumHeight)

        guard maximumDimension > 0 else {
            return requestedDimension
        }

        return min(requestedDimension, maximumDimension)
    }
}
