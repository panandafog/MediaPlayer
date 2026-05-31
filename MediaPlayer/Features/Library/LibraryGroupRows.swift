//
//  LibraryGroupRows.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct ArtistRow: View {
    let artist: LibraryArtist

    var body: some View {
        HStack(spacing: 12) {
            SongArtwork(artwork: artist.artwork, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.name)
                    .lineLimit(1)
                Text(
                    "\(LibraryItemCountFormatter.albums(artist.albums.count)), "
                        + LibraryItemCountFormatter.tracks(artist.songs.count)
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }
}

struct AlbumRow: View {
    let album: LibraryAlbum

    var body: some View {
        HStack(spacing: 12) {
            SongArtwork(artwork: album.artwork, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(LibraryItemCountFormatter.tracks(album.songs.count))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            SongArtwork(artwork: playlist.artwork, size: 48)

            VStack(alignment: .leading, spacing: 3) {
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
