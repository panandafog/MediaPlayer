//
//  TrackDetailsView.swift
//  MediaPlayer
//

import Foundation
import MusicKit
import SwiftUI

struct TrackDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var details: TrackDetails
    @State private var isLoading = true

    let song: Song

    init(song: Song) {
        self.song = song
        _details = State(initialValue: TrackDetails(song: song, relatedSong: nil, extendedSong: nil))
    }

    var body: some View {
        NavigationStack {
            List {
                header
                trackSection
                creditsSection
                librarySection
                audioSection
                identifiersSection
                albumSections
                relatedSection
            }
            .navigationTitle("Track Info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .task(id: song.id) {
            isLoading = true
            details = await TrackDetailsService().load(for: song)
            isLoading = false
        }
#if os(macOS)
        .frame(minWidth: 420, minHeight: 540)
#endif
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            SongArtwork(
                artwork: details.song.artwork,
                size: 104,
                usesHighResolutionSource: true
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(details.song.title)
                    .font(.title3.weight(.semibold))
                Text(details.song.artistName)
                    .foregroundStyle(.secondary)
                if let albumTitle = details.song.albumTitle {
                    Text(albumTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if isLoading {
                    ProgressView("Loading metadata…")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private var trackSection: some View {
        Section("Track") {
            row("Title", details.song.title)
            row("Artist", details.song.artistName)
            row("Album", details.song.albumTitle)
            row("Duration", details.song.duration.map { TrackDurationFormatter.string(from: $0) })
            row("Track number", details.song.trackNumber.map { String($0) })
            row("Disc number", details.song.discNumber.map { String($0) })
            row("Genres", joined(details.song.genreNames))
            row("Release date", dateOnly(details.song.releaseDate))
            row("Content rating", rating(details.song.contentRating))
            row("Lyrics available", yesNo(details.song.hasLyrics))
            row("Work", details.song.workName)
            row("Movement", details.song.movementName)
            row("Movement number", details.song.movementNumber.map { String($0) })
            row("Movement count", details.song.movementCount.map { String($0) })
#if os(iOS)
            row("Start time", details.song.startTime.map { TrackDurationFormatter.string(from: $0) })
            row("End time", details.song.endTime.map { TrackDurationFormatter.string(from: $0) })
#endif
        }
    }

    private var creditsSection: some View {
        Section("Credits") {
            row("Composer", details.song.composerName)
            row("Artists", joined(details.artists.map(\.name)))
            row("Composers", joined(details.composers.map(\.name)))
            row("Genre records", joined(details.genres.map(\.name)))
            row("Attribution", details.song.attribution)
            row("Editorial name", details.song.editorialNotes?.name)
            row("Editorial notes", details.song.editorialNotes?.standard)
            row("Short editorial notes", details.song.editorialNotes?.short)
            row("Editorial tagline", details.song.editorialNotes?.tagline)
        }
    }

    private var librarySection: some View {
        Section("Library") {
            row("Date added", dateAndTime(details.song.libraryAddedDate))
            row("Last played", dateAndTime(details.song.lastPlayedDate))
            row("Play count", details.song.playCount.map { String($0) })
        }
    }

    private var audioSection: some View {
        Section("Audio") {
            row("Available audio variants", joined(details.audioVariants?.map(audioVariant)))
            row("Apple Digital Master", yesNo(details.song.isAppleDigitalMaster))
            row("Preview count", details.song.previewAssets.map { String($0.count) })

            if let previews = details.song.previewAssets {
                ForEach(Array(previews.enumerated()), id: \.offset) { index, preview in
                    urlRow("Preview \(index + 1)", preview.url)
                    urlRow("HLS preview \(index + 1)", preview.hlsURL)
                    if let artwork = preview.artwork {
                        row(
                            "Preview artwork \(index + 1)",
                            "\(artwork.maximumWidth) × \(artwork.maximumHeight)"
                        )
                    }
                }
            }
        }
    }

    private var identifiersSection: some View {
        Section("Identifiers & Links") {
            row("MusicKit ID", details.song.id.rawValue)
            row("ISRC", details.song.isrc)
            urlRow("Track link", details.song.url)
            urlRow("Artist link", details.artistURL)
            if let artwork = details.song.artwork {
                row("Artwork size", "\(artwork.maximumWidth) × \(artwork.maximumHeight)")
            }
        }
    }

    @ViewBuilder
    private var albumSections: some View {
        ForEach(details.albums) { album in
            Section("Album: \(album.title)") {
                row("Album artist", album.artistName)
                row("Release date", dateOnly(album.releaseDate))
                row("Genres", joined(album.genreNames))
                row("Track count", String(album.trackCount))
                row("Record label", album.recordLabelName)
                row("Copyright", album.copyright)
                row("Editorial name", album.editorialNotes?.name)
                row("Editorial notes", album.editorialNotes?.standard)
                row("Editorial tagline", album.editorialNotes?.tagline)
                row("UPC", album.upc)
                row("Compilation", yesNo(album.isCompilation))
                row("Complete album", yesNo(album.isComplete))
                row("Single", yesNo(album.isSingle))
                row("Apple Digital Master", yesNo(album.isAppleDigitalMaster))
                row("Audio variants", joined(album.audioVariants?.map(audioVariant)))
                row("Content rating", rating(album.contentRating))
                row("Date added", dateAndTime(album.libraryAddedDate))
                row("Last played", dateAndTime(album.lastPlayedDate))
                row("Album ID", album.id.rawValue)
                urlRow("Album link", album.url)
                urlRow("Album artist link", album.artistURL)
                if let artwork = album.artwork {
                    row("Album artwork size", "\(artwork.maximumWidth) × \(artwork.maximumHeight)")
                }
            }
        }
    }

    private var relatedSection: some View {
        Section("Related") {
            row("Music videos", joined(details.musicVideos.map(\.title)))
            row("Station", details.station?.name)
            ForEach(details.artists) { artist in
                row("Artist ID: \(artist.name)", artist.id.rawValue)
                urlRow("Artist link: \(artist.name)", artist.url)
            }
            ForEach(details.genres) { genre in
                row("Genre ID: \(genre.name)", genre.id.rawValue)
            }
            ForEach(details.musicVideos) { video in
                row("Video ID: \(video.title)", video.id.rawValue)
                urlRow("Video link: \(video.title)", video.url)
            }
        }
    }

    private func row(_ title: String, _ value: String?) -> some View {
        let displayedValue = value.flatMap { $0.isEmpty ? nil : $0 }

        return LabeledContent(title) {
            Text(displayedValue ?? "—")
                .foregroundStyle(displayedValue == nil ? .secondary : .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func urlRow(_ title: String, _ url: URL?) -> some View {
        LabeledContent(title) {
            if let url {
                Link(url.absoluteString, destination: url)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func joined(_ values: [String]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.joined(separator: ", ")
    }

    private func dateAndTime(_ value: Date?) -> String? {
        value?.formatted(date: .abbreviated, time: .shortened)
    }

    private func dateOnly(_ value: Date?) -> String? {
        value?.formatted(date: .abbreviated, time: .omitted)
    }

    private func yesNo(_ value: Bool?) -> String? {
        value.map { $0 ? "Yes" : "No" }
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func rating(_ value: ContentRating?) -> String? {
        switch value {
        case .some(.clean): "Clean"
        case .some(.explicit): "Explicit"
        case .none: nil
        @unknown default: nil
        }
    }

    private func audioVariant(_ value: AudioVariant) -> String {
        switch value {
        case .dolbyAtmos: "Dolby Atmos"
        case .dolbyAudio: "Dolby Audio"
        case .lossless: "Lossless"
        case .highResolutionLossless: "Hi-Res Lossless"
        case .lossyStereo: "Lossy Stereo"
        case .spatialAudio: "Spatial Audio"
        @unknown default: "Other"
        }
    }
}
