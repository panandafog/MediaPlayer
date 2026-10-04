#if os(macOS)
import Foundation
import MusicKit
import TagLibSwift

nonisolated struct EditableTrackMetadata: Equatable, Sendable {
    let fileURL: URL
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var composer: String
    var genre: String
    var trackNumber: Int
    var discNumber: Int
    var artistValues: [String] = []

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.fileURL == rhs.fileURL && lhs.title == rhs.title && lhs.artist == rhs.artist
            && lhs.album == rhs.album && lhs.albumArtist == rhs.albumArtist
            && lhs.composer == rhs.composer && lhs.genre == rhs.genre
            && lhs.trackNumber == rhs.trackNumber && lhs.discNumber == rhs.discNumber
    }

    static let empty = EditableTrackMetadata(
        fileURL: URL(fileURLWithPath: "/"), title: "", artist: "", album: "",
        albumArtist: "", composer: "", genre: "", trackNumber: 0, discNumber: 0
    )
}

nonisolated struct SongFileIdentity: Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval?
    let trackNumber: Int?
    let discNumber: Int?

    init(song: Song) {
        title = song.title
        artist = song.artistName
        album = song.albumTitle ?? ""
        duration = song.duration
        trackNumber = song.trackNumber
        discNumber = song.discNumber
    }

    init(title: String, artist: String, album: String, duration: TimeInterval?, trackNumber: Int?, discNumber: Int?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.discNumber = discNumber
    }

    func matches(_ metadata: EditableTrackMetadata, duration fileDuration: TimeInterval?) -> Bool {
        guard title.compare(metadata.title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame,
              artist.compare(metadata.artist, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame,
              album.compare(metadata.album, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else {
            return false
        }
        if let duration, duration.isFinite, duration > 0,
           let fileDuration, abs(duration - fileDuration) > 2 {
            return false
        }
        if let trackNumber, trackNumber > 0, trackNumber != metadata.trackNumber { return false }
        if let discNumber, discNumber > 0, discNumber != metadata.discNumber { return false }
        return true
    }
}

nonisolated enum AudioFileMetadataError: LocalizedError {
    case unsupportedFile
    case fileDoesNotMatch
    case fileChanged
    case invalidFields
    case unsupportedFields(String)
    case verificationFailed
    case missingTracks(Int)
    case ambiguousTracks

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: "This file could not be opened as a supported audio format."
        case .fileDoesNotMatch: "The selected file's tags do not match this library track. Choose its original audio file."
        case .fileChanged: "The file's tags changed while the editor was open. Reopen it before saving."
        case .invalidFields: "Enter a title and artist, and use track and disc numbers from 0 to 4,294,967,295."
        case .unsupportedFields(let fields): "This file cannot store the edited fields: \(fields). No changes were saved."
        case .verificationFailed: "The file was written, but its new tags could not be verified. Check the file before trying again."
        case .missingTracks(let count): "\(count) library track(s) could not be matched to files in this folder. No changes were made."
        case .ambiguousTracks: "Multiple files match one or more library tracks. Choose a more specific folder; no changes were made."
        }
    }
}

actor AudioFileMetadataService {
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "mp4", "aac", "flac", "ogg", "opus", "wav", "aif", "aiff", "ape", "wv", "wma"
    ]

    func load(at url: URL, matching identity: SongFileIdentity? = nil) throws -> EditableTrackMetadata {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let (metadata, duration) = try read(url)
        if let identity, !identity.matches(metadata, duration: duration) {
            throw AudioFileMetadataError.fileDoesNotMatch
        }
        return metadata
    }

    func match(_ identities: [SongFileIdentity], in folder: URL) throws -> [EditableTrackMetadata] {
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw AudioFileMetadataError.missingTracks(identities.count)
        }

        var candidates: [(EditableTrackMetadata, TimeInterval?)] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            guard Self.supportedExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let candidate = try? read(url) else { continue }
            candidates.append(candidate)
        }

        var matches: [EditableTrackMetadata] = []
        var missingCount = 0
        for identity in identities {
            let found = candidates.filter { identity.matches($0.0, duration: $0.1) }
            if found.count > 1 { throw AudioFileMetadataError.ambiguousTracks }
            if let match = found.first?.0 { matches.append(match) }
            else { missingCount += 1 }
        }
        if missingCount > 0 { throw AudioFileMetadataError.missingTracks(missingCount) }
        if Set(matches.map(\.fileURL)).count != matches.count {
            throw AudioFileMetadataError.ambiguousTracks
        }
        return matches
    }

    func save(_ edited: EditableTrackMetadata, replacing original: EditableTrackMetadata, accessThrough folder: URL? = nil) throws {
        guard edited.fileURL == original.fileURL,
              !edited.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !edited.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              edited.trackNumber >= 0, edited.discNumber >= 0,
              edited.trackNumber <= Int(UInt32.max), edited.discNumber <= Int(UInt32.max) else {
            throw AudioFileMetadataError.invalidFields
        }

        let scope = folder ?? original.fileURL
        let accessed = scope.startAccessingSecurityScopedResource()
        defer { if accessed { scope.stopAccessingSecurityScopedResource() } }
        let (current, _) = try read(original.fileURL)
        guard current == original else { throw AudioFileMetadataError.fileChanged }
        guard edited != original else { return }
        guard let file = AudioFile(path: original.fileURL.path), file.isValid else {
            throw AudioFileMetadataError.unsupportedFile
        }

        var properties = file.properties
        var expected = edited
        func update(_ key: String, _ old: String, _ new: String) {
            if old != new { properties[key] = new.isEmpty ? nil : [new] }
        }
        update("TITLE", original.title, edited.title)
        if original.artist != edited.artist {
            let values = (properties["ARTIST"]?.count ?? 0) > 1
                ? edited.artist.split(separator: ";", omittingEmptySubsequences: true)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                : [edited.artist]
            properties["ARTIST"] = values
            if values.count > 1 { expected.artist = values.joined(separator: "; ") }
        }
        update("ALBUM", original.album, edited.album)
        update("ALBUMARTIST", original.albumArtist, edited.albumArtist)
        update("COMPOSER", original.composer, edited.composer)
        update("GENRE", original.genre, edited.genre)
        update("TRACKNUMBER", String(original.trackNumber), String(edited.trackNumber))
        update("DISCNUMBER", String(original.discNumber), String(edited.discNumber))

        let rejected = file.setProperties(properties)
        if !rejected.isEmpty {
            throw AudioFileMetadataError.unsupportedFields(rejected.keys.sorted().joined(separator: ", "))
        }
        try file.save()
        let (saved, _) = try read(original.fileURL)
        guard saved == expected else { throw AudioFileMetadataError.verificationFailed }
    }

    private func read(_ url: URL) throws -> (EditableTrackMetadata, TimeInterval?) {
        guard let file = AudioFile(path: url.path), file.isValid else {
            throw AudioFileMetadataError.unsupportedFile
        }
        let properties = file.properties
        let artistValues = properties["ARTIST"] ?? []
        var metadata = EditableTrackMetadata(
            fileURL: url,
            title: file.tag.title,
            artist: artistValues.count > 1 ? artistValues.joined(separator: "; ") : file.tag.artist,
            album: file.tag.album,
            albumArtist: properties["ALBUMARTIST"]?.first ?? "",
            composer: properties["COMPOSER"]?.first ?? "",
            genre: file.tag.genre,
            trackNumber: Int(file.tag.track),
            discNumber: Int(properties["DISCNUMBER"]?.first ?? "") ?? 0
        )
        metadata.artistValues = artistValues
        let milliseconds = file.audioProperties?.lengthInMilliseconds
        return (metadata, milliseconds.map { TimeInterval($0) / 1_000 })
    }
}

extension Notification.Name {
    static let musicTrackMetadataDidChange = Notification.Name("musicTrackMetadataDidChange")
}
#endif
