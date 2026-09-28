//
//  MediaPlayerTests.swift
//  MediaPlayerTests
//
//  Created by Andrey Pantyuhin on 31.05.2026.
//

import Foundation
import CoreGraphics
import MusicKit
import Testing
@testable import PlayerApp

struct MediaPlayerTests {

    @Test func findsArtworkAccentInDarkCover() {
        let size = 48
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            pixels[offset + 3] = 255
        }
        for row in 16..<32 {
            for column in 16..<32 {
                let offset = (row * size + column) * 4
                pixels[offset] = 220
                pixels[offset + 1] = 35
                pixels[offset + 2] = 45
            }
        }

        let accent = ArtworkAccentColor.fromPixels(pixels)
        #expect(accent != nil)
        #expect((accent?.hue ?? 0.5) < 0.08 || (accent?.hue ?? 0.5) > 0.92)
        #expect((accent?.brightness ?? 0) >= 0.58)
    }

    @Test func ignoresGrayscaleArtworkAsAccent() {
        let pixels = Array(repeating: [UInt8(180), 180, 180, 255], count: 48 * 48)
            .flatMap { $0 }
        #expect(ArtworkAccentColor.fromPixels(pixels) == nil)
        #expect(
            ArtworkAccentColor.fromBackgroundColor(
                CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
            ) == nil
        )
    }

    @Test func formatsTrackDuration() {
        #expect(TrackDurationFormatter.string(from: 0) == "0:00")
        #expect(TrackDurationFormatter.string(from: 65.9) == "1:05")
        #expect(TrackDurationFormatter.string(from: nil) == "--:--")
    }

    @Test func formatsLibraryGroupDuration() {
        #expect(LibraryDurationFormatter.string(from: 30) == "<1m")
        #expect(LibraryDurationFormatter.string(from: 3_600) == "1h")
        #expect(LibraryDurationFormatter.string(from: 5_400) == "1h 30m")
    }

    @Test @MainActor func adaptsTrackColumnsToAvailableWidth() {
        let fields: [SongListField] = [.releaseYear, .genre, .playCount]
        let compact = SongListLayout(
            availableWidth: 390,
            textScale: 1,
            context: .library,
            orderedFields: fields
        )
        let regular = SongListLayout(
            availableWidth: 600,
            textScale: 1,
            context: .library,
            orderedFields: fields
        )
        let wide = SongListLayout(
            availableWidth: 1_100,
            textScale: 1,
            context: .library,
            orderedFields: fields
        )

        #expect(compact.density == .compact)
        #expect(!compact.showsAlbumColumn)
        #expect(compact.fields.isEmpty)
        #expect(compact.inlineFields == fields)
        #expect(regular.density == .regular)
        #expect(regular.showsAlbumColumn)
        #expect(regular.fields.isEmpty)
        #expect(regular.inlineFields == fields)
        #expect(wide.density == .expanded)
        #expect(wide.fields == fields)
        #expect(wide.inlineFields.isEmpty)
    }

    @Test @MainActor func omitsRepeatedAlbumAndRespectsFieldOrder() {
        let order = SongListField.order(from: "genre,releaseYear,genre,unknown")
        #expect(Array(order.prefix(2)) == [.genre, .releaseYear])

        let layout = SongListLayout(
            availableWidth: 900,
            textScale: 1,
            context: .album,
            orderedFields: [.genre, .releaseYear]
        )
        #expect(!layout.showsAlbumColumn)
        #expect(layout.fields == [.genre, .releaseYear])
    }

    @Test @MainActor func hidesOptionalTrackListElements() {
        let layout = SongListLayout(
            availableWidth: 900,
            textScale: 1,
            context: .library,
            orderedFields: [.releaseYear],
            showsAlbum: false,
            showsDuration: false,
            showsInfoButton: false
        )

        #expect(!layout.showsAlbum)
        #expect(!layout.showsAlbumColumn)
        #expect(!layout.showsDuration)
        #expect(!layout.showsInfoButton)
        #expect(layout.fields == [.releaseYear])
    }

    @Test @MainActor func adaptsNowPlayingLayoutToAvailableSize() {
        let examples: [(CGSize, NowPlayingLayout)] = [
            (CGSize(width: 1512, height: 900), .immersive),
            (CGSize(width: 1100, height: 700), .immersive),
            (CGSize(width: 880, height: 560), .immersive),
            (CGSize(width: 879, height: 700), .fullHorizontal),
            (CGSize(width: 1000, height: 559), .fullHorizontal),
            (CGSize(width: 390, height: 700), .fullVertical),
            (CGSize(width: 844, height: 390), .fullHorizontal),
            (CGSize(width: 300, height: 449), .compactVertical),
            (CGSize(width: 260, height: 400), .compactVertical),
            (CGSize(width: 180, height: 300), .compactVertical),
            (CGSize(width: 480, height: 260), .compactHorizontal),
            (CGSize(width: 360, height: 170), .compactHorizontal),
            (CGSize(width: 440, height: 169), .minimalWideHorizontal),
            (CGSize(width: 440, height: 80), .minimalWideHorizontal),
            (CGSize(width: 600, height: 100), .minimalWideHorizontal),
            (CGSize(width: 180, height: 299), .minimalVertical),
            (CGSize(width: 180, height: 200), .minimalVertical),
            (CGSize(width: 439, height: 100), .minimalHorizontal),
            (CGSize(width: 440, height: 79), .minimalHorizontal),
            (CGSize(width: 350, height: 180), .minimalHorizontal),
            (CGSize(width: 250, height: 140), .minimalHorizontal),
            (CGSize(width: 180, height: 100), .minimalHorizontal)
        ]

        for (size, expectedLayout) in examples {
            #expect(NowPlayingLayoutMetrics(availableSize: size).layout == expectedLayout)
        }
    }

#if os(macOS)
    @Test @MainActor func reducesPlayerWindowChromeOnlyForSmallWindows() {
        #expect(PlayerWindowChromeLayout.usesCompactChrome(for: CGSize(width: 180, height: 100)))
        #expect(PlayerWindowChromeLayout.usesCompactChrome(for: CGSize(width: 440, height: 169)))
        #expect(PlayerWindowChromeLayout.usesCompactChrome(for: CGSize(width: 180, height: 300)))
        #expect(!PlayerWindowChromeLayout.usesCompactChrome(for: CGSize(width: 380, height: 560)))
        #expect(!PlayerWindowChromeLayout.usesCompactChrome(for: CGSize(width: 380, height: 300)))
    }
#endif

    @Test func normalizesPlaybackProgress() {
        #expect(PlaybackProgress.normalizedTime(-1, duration: 120) == 0)
        #expect(PlaybackProgress.normalizedTime(30, duration: 120) == 30)
        #expect(PlaybackProgress.normalizedTime(150, duration: 120) == 120)
        #expect(PlaybackProgress.normalizedTime(.infinity, duration: 120) == 0)
    }

    @Test func limitsPlaybackQueueAroundSelectedItem() {
        let items = Array(0..<1_000)
        let window = PlaybackQueueWindow.items(from: items, startingAt: 500)

        #expect(window.first == 490)
        #expect(window.last == 550)
        #expect(window.count == 61)
    }

    @Test func limitsPlaybackQueueAtCollectionEdges() {
        let items = Array(0..<1_000)

        #expect(PlaybackQueueWindow.items(from: items, startingAt: 10).first == 0)
        #expect(PlaybackQueueWindow.items(from: items, startingAt: 10).last == 60)
        #expect(PlaybackQueueWindow.items(from: items, startingAt: 999).first == 989)
        #expect(PlaybackQueueWindow.items(from: items, startingAt: 999).last == 999)
    }

    @Test func returnsItemsAfterCurrentQueueEntry() {
        let items = Array(0..<5)

        #expect(PlaybackQueueWindow.itemsAfterCurrent(in: items, currentIndex: 1) == [2, 3, 4])
        #expect(PlaybackQueueWindow.itemsAfterCurrent(in: items, currentIndex: 4).isEmpty)
        #expect(PlaybackQueueWindow.itemsAfterCurrent(in: items, currentIndex: nil).isEmpty)
    }

    @Test func mapsListeningModesToNativeRepeatMode() {
        #expect(PlaybackMode.normal.nativeRepeatMode == .none)
        #expect(PlaybackMode.shuffle.nativeRepeatMode == .none)
        #expect(PlaybackMode.repeatQueue.nativeRepeatMode == .all)
        #expect(PlaybackMode.repeatOne.nativeRepeatMode == .one)
    }

    @Test func shufflesActualPlaybackQueueStartingWithCurrentItem() {
        let items = Array(0..<5)
        let shuffledItems = PlaybackQueueOrder.shuffledItems(
            from: items,
            startingAt: 2,
            shuffle: { _ in }
        )

        #expect(shuffledItems == [0, 1, 2, 4, 3])
        #expect(Set(shuffledItems) == Set(items))
    }

    @Test func persistsSmartArtistGroupingSettingsAcrossLaunches() throws {
        let suiteName = "MediaPlayerTests.\(UUID().uuidString)"
        let firstLaunchDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            firstLaunchDefaults.removePersistentDomain(forName: suiteName)
        }

        firstLaunchDefaults.set(
            true,
            forKey: PlayerSettingsKey.usesSmartArtistGrouping
        )
        firstLaunchDefaults.set(
            "|+",
            forKey: PlayerSettingsKey.smartArtistSeparatorCharacters
        )

        let nextLaunchDefaults = try #require(UserDefaults(suiteName: suiteName))

        #expect(
            nextLaunchDefaults.bool(forKey: PlayerSettingsKey.usesSmartArtistGrouping)
        )
        #expect(
            nextLaunchDefaults.string(
                forKey: PlayerSettingsKey.smartArtistSeparatorCharacters
            ) == "|+"
        )
    }

    @Test @MainActor func restoresLibraryBrowsingPreferences() throws {
        let suiteName = "MediaPlayerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(
            MusicLibrarySortOption.artist.rawValue,
            forKey: PlayerSettingsKey.librarySortOption
        )
        defaults.set(
            MusicLibrarySection.albums.rawValue,
            forKey: PlayerSettingsKey.librarySection
        )

        let restoredLibrary = MusicLibraryViewModel(defaults: defaults)

        #expect(restoredLibrary.sortOption == .artist)
        #expect(restoredLibrary.section == .albums)

        restoredLibrary.sortOption = .album
        restoredLibrary.section = .artists

        let nextLaunchLibrary = MusicLibraryViewModel(defaults: defaults)

        #expect(nextLaunchLibrary.sortOption == .album)
        #expect(nextLaunchLibrary.section == .artists)
    }

    @Test func separatesCombinedArtistNamesUsingUnambiguousDelimiters() {
        #expect(
            CombinedArtistNameParser.names(from: "Boris Brejcha; Ginger")
                == ["Boris Brejcha", "Ginger"]
        )
        #expect(
            CombinedArtistNameParser.names(from: "Artist feat. Guest")
                == ["Artist", "Guest"]
        )
        #expect(
            CombinedArtistNameParser.names(from: "Artist / Guest x Third")
                == ["Artist", "Guest", "Third"]
        )
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist One,Artist Two & Artist Three/Artist Four"
            ) == ["Artist One", "Artist Two", "Artist Three", "Artist Four"]
        )
    }

    @Test func usesCustomArtistSeparatorCharactersLiterally() {
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist One|Artist Two+Artist Three",
                separatorCharacters: "|+"
            ) == ["Artist One", "Artist Two", "Artist Three"]
        )
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist.One*Artist Two",
                separatorCharacters: ".*"
            ) == ["Artist", "One", "Artist Two"]
        )
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist One; Artist Two",
                separatorCharacters: "|"
            ) == ["Artist One; Artist Two"]
        )
    }

    @Test func normalizesCustomArtistSeparatorCharacters() {
        #expect(
            SmartArtistGroupingSettings.normalizedSeparatorCharacters(" , , & / ")
                == ",&/"
        )
    }

    @Test func groupsFeaturedTracksWithTheMainAlbumArtist() {
        let names: Set<String> = [
            "Gorilla Zippo",
            "Gorilla Zippo feat. Anikv",
            "Gorilla Zippo feat. Anikv & Richie",
            "Gorilla Zippo & KickShot",
            "Other Artist"
        ]

        for name in names where name.hasPrefix("Gorilla Zippo") && name != "Gorilla Zippo" {
            #expect(
                AlbumArtistNameResolver.canonicalName(for: name, among: names)
                    == "Gorilla Zippo"
            )
        }
        #expect(
            AlbumArtistNameResolver.canonicalName(for: "Other Artist", among: names)
                == "Other Artist"
        )
    }

    @Test func keepsUnrelatedAlbumArtistsSeparate() {
        let names: Set<String> = ["AC", "AC/DC", "Gorilla Zippo feat. Anikv"]

        #expect(AlbumArtistNameResolver.canonicalName(for: "AC/DC", among: names) == "AC/DC")
        #expect(
            AlbumArtistNameResolver.canonicalName(
                for: "Gorilla Zippo feat. Anikv",
                among: names
            ) == "Gorilla Zippo feat. Anikv"
        )
    }

    @Test @MainActor func storesPlaybackRestorationSnapshot() throws {
        let suiteName = "MediaPlayerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PlaybackRestorationStore(defaults: defaults)
        let snapshot = PlaybackRestorationSnapshot(
            queueSongIDs: ["first", "second"],
            currentSongID: "second",
            playbackTime: 42.5
        )

        store.save(snapshot)

        #expect(store.load() == snapshot)
    }

}
