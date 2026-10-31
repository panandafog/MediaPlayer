#if os(macOS)
import Foundation

nonisolated struct TagHistoryFile: Codable, Identifiable, Sendable {
    let url: URL
    let bookmark: Data
    let backupName: String
    let editedName: String
    let beforeHash: String
    let afterHash: String
    let before: TagFileSnapshot
    let after: TagFileSnapshot
    let changes: [TagPropertyChange]
    let changesArtwork: Bool
    var id: String { url.path }
}

nonisolated struct TagHistoryOperation: Codable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable { case applying, applied, undoing, undone, recovery }
    let id: UUID
    let date: Date
    var status: Status
    let folderBookmark: Data?
    let files: [TagHistoryFile]
    var requiresRecovery: Bool { status != .applied && status != .undone }
}

actor TagEditorHistory {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Trackfold/TagEditorHistory", isDirectory: true)
    }

    func operations() throws -> [TagHistoryOperation] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { UUID(uuidString: $0.lastPathComponent) != nil }
            .compactMap { folder -> TagHistoryOperation? in
                let manifest = folder.appendingPathComponent("operation.json")
                guard FileManager.default.fileExists(atPath: manifest.path) else { return nil }
                return try JSONDecoder().decode(TagHistoryOperation.self, from: Data(contentsOf: manifest))
            }
            .filter { $0.status != .undone }
            .sorted { $0.date > $1.date }
    }

    func apply(_ edits: [TagFileEdit], folder: URL, progress: @Sendable (String) async -> Void) async throws {
        try TagFileIO.validate(edits)
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        let operationFolder = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: operationFolder, withIntermediateDirectories: true)
        var journal: TagHistoryOperation?
        var attemptedFileIDs = Set<String>()
        do {
            var prepared: [TagHistoryFile] = []
            for (index, edit) in edits.enumerated() {
                try Task.checkCancellation()
                await progress("Preparing \(index + 1) of \(edits.count)…")
                guard TagEditorAnalysis.contains(edit.original.url, in: folder) else {
                    throw TagEditorError.message("A selected file is outside the current folder.")
                }
                let fileAccess = edit.original.url.startAccessingSecurityScopedResource()
                defer { if fileAccess { edit.original.url.stopAccessingSecurityScopedResource() } }
                guard FileManager.default.isWritableFile(atPath: edit.original.url.path) else {
                    throw TagEditorError.message("\(edit.original.url.lastPathComponent) is read-only. No source files were changed.")
                }
                let backupName = "\(index)-original.\(edit.original.url.pathExtension)"
                let editedName = "\(index)-edited.\(edit.original.url.pathExtension)"
                let backup = operationFolder.appendingPathComponent(backupName)
                let working = operationFolder.appendingPathComponent(editedName)
                // Coordinated reading protects the snapshot/backup boundary.
                try coordinatedRead(edit.original.url) { url in
                    let current = try TagFileIO.read(url)
                    guard current.properties == edit.original.properties,
                          current.size == edit.original.size, current.modified == edit.original.modified,
                          current.artworkCount == edit.original.artworkCount else {
                        throw TagEditorError.message("\(url.lastPathComponent) changed since it was loaded. Refresh before editing.")
                    }
                    try FileManager.default.copyItem(at: url, to: backup)
                }
                try FileManager.default.copyItem(at: backup, to: working)
                try TagFileIO.write(edit, to: working)
                let after = try TagFileIO.read(working)
                let bookmark = try edit.original.url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                prepared.append(TagHistoryFile(
                    url: edit.original.url, bookmark: bookmark, backupName: backupName, editedName: editedName,
                    beforeHash: try TagFileIO.digest(backup), afterHash: try TagFileIO.digest(working),
                    before: edit.original, after: after, changes: edit.changes, changesArtwork: edit.artwork != nil
                ))
            }
            let folderBookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            var operation = TagHistoryOperation(id: id, date: Date(), status: .applying, folderBookmark: folderBookmark, files: prepared)
            try persist(operation)
            journal = operation
            // Preflight the entire set before replacing the first source file.
            for file in prepared {
                try withAccess(file) { url in
                    guard try TagFileIO.digest(url) == file.beforeHash else {
                        throw TagEditorError.message("\(url.lastPathComponent) changed before saving. No further files were changed.")
                    }
                }
            }
            for (index, file) in prepared.enumerated() {
                await progress("Applying \(index + 1) of \(prepared.count)…")
                try withAccess(file) { url in
                    attemptedFileIDs.insert(file.id)
                    try replace(url, from: operationFolder.appendingPathComponent(file.editedName), expectedHash: file.beforeHash)
                    guard try TagFileIO.digest(url) == file.afterHash else { throw TagEditorError.message("The saved file could not be verified.") }
                }
            }
            operation.status = .applied
            try persist(operation)
            for file in prepared { try? FileManager.default.removeItem(at: operationFolder.appendingPathComponent(file.editedName)) }
        } catch {
            let originalError = error
            if let journal {
                // An untouched file may have changed externally during preflight.
                // Never roll that change back or report it as one of our writes.
                var operation = TagHistoryOperation(
                    id: journal.id, date: journal.date, status: .recovery,
                    folderBookmark: journal.folderBookmark,
                    files: journal.files.filter { attemptedFileIDs.contains($0.id) }
                )
                let failures = restore(operation)
                operation.status = failures.isEmpty ? .undone : .recovery
                try persist(operation)
                if !failures.isEmpty {
                    throw TagEditorError.message("The operation stopped. Backups are saved in History; use Restore to finish recovery. Files requiring attention: \(failures.joined(separator: ", ")). \(originalError.localizedDescription)")
                }
                try? FileManager.default.removeItem(at: operationFolder)
                let outcome = attemptedFileIDs.isEmpty ? "No source files were changed." : "The original files were restored."
                throw TagEditorError.message("The operation stopped. \(outcome) \(originalError.localizedDescription)")
            }
            // This directory contains only private copies; no source write began.
            try? FileManager.default.removeItem(at: operationFolder)
            throw originalError
        }
    }

    func undo(_ requested: TagHistoryOperation, progress: @Sendable (String) async -> Void) async throws {
        guard var operation = try operations().first(where: { $0.id == requested.id }) else {
            throw TagEditorError.message("This operation is no longer available to undo.")
        }
        // A directory grant also allows coordinated atomic replacement when the
        // editor is now browsing a different folder or has been relaunched.
        let accessURL = operation.folderBookmark.flatMap { try? resolveBookmark($0) }
        let accessed = accessURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessed { accessURL?.stopAccessingSecurityScopedResource() } }
        let folder = directory.appendingPathComponent(operation.id.uuidString)
        // Refuse the whole undo when a later edit would otherwise be overwritten.
        for file in operation.files {
            try withAccess(file) { url in
                let hash = try TagFileIO.digest(url)
                guard hash == file.afterHash || hash == file.beforeHash,
                      try TagFileIO.digest(folder.appendingPathComponent(file.backupName)) == file.beforeHash else {
                    throw TagEditorError.message("\(file.url.lastPathComponent) has changed since this operation, or its backup is unavailable. Undo was not started.")
                }
            }
        }
        operation.status = .undoing
        try persist(operation)
        await progress("Restoring original files…")
        let failures = restore(operation)
        operation.status = failures.isEmpty ? .undone : .recovery
        try persist(operation)
        if !failures.isEmpty {
            throw TagEditorError.message("Some files could not be restored: \(failures.joined(separator: ", ")). Backups remain in History; retry Restore after resolving the problem.")
        }
        // Only discard private copies after the originals have been verified.
        try? FileManager.default.removeItem(at: folder)
    }

    private func restore(_ operation: TagHistoryOperation) -> [String] {
        let folder = directory.appendingPathComponent(operation.id.uuidString)
        var failures: [String] = []
        for file in operation.files.reversed() {
            do {
                try withAccess(file) { url in
                    let hash = try TagFileIO.digest(url)
                    if hash == file.beforeHash { return }
                    guard hash == file.afterHash else { throw TagEditorError.message("File changed externally.") }
                    let backup = folder.appendingPathComponent(file.backupName)
                    guard try TagFileIO.digest(backup) == file.beforeHash else { throw TagEditorError.message("Backup changed.") }
                    try replace(url, from: backup, expectedHash: file.afterHash)
                    guard try TagFileIO.digest(url) == file.beforeHash else { throw TagEditorError.message("Restored file could not be verified.") }
                }
            } catch { failures.append(file.url.lastPathComponent) }
        }
        return failures
    }

    private func persist(_ operation: TagHistoryOperation) throws {
        let path = directory.appendingPathComponent(operation.id.uuidString).appendingPathComponent("operation.json")
        try JSONEncoder().encode(operation).write(to: path, options: .atomic)
    }

    private func withAccess<T>(_ file: TagHistoryFile, action: (URL) throws -> T) throws -> T {
        let url = try resolveBookmark(file.bookmark)
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try action(url)
    }

    private func resolveBookmark(_ data: Data) throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private func coordinatedRead(_ url: URL, action: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var actionError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            do { try action(coordinated) } catch { actionError = error }
        }
        if let coordinationError { throw coordinationError }
        if let actionError { throw actionError }
    }

    private func replace(_ url: URL, from copy: URL, expectedHash: String) throws {
        var coordinationError: NSError?
        var actionError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinated in
            do {
                guard try TagFileIO.digest(coordinated) == expectedHash else {
                    throw TagEditorError.message("\(url.lastPathComponent) changed during the operation.")
                }
                let temporary = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: coordinated, create: true)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let replacement = temporary.appendingPathComponent(coordinated.lastPathComponent)
                try FileManager.default.copyItem(at: copy, to: replacement)
                _ = try FileManager.default.replaceItemAt(coordinated, withItemAt: replacement)
            } catch { actionError = error }
        }
        if let coordinationError { throw coordinationError }
        if let actionError { throw actionError }
    }
}
#endif
