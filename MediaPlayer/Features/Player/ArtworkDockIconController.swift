//
//  ArtworkDockIconController.swift
//  MediaPlayer
//

#if os(macOS)
import AppKit
import Combine
import MusicKit

@MainActor
final class ArtworkDockIconController: ObservableObject {
    private var requestedArtwork: Artwork?
    private var isEnabled = false
    private var request: Task<Void, Never>?
    private var sourceImage: CGImage?
    private var sourceSize = NSSize.zero
    private var displayedColor: ColorKey?
    private var renderedImages: [ColorKey: NSImage] = [:]
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()

    func update(for artwork: Artwork?, enabled: Bool) {
        guard requestedArtwork != artwork || isEnabled != enabled else {
            return
        }

        requestedArtwork = artwork
        isEnabled = enabled
        request?.cancel()

        guard enabled, let artwork else {
            restoreOriginalIcon()
            return
        }

        // Keep the previous color visible while the next artwork is being sampled.
        request = Task { [weak self] in
            let accent = await ArtworkAccentColorProvider.shared.color(for: artwork)
            guard !Task.isCancelled else {
                return
            }
            self?.showIcon(for: accent)
        }
    }

    private func showIcon(for accent: ArtworkAccentColor?) {
        guard let accent else {
            restoreOriginalIcon()
            return
        }

        let color = ColorKey(accent: accent)
        guard color != Self.originalColor else {
            restoreOriginalIcon()
            return
        }
        guard displayedColor != color else {
            return
        }

        let image: NSImage?
        if let cachedImage = renderedImages[color] {
            image = cachedImage
        } else {
            image = renderIcon(for: color)
            if let image {
                if renderedImages.count >= Self.cacheLimit {
                    renderedImages.removeAll(keepingCapacity: true)
                }
                renderedImages[color] = image
            }
        }

        guard let image else {
            restoreOriginalIcon()
            return
        }
        NSApplication.shared.applicationIconImage = image
        displayedColor = color
    }

    private func renderIcon(for color: ColorKey) -> NSImage? {
        guard prepareOriginalIcon(), let sourceImage else {
            return nil
        }

        let width = sourceImage.width
        let height = sourceImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let cgImage = pixels.withUnsafeMutableBytes { bytes -> CGImage? in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: outputColorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                    | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }
            context.draw(
                sourceImage,
                in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            )

            var brightestOrange = 0.0
            for offset in stride(from: 0, to: bytes.count, by: 4) {
                let alpha = Double(bytes[offset + 3])
                guard alpha >= 32 else { continue }
                let red = Double(bytes[offset]) / alpha
                let green = Double(bytes[offset + 1]) / alpha
                let blue = Double(bytes[offset + 2]) / alpha
                if red >= green, green >= blue, red - blue > 0.08 {
                    brightestOrange = max(brightestOrange, red)
                }
            }
            guard brightestOrange > 0 else { return nil }

            for offset in stride(from: 0, to: bytes.count, by: 4) {
                let alpha = Double(bytes[offset + 3])
                guard alpha >= 32 else { continue }
                let red = Double(bytes[offset]) / alpha
                let green = Double(bytes[offset + 1]) / alpha
                let blue = Double(bytes[offset + 2]) / alpha
                guard red >= green, green >= blue else { continue }

                let strength = min(max((red - blue - 0.015) / 0.08, 0), 1)
                guard strength > 0 else { continue }

                // Rebuild tinted pixels from neutral gray, never from orange.
                // This keeps blue from turning purple and red from turning pink.
                let neutral = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let shade = min(red / brightestOrange, 1)
                for (channel, target) in [color.redValue, color.greenValue, color.blueValue]
                    .enumerated() {
                    let value = neutral * (1 - strength) + target * shade * strength
                    bytes[offset + channel] = UInt8(clamping: Int((value * alpha).rounded()))
                }
            }
            return context.makeImage()
        }
        guard let cgImage else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: sourceSize)
    }

    private func prepareOriginalIcon() -> Bool {
        if sourceImage != nil {
            return true
        }

        guard let original = NSApplication.shared.applicationIconImage else {
            return false
        }
        var proposedRect = NSRect(x: 0, y: 0, width: 512, height: 512)
        guard let cgImage = original.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            return false
        }

        sourceImage = cgImage
        sourceSize = original.size.width > 0 && original.size.height > 0
            ? original.size
            : NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        return true
    }

    private func restoreOriginalIcon() {
        guard displayedColor != nil else {
            return
        }
        NSApplication.shared.applicationIconImage = nil
        displayedColor = nil
    }

    private static let cacheLimit = 16

    // The original layer fill is extended-sRGB (1, 0.55294, 0.15686).
    private static let originalBlue = 0.15686
    private static let originalColor = ColorKey(
        red: 255,
        green: UInt8((0.55294 * 255).rounded()),
        blue: UInt8((originalBlue * 255).rounded())
    )

    private struct ColorKey: Hashable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        init(red: UInt8, green: UInt8, blue: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(accent: ArtworkAccentColor) {
            let (red, green, blue) = accent.rgb
            self.init(
                red: UInt8(clamping: Int((red * 255).rounded())),
                green: UInt8(clamping: Int((green * 255).rounded())),
                blue: UInt8(clamping: Int((blue * 255).rounded()))
            )
        }

        var redValue: Double { Double(red) / 255 }
        var greenValue: Double { Double(green) / 255 }
        var blueValue: Double { Double(blue) / 255 }
    }
}
#endif
