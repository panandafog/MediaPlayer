//
//  TrackDetails.swift
//  MediaPlayer
//

import Foundation
import MusicKit

struct TrackDetails {
    let song: Song
    let relatedSong: Song?
    let extendedSong: Song?

    var albums: [Album] {
        relatedSong?.albums.map(Array.init) ?? song.albums.map(Array.init) ?? []
    }

    var artists: [Artist] {
        relatedSong?.artists.map(Array.init) ?? song.artists.map(Array.init) ?? []
    }

    var genres: [Genre] {
        relatedSong?.genres.map(Array.init) ?? song.genres.map(Array.init) ?? []
    }

    var composers: [Artist] {
        relatedSong?.composers.map(Array.init) ?? song.composers.map(Array.init) ?? []
    }

    var musicVideos: [MusicVideo] {
        relatedSong?.musicVideos.map(Array.init) ?? song.musicVideos.map(Array.init) ?? []
    }

    var station: Station? {
        relatedSong?.station ?? song.station
    }

    var audioVariants: [AudioVariant]? {
        extendedSong?.audioVariants ?? song.audioVariants
    }

    var artistURL: URL? {
        extendedSong?.artistURL ?? song.artistURL
    }
}
