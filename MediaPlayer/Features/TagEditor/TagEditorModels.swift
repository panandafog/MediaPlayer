#if os(macOS)
import Foundation

nonisolated enum TagEditorSource: String, CaseIterable, Identifiable {
    case library, folder
    var id: String { rawValue }
    var title: String { self == .library ? "Music Library Files" : "All Audio Files in Folder" }
}

nonisolated enum TagField: String, CaseIterable, Codable, Identifiable, Sendable {
    case title = "TITLE", artist = "ARTIST", album = "ALBUM", albumArtist = "ALBUMARTIST"
    case composer = "COMPOSER", genre = "GENRE", date = "DATE"
    case track = "TRACKNUMBER", disc = "DISCNUMBER", comment = "COMMENT"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        case .albumArtist: "Album Artist"
        case .composer: "Composer"
        case .genre: "Genre"
        case .date: "Date / Year"
        case .track: "Track Number"
        case .disc: "Disc Number"
        case .comment: "Comment"
        }
    }
    var supportsMultipleValues: Bool { [.artist, .albumArtist, .composer, .genre].contains(self) }
    func values(from text: String) -> [String] {
        if text.isEmpty { return [] }
        return supportsMultipleValues ? text.components(separatedBy: .newlines).filter { !$0.isEmpty } : [text]
    }
}

nonisolated struct TagFileSnapshot: Identifiable, Codable, Sendable {
    let url: URL
    let properties: [String: [String]]
    let duration: TimeInterval?
    let size: Int64
    let modified: Date?
    let artworkCount: Int
    let artworkThumbnail: Data?
    var id: String { url.standardizedFileURL.path }
    func values(_ field: TagField) -> [String] { properties[field.rawValue] ?? [] }
    func text(_ field: TagField) -> String { values(field).joined(separator: "; ") }
    var title: String { text(.title).isEmpty ? url.deletingPathExtension().lastPathComponent : text(.title) }
    var artist: String { text(.artist).isEmpty ? "Unknown Artist" : text(.artist) }
    var album: String { text(.album).isEmpty ? "Unknown Album" : text(.album) }
    var albumArtist: String { text(.albumArtist).isEmpty ? artist : text(.albumArtist) }
    var albumID: String { albumArtist + "\u{0}" + album }
}

nonisolated struct TagPropertyChange: Codable, Sendable, Identifiable {
    let field: TagField
    let before: [String]
    let after: [String]
    var id: TagField { field }
    var reversed: Self { Self(field: field, before: after, after: before) }
}

nonisolated struct TagArtworkEdit: Sendable {
    // nil means explicitly remove every embedded image.
    let data: Data?
    let mimeType: String
}

nonisolated struct TagFileEdit: Identifiable, Sendable {
    let original: TagFileSnapshot
    let changes: [TagPropertyChange]
    let artwork: TagArtworkEdit?
    var id: String { original.id }
}

nonisolated struct TagArtistRename: Sendable {
    let name: String
    let replacement: String
    let separators: String
}

nonisolated enum TagEditPlan {
    static func make(files: [TagFileSnapshot], replacements: [TagField: [String]], artistRename: TagArtistRename? = nil, artwork: TagArtworkEdit? = nil) throws -> [TagFileEdit] {
        if let rename = artistRename, rename.replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TagEditorError.message("Enter the new artist name.")
        }
        return try files.compactMap { file in
            var values = replacements
            if let rename = artistRename {
                var matched = false
                values[.artist] = file.values(.artist).map { credit in
                    guard let value = ArtistCreditRewriter.replacing(rename.name, in: credit, with: rename.replacement, separatorCharacters: rename.separators) else { return credit }
                    matched = true
                    return value
                }
                guard matched else { throw TagEditorError.message("Could not locate \(rename.name) in the credits of \(file.title).") }
            }
            let changes = TagField.allCases.compactMap { field -> TagPropertyChange? in
                guard let after = values[field], after != file.values(field) else { return nil }
                return TagPropertyChange(field: field, before: file.values(field), after: after)
            }
            let artwork = artwork?.data == nil && file.artworkCount == 0 ? nil : artwork
            return changes.isEmpty && artwork == nil ? nil : TagFileEdit(original: file, changes: changes, artwork: artwork)
        }
    }
}

nonisolated enum TagIssueKind: String, CaseIterable, Identifiable, Sendable {
    case identicalFiles, possibleDuplicates, missingArtwork, missingTags, missingTrackNumber
    case whitespace, inconsistentAlbumArtist, unreadable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .identicalFiles: "Identical Files"
        case .possibleDuplicates: "Possible Duplicates"
        case .missingArtwork: "Missing Embedded Artwork"
        case .missingTags: "Missing Title, Artist or Album"
        case .missingTrackNumber: "Missing Track Number"
        case .whitespace: "Extra Whitespace"
        case .inconsistentAlbumArtist: "Inconsistent Album Artist"
        case .unreadable: "Unreadable Files"
        }
    }
}

nonisolated struct TagEditorIssue: Identifiable, Sendable {
    let kind: TagIssueKind
    let fileIDs: Set<String>
    let detail: String
    var id: String { kind.rawValue + fileIDs.sorted().joined(separator: "\u{0}") + detail }
}

nonisolated struct TagScanResult: Sendable {
    var files: [TagFileSnapshot]
    var issues: [TagEditorIssue]
    var excludedLibraryItems = 0
}

nonisolated enum TagEditorAnalysis {
    static func basicIssues(in files: [TagFileSnapshot]) -> [TagEditorIssue] {
        var issues: [TagEditorIssue] = []
        for file in files {
            if file.artworkCount == 0 {
                issues.append(.init(kind: .missingArtwork, fileIDs: [file.id], detail: file.title))
            }
            let missing = [TagField.title, .artist, .album].filter {
                file.text($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !missing.isEmpty {
                issues.append(.init(kind: .missingTags, fileIDs: [file.id], detail: missing.map(\.title).joined(separator: ", ")))
            }
            if (Int(file.text(.track).split(separator: "/").first ?? "") ?? 0) <= 0 {
                issues.append(.init(kind: .missingTrackNumber, fileIDs: [file.id], detail: file.title))
            }
            if TagField.allCases.contains(where: { field in
                file.values(field).contains { $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }) {
                issues.append(.init(kind: .whitespace, fileIDs: [file.id], detail: file.title))
            }
        }
        // Titles alone are not evidence of duplicates. Require matching artists,
        // album and nearly equal known durations, and label these as candidates.
        let credits = Dictionary(grouping: files.filter { !$0.text(.title).isEmpty && !$0.text(.artist).isEmpty }) {
            [$0.text(.title), $0.text(.artist), $0.text(.album)].map(normalize).joined(separator: "\u{0}")
        }
        for group in credits.values where group.count > 1 {
            let sorted = group.sorted { ($0.duration ?? -.infinity) < ($1.duration ?? -.infinity) }
            var cluster: [TagFileSnapshot] = []
            func appendCluster() {
                if cluster.count > 1 {
                    issues.append(.init(kind: .possibleDuplicates, fileIDs: Set(cluster.map(\.id)), detail: cluster[0].title))
                }
            }
            for file in sorted {
                guard let duration = file.duration, duration > 0 else { continue }
                if let first = cluster.first?.duration, duration - first > 2 { appendCluster(); cluster = [] }
                cluster.append(file)
            }
            appendCluster()
        }
        let albums = Dictionary(grouping: files.filter { !$0.text(.album).isEmpty }) {
            $0.url.deletingLastPathComponent().path + "\u{0}" + normalize($0.text(.album))
        }
        for group in albums.values where Set(group.map { normalize($0.text(.albumArtist)) }).count > 1 {
            issues.append(.init(kind: .inconsistentAlbumArtist, fileIDs: Set(group.map(\.id)), detail: group[0].album))
        }
        return issues
    }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func contains(_ url: URL, in folder: URL) -> Bool {
        let parent = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let child = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return child.count > parent.count && Array(child.prefix(parent.count)) == parent
    }
}

nonisolated enum TagEditorError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}
#endif
