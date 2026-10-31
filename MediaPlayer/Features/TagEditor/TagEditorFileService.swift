#if os(macOS)
import CryptoKit
import Foundation
import ImageIO
import TagLibSwift
import UniformTypeIdentifiers
import iTunesLibrary

nonisolated struct TagLibraryLocations: Sendable {
    let folder: URL?
    let files: [URL]
    let unavailableCount: Int
}

actor TagEditorFileService {
    func libraryLocations() throws -> TagLibraryLocations {
        let library = try ITLibrary(apiVersion: "1.0")
        var urls: [URL] = []
        var unavailable = 0
        var seen = Set<String>()
        for item in library.allMediaItems where item.mediaKind == .kindSong {
            guard !item.isDRMProtected, let url = item.location, url.isFileURL else {
                unavailable += 1
                continue
            }
            if seen.insert(url.standardizedFileURL.path).inserted { urls.append(url) }
        }
        return TagLibraryLocations(folder: library.mediaFolderLocation, files: urls, unavailableCount: unavailable)
    }

    func scan(folder: URL, library: TagLibraryLocations?, progress: @Sendable (Int) async -> Void) async throws -> TagScanResult {
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
        var urls: [URL] = []
        var issues: [TagEditorIssue] = []
        var excluded = library?.unavailableCount ?? 0
        if let library {
            urls = library.files.filter { TagEditorAnalysis.contains($0, in: folder) }
            excluded += library.files.count - urls.count
        } else {
            guard FileManager.default.isReadableFile(atPath: folder.path),
                  let enumerator = FileManager.default.enumerator(
                    at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { url, error in
                        issues.append(.init(kind: .unreadable, fileIDs: [url.path], detail: error.localizedDescription))
                        return true
                    }
                  ) else { throw TagEditorError.message("This folder cannot be read. Choose it again to grant access.") }
            for case let url as URL in enumerator {
                try Task.checkCancellation()
                guard TagFileIO.extensions.contains(url.pathExtension.lowercased()) else { continue }
                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isRegularFile == true && values.isSymbolicLink != true { urls.append(url) }
                } catch {
                    issues.append(.init(kind: .unreadable, fileIDs: [url.path], detail: error.localizedDescription))
                }
            }
        }
        var files: [TagFileSnapshot] = []
        for (index, url) in urls.enumerated() {
            try Task.checkCancellation()
            let fileAccess = url.startAccessingSecurityScopedResource()
            do { files.append(try TagFileIO.read(url)) }
            catch { issues.append(.init(kind: .unreadable, fileIDs: [url.path], detail: "\(url.lastPathComponent): \(error.localizedDescription)")) }
            if fileAccess { url.stopAccessingSecurityScopedResource() }
            if index % 25 == 0 { await progress(index + 1) }
        }
        issues += TagEditorAnalysis.basicIssues(in: files)
        return TagScanResult(files: files.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }, issues: issues, excludedLibraryItems: excluded)
    }

    func identicalFiles(_ files: [TagFileSnapshot], folder: URL, progress: @Sendable (Int) async -> Void) async throws -> [TagEditorIssue] {
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
        let groups = Dictionary(grouping: files, by: \.size).values.filter { $0.count > 1 }
        var results: [TagEditorIssue] = []
        var count = 0
        for group in groups {
            var hashes: [String: [TagFileSnapshot]] = [:]
            for file in group {
                try Task.checkCancellation()
                let access = file.url.startAccessingSecurityScopedResource()
                defer { if access { file.url.stopAccessingSecurityScopedResource() } }
                // A fresh scan is required if another program edited a file.
                let values = try file.url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard Int64(values.fileSize ?? -1) == file.size, values.contentModificationDate == file.modified else {
                    throw TagEditorError.message("Files changed during analysis. Refresh the folder and try again.")
                }
                hashes[try TagFileIO.digest(file.url), default: []].append(file)
                count += 1
                await progress(count)
            }
            for matches in hashes.values where matches.count > 1 {
                results.append(.init(kind: .identicalFiles, fileIDs: Set(matches.map(\.id)), detail: "\(matches.count) byte-for-byte identical files: \(matches[0].title)"))
            }
        }
        return results
    }

    func readableMusicFolder(candidates: [URL], requiringAudio: Bool = false) -> URL? {
        for url in candidates {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard FileManager.default.isReadableFile(atPath: url.path),
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true else { continue }
            if requiringAudio {
                guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
                var found = false
                for case let file as URL in enumerator {
                    if TagFileIO.extensions.contains(file.pathExtension.lowercased()),
                       (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                        found = true
                        break
                    }
                }
                if !found { continue }
            }
            return url
        }
        return nil
    }
}

nonisolated enum TagFileIO {
    static let extensions: Set<String> = ["mp3", "m4a", "m4b", "mp4", "aac", "flac", "ogg", "oga", "opus", "wav", "aif", "aiff", "ape", "wv", "wma", "mpc", "tta", "dsf", "dff"]

    static func read(_ url: URL) throws -> TagFileSnapshot {
        guard let file = AudioFile(path: url.path), file.isValid else {
            throw TagEditorError.message("Unsupported or damaged audio file.")
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let pictures = file.pictures
        return TagFileSnapshot(
            url: url, properties: file.properties,
            duration: file.audioProperties.map { Double($0.lengthInMilliseconds) / 1000 },
            size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate,
            artworkCount: pictures.count, artworkThumbnail: pictures.first.flatMap { thumbnail($0.data) }
        )
    }

    static func thumbnail(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 160,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    static func validate(_ edits: [TagFileEdit]) throws {
        guard !edits.isEmpty, Set(edits.map(\.id)).count == edits.count else {
            throw TagEditorError.message("The selection is empty or contains the same file more than once.")
        }
        for edit in edits {
            for change in edit.changes {
                guard change.before == edit.original.values(change.field),
                      !change.after.contains(where: { $0.contains("\0") }) else {
                    throw TagEditorError.message("Invalid value for \(change.field.title).")
                }
                if [.track, .disc].contains(change.field), let text = change.after.first {
                    let parts = text.split(separator: "/", omittingEmptySubsequences: false)
                    guard (1...2).contains(parts.count), parts.allSatisfy({ UInt32($0) != nil }) else {
                        throw TagEditorError.message("Use a number or number/total for \(change.field.title).")
                    }
                }
            }
            if let image = edit.artwork?.data, thumbnail(image) == nil {
                throw TagEditorError.message("The selected cover is not a readable image.")
            }
        }
    }

    // Called only for a private working copy. The source file is replaced after
    // every file in the operation has passed validation and has a durable backup.
    static func write(_ edit: TagFileEdit, to workingCopy: URL) throws {
        guard let file = AudioFile(path: workingCopy.path), file.isValid else {
            throw TagEditorError.message("Could not read \(edit.original.url.lastPathComponent).")
        }
        var properties = file.properties
        let originalPictures = file.pictures
        for change in edit.changes {
            properties[change.field.rawValue] = change.after.isEmpty ? nil : change.after
        }
        let rejected = file.setProperties(properties)
        guard rejected.isEmpty else {
            throw TagEditorError.message("\(edit.original.url.lastPathComponent) cannot store: \(rejected.keys.sorted().joined(separator: ", ")).")
        }
        if let artwork = edit.artwork {
            let pictures = artwork.data.map { [Picture(data: $0, mimeType: artwork.mimeType, description: "", pictureType: .frontCover)] } ?? []
            guard file.setPictures(pictures) else { throw TagEditorError.message("This file format cannot store the selected artwork change.") }
        }
        try file.save()
        let result = try read(workingCopy)
        for change in edit.changes where result.values(change.field) != change.after {
            throw TagEditorError.message("\(change.field.title) could not be stored exactly as shown for \(edit.original.title). No source files were changed.")
        }
        let allKeys = Set(edit.original.properties.keys).union(result.properties.keys)
        for key in allKeys where !edit.changes.contains(where: { $0.field.rawValue == key }) {
            guard result.properties[key] == edit.original.properties[key] else {
                throw TagEditorError.message("Saving would alter another tag in \(edit.original.title). No source files were changed.")
            }
        }
        let savedPictures = AudioFile(path: workingCopy.path)?.pictures
        if let artwork = edit.artwork {
            let expectedData = artwork.data.map { [$0] } ?? []
            guard savedPictures?.map(\.data) == expectedData else { throw TagEditorError.message("Artwork verification failed.") }
        } else if savedPictures != originalPictures {
            throw TagEditorError.message("Saving would change existing artwork. No source files were changed.")
        }
    }

    static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

extension Notification.Name {
    static let musicTrackMetadataDidChange = Notification.Name("musicTrackMetadataDidChange")
}
#endif
