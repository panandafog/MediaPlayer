//
//  SongArtwork.swift
//  MediaPlayer
//
//

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
import Foundation
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

struct HighResolutionArtworkImage: View {
    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: PlatformArtworkImage?
    @State private var loadedArtworkIdentifier: URL?
    @State private var loadedPixelDimension = 0

    let artwork: Artwork
    let size: CGFloat
    var maximumPixelDimension: Int? = nil

    var body: some View {
        Group {
            if let loadedImage,
               loadedArtworkIdentifier == artworkIdentifier {
                swiftUIImage(from: loadedImage)
                .resizable()
                .scaledToFill()
            } else {
                ArtworkImage(artwork, width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: requestURL) {
            await loadHighResolutionImage()
        }
    }

    private var requestURL: URL? {
        artwork.url(width: pixelDimension, height: pixelDimension)
    }

    private var artworkIdentifier: URL? {
        artwork.url(width: 1, height: 1)
    }

    private var pixelDimension: Int {
        let requestedDimension = max(Int((size * max(displayScale, 1)).rounded(.up)), 1)
        let cappedDimension = min(requestedDimension, maximumPixelDimension ?? requestedDimension)
        let maximumDimension = min(artwork.maximumWidth, artwork.maximumHeight)

        guard maximumDimension > 0 else {
            return cappedDimension
        }

        return min(cappedDimension, maximumDimension)
    }

    @MainActor
    private func loadHighResolutionImage() async {
        if loadedArtworkIdentifier != artworkIdentifier {
            loadedImage = nil
            loadedArtworkIdentifier = nil
            loadedPixelDimension = 0
        }

        guard let requestURL else {
            return
        }

        guard loadedPixelDimension < pixelDimension else {
            return
        }

        do {
            try await Task.sleep(for: Loading.resizeDebounceDelay)
            try Task.checkCancellation()
        } catch {
            return
        }

        for attempt in 0..<Loading.maximumAttemptCount {
            do {
                var request = URLRequest(
                    url: requestURL,
                    cachePolicy: attempt == 0
                        ? .useProtocolCachePolicy
                        : .reloadRevalidatingCacheData,
                    timeoutInterval: Loading.requestTimeout
                )
                request.allowsConstrainedNetworkAccess = true

                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()

                guard
                    let response = response as? HTTPURLResponse,
                    (200..<300).contains(response.statusCode),
                    let image = PlatformArtworkImage(data: data)
                else {
                    throw ArtworkLoadingError.invalidResponse
                }

                loadedImage = image
                loadedArtworkIdentifier = artworkIdentifier
                loadedPixelDimension = pixelDimension
                return
            } catch is CancellationError {
                return
            } catch {
                guard attempt + 1 < Loading.maximumAttemptCount else {
                    return
                }

                try? await Task.sleep(for: Loading.retryDelay)
            }
        }
    }

    private func swiftUIImage(from image: PlatformArtworkImage) -> Image {
#if canImport(AppKit)
        Image(nsImage: image)
#else
        Image(uiImage: image)
#endif
    }
}

#if canImport(AppKit)
private typealias PlatformArtworkImage = NSImage
#else
private typealias PlatformArtworkImage = UIImage
#endif

private enum ArtworkLoadingError: Error {
    case invalidResponse
}

private enum Loading {
    static let maximumAttemptCount = 3
    static let requestTimeout: TimeInterval = 15
    static let resizeDebounceDelay = Duration.milliseconds(150)
    static let retryDelay = Duration.milliseconds(500)
}
