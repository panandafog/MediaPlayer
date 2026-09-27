//
//  ArtworkAccentColor.swift
//  MediaPlayer
//

import Combine
import CoreGraphics
import Foundation
import ImageIO
import MusicKit
import SwiftUI

nonisolated struct ArtworkAccentColor: Equatable, Sendable {
    let hue: Double
    let saturation: Double
    let brightness: Double

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    static func fromBackgroundColor(_ color: CGColor?) -> Self? {
        guard let color,
              let rgbColor = color.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                intent: .defaultIntent,
                options: nil
              ),
              let components = rgbColor.components,
              components.count >= 3 else {
            return nil
        }

        let hsv = hsv(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2])
        )
        guard hsv.saturation >= 0.25, hsv.brightness >= 0.18 else {
            return nil
        }

        return normalized(
            hue: hsv.hue,
            saturation: hsv.saturation,
            brightness: hsv.brightness
        )
    }

    static func fromImageData(_ data: Data) -> Self? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Palette.sampleSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }

        let width = Palette.sampleSize
        let height = Palette.sampleSize
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let didDraw = pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                    | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else {
            return nil
        }

        return fromPixels(pixels)
    }

    static func fromPixels(_ pixels: [UInt8]) -> Self? {
        guard !pixels.isEmpty, pixels.count.isMultiple(of: 4) else {
            return nil
        }

        var bins = [HueBin](repeating: HueBin(), count: Palette.hueBinCount)

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset + 3] >= Palette.minimumAlpha else {
                continue
            }

            let hsv = hsv(
                red: Double(pixels[offset]) / 255,
                green: Double(pixels[offset + 1]) / 255,
                blue: Double(pixels[offset + 2]) / 255
            )
            guard hsv.saturation >= Palette.minimumSaturation,
                  hsv.brightness >= Palette.minimumBrightness else {
                continue
            }

            let weight = hsv.saturation * hsv.saturation
                * min(hsv.brightness / 0.5, 1)
            let index = min(Int(hsv.hue * Double(Palette.hueBinCount)), Palette.hueBinCount - 1)
            let angle = hsv.hue * 2 * .pi
            bins[index].weight += weight
            bins[index].hueX += cos(angle) * weight
            bins[index].hueY += sin(angle) * weight
            bins[index].saturation += hsv.saturation * weight
            bins[index].brightness += hsv.brightness * weight
        }

        let bestIndex = bins.indices.max { left, right in
            neighborhoodWeight(at: left, in: bins)
                < neighborhoodWeight(at: right, in: bins)
        }
        guard let bestIndex,
              neighborhoodWeight(at: bestIndex, in: bins) >= Palette.minimumClusterWeight else {
            return nil
        }

        var selected = HueBin()
        for index in neighboringIndices(of: bestIndex) {
            selected.add(bins[index])
        }
        guard selected.weight > 0 else {
            return nil
        }

        let angle = atan2(selected.hueY, selected.hueX)
        let hue = (angle < 0 ? angle + 2 * .pi : angle) / (2 * .pi)
        return normalized(
            hue: hue,
            saturation: selected.saturation / selected.weight,
            brightness: selected.brightness / selected.weight
        )
    }

    private static func neighborhoodWeight(at index: Int, in bins: [HueBin]) -> Double {
        neighboringIndices(of: index).reduce(0) { $0 + bins[$1].weight }
    }

    private static func neighboringIndices(of index: Int) -> [Int] {
        let count = Palette.hueBinCount
        return [(index + count - 1) % count, index, (index + 1) % count]
    }

    private static func normalized(
        hue: Double,
        saturation: Double,
        brightness: Double
    ) -> Self {
        var result = Self(
            hue: hue,
            saturation: min(max(saturation, 0.55), 0.85),
            brightness: min(max(brightness, 0.72), 0.93)
        )

        // Keep accents legible against the dimmed artwork without washing out
        // naturally bright colors such as yellow.
        for _ in 0..<12 {
            let luminance = result.relativeLuminance
            if luminance < 0.22 {
                if result.brightness < 0.99 {
                    result = Self(
                        hue: hue,
                        saturation: result.saturation,
                        brightness: min(result.brightness + 0.04, 1)
                    )
                } else {
                    result = Self(
                        hue: hue,
                        saturation: max(result.saturation - 0.05, 0.4),
                        brightness: result.brightness
                    )
                }
            } else if luminance > 0.55 {
                result = Self(
                    hue: hue,
                    saturation: result.saturation,
                    brightness: max(result.brightness - 0.04, 0.58)
                )
            } else {
                break
            }
        }

        return result
    }

    private var relativeLuminance: Double {
        let (red, green, blue) = rgb
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red)
            + 0.7152 * linear(green)
            + 0.0722 * linear(blue)
    }

    var rgb: (Double, Double, Double) {
        let sector = hue * 6
        let fraction = sector - floor(sector)
        let low = brightness * (1 - saturation)
        let falling = brightness * (1 - saturation * fraction)
        let rising = brightness * (1 - saturation * (1 - fraction))

        switch Int(sector) % 6 {
        case 0: return (brightness, rising, low)
        case 1: return (falling, brightness, low)
        case 2: return (low, brightness, rising)
        case 3: return (low, falling, brightness)
        case 4: return (rising, low, brightness)
        default: return (brightness, low, falling)
        }
    }

    private static func hsv(red: Double, green: Double, blue: Double) -> (
        hue: Double,
        saturation: Double,
        brightness: Double
    ) {
        let maximum = max(red, max(green, blue))
        let minimum = min(red, min(green, blue))
        let difference = maximum - minimum
        guard difference > 0, maximum > 0 else {
            return (0, 0, maximum)
        }

        let hue: Double
        if maximum == red {
            hue = ((green - blue) / difference).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            hue = (blue - red) / difference + 2
        } else {
            hue = (red - green) / difference + 4
        }

        return ((hue < 0 ? hue + 6 : hue) / 6, difference / maximum, maximum)
    }
}

@MainActor
final class ArtworkAccentTheme: ObservableObject {
    @Published private(set) var accent: ArtworkAccentColor?

    private var requestedArtwork: Artwork?
    private var isEnabled = false
    private var request: Task<Void, Never>?

    var color: Color? {
        accent?.color
    }

    func update(for artwork: Artwork?, enabled: Bool) {
        guard requestedArtwork != artwork || isEnabled != enabled else {
            return
        }

        requestedArtwork = artwork
        isEnabled = enabled
        request?.cancel()

        guard enabled, let artwork else {
            accent = nil
            return
        }

        // Retain the previous track's tint until the new color is ready.
        request = Task { [weak self] in
            let color = await ArtworkAccentColorProvider.shared.color(for: artwork)
            guard !Task.isCancelled else {
                return
            }
            self?.accent = color
        }
    }
}

@MainActor
final class ArtworkAccentColorProvider {
    static let shared = ArtworkAccentColorProvider()

    private var cachedColors: [URL: ArtworkAccentColor] = [:]
    private var unavailableURLs: Set<URL> = []
    private var inFlight: [URL: Task<(color: ArtworkAccentColor?, fetched: Bool), Never>] = [:]

    func color(for artwork: Artwork) async -> ArtworkAccentColor? {
        guard let url = artwork.url(width: Palette.requestSize, height: Palette.requestSize) else {
            return ArtworkAccentColor.fromBackgroundColor(artwork.backgroundColor)
        }

        if let cachedColor = cachedColors[url] {
            return cachedColor
        }
        if unavailableURLs.contains(url) {
            return nil
        }
        if let inFlight = inFlight[url] {
            let result = await inFlight.value
            return result.color
        }

        let fallback = ArtworkAccentColor.fromBackgroundColor(artwork.backgroundColor)
        if let fallback {
            cache(fallback, for: url)
            return fallback
        }

        // Do not start a request for a track that is skipped immediately.
        do {
            try await Task.sleep(for: Palette.requestDebounce)
            try Task.checkCancellation()
        } catch {
            return nil
        }
        if let cachedColor = cachedColors[url] {
            return cachedColor
        }
        if let inFlight = inFlight[url] {
            let result = await inFlight.value
            return result.color
        }

        let request = Task.detached(priority: .utility) {
            () -> (color: ArtworkAccentColor?, fetched: Bool) in
            do {
                let urlRequest = URLRequest(
                    url: url,
                    cachePolicy: .useProtocolCachePolicy,
                    timeoutInterval: Palette.requestTimeout
                )
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                if let response = response as? HTTPURLResponse,
                   !(200..<300).contains(response.statusCode) {
                    return (nil, false)
                }
                return (ArtworkAccentColor.fromImageData(data), true)
            } catch {
                return (nil, false)
            }
        }
        inFlight[url] = request

        let result = await request.value
        inFlight[url] = nil
        if let color = result.color {
            cache(color, for: url)
        } else if result.fetched {
            evictCacheIfNeeded()
            unavailableURLs.insert(url)
        }
        return result.color
    }

    private func cache(_ color: ArtworkAccentColor, for url: URL) {
        evictCacheIfNeeded()
        cachedColors[url] = color
    }

    private func evictCacheIfNeeded() {
        if cachedColors.count + unavailableURLs.count >= Palette.cacheLimit {
            cachedColors.removeAll(keepingCapacity: true)
            unavailableURLs.removeAll(keepingCapacity: true)
        }
    }
}

private nonisolated struct HueBin {
    var weight = 0.0
    var hueX = 0.0
    var hueY = 0.0
    var saturation = 0.0
    var brightness = 0.0

    mutating func add(_ other: Self) {
        weight += other.weight
        hueX += other.hueX
        hueY += other.hueY
        saturation += other.saturation
        brightness += other.brightness
    }
}

private nonisolated enum Palette {
    static let requestSize = 96
    static let sampleSize = 48
    static let hueBinCount = 24
    static let minimumAlpha: UInt8 = 192
    static let minimumSaturation = 0.25
    static let minimumBrightness = 0.18
    static let minimumClusterWeight = 8.0
    static let cacheLimit = 256
    static let requestDebounce = Duration.milliseconds(100)
    static let requestTimeout: TimeInterval = 8
}
