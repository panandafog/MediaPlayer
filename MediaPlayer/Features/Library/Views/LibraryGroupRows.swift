//
//  LibraryGroupRows.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct ArtistRow: View {
    let artist: LibraryArtist

    var body: some View {
        HStack(spacing: LibraryRowMetrics.spacing) {
            SongArtwork(artwork: artist.artwork, size: LibraryRowMetrics.artworkSize)

            VStack(alignment: .leading, spacing: LibraryRowMetrics.metadataSpacing) {
                Text(artist.name)
                    .lineLimit(1)
                Text(
                    "\(LibraryItemCountFormatter.albums(artist.albums.count)), "
                        + LibraryItemCountFormatter.tracks(artist.songs.count)
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !supplementaryDetails.isEmpty {
                    Text(supplementaryDetails)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var supplementaryDetails: String {
        [
            artist.primaryGenreName,
            artist.totalDuration.map { LibraryDurationFormatter.string(from: $0) }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

struct AlbumRow: View {
    let album: LibraryAlbum

    var body: some View {
        HStack(spacing: LibraryRowMetrics.spacing) {
            SongArtwork(artwork: album.artwork, size: LibraryRowMetrics.artworkSize)

            VStack(alignment: .leading, spacing: LibraryRowMetrics.metadataSpacing) {
                Text(album.title)
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(supplementaryDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var supplementaryDetails: String {
        [
            album.releaseYear.map { String($0) },
            LibraryItemCountFormatter.tracks(album.songs.count),
            album.totalDuration.map { LibraryDurationFormatter.string(from: $0) },
            album.primaryGenreName
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: LibraryRowMetrics.spacing) {
            SongArtwork(artwork: playlist.artwork, size: LibraryRowMetrics.artworkSize)

            VStack(alignment: .leading, spacing: LibraryRowMetrics.metadataSpacing) {
                Text(playlist.name)
                    .lineLimit(1)
                Text(playlist.curatorName ?? "Playlist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
