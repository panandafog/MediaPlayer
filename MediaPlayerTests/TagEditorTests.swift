#if os(macOS)
import Foundation
import Testing
@testable import PlayerApp

struct TagEditorTests {
    @Test func batchPlanChangesOnlyExplicitlyEnabledFields() throws {
        let first = snapshot("one.mp3", properties: ["TITLE": ["One"], "ALBUM": ["Old"], "ARTIST": ["Artist 1", "Artist 2"], "COMMENT": ["Keep me"]])
        let second = snapshot("two.mp3", properties: ["TITLE": ["Two"], "ALBUM": ["Other"], "ARTIST": ["Artist 3"]])
        let edits = try TagEditPlan.make(files: [first, second], replacements: [.album: ["New"]])
        #expect(edits.count == 2)
        #expect(edits.allSatisfy { $0.changes.count == 1 && $0.changes[0].field == .album && $0.changes[0].after == ["New"] })
        #expect(edits[0].original.values(.artist) == ["Artist 1", "Artist 2"])
        #expect(edits[0].original.values(.comment) == ["Keep me"])
        #expect(edits.allSatisfy { $0.artwork == nil })
    }

    @Test func artistRenamePreservesStructuredAndCombinedCredits() throws {
        let first = snapshot("one.mp3", properties: ["ARTIST": ["Artist 1", "Artist 2"]])
        let second = snapshot("two.mp3", properties: ["ARTIST": ["Artist 1 feat. Artist 3"]])
        let edits = try TagEditPlan.make(files: [first, second], replacements: [:], artistRename: TagArtistRename(name: "Artist 1", replacement: "New Artist", separators: ";,&/"))
        #expect(edits[0].changes[0].after == ["New Artist", "Artist 2"])
        #expect(edits[1].changes[0].after == ["New Artist feat. Artist 3"])
    }

    @Test func blankEnabledFieldIsExplicitlyClearedAndUnchangedEditsAreOmitted() throws {
        let file = snapshot("one.mp3", properties: ["TITLE": ["One"], "COMMENT": ["Remove"]])
        let edits = try TagEditPlan.make(files: [file], replacements: [.title: ["One"], .comment: []])
        #expect(edits.count == 1)
        #expect(edits[0].changes.count == 1)
        #expect(edits[0].changes[0].field == .comment)
        #expect(edits[0].changes[0].before == ["Remove"])
        #expect(edits[0].changes[0].after.isEmpty)
        #expect(try TagEditPlan.make(files: [file], replacements: [:]).isEmpty)
    }

    @Test func issueDetectionSeparatesCandidateDuplicatesFromDifferentVersions() {
        let properties = ["TITLE": ["Song"], "ARTIST": ["Artist"], "ALBUM": ["Album"]]
        let first = snapshot("one.mp3", properties: properties, duration: 200)
        let second = snapshot("two.mp3", properties: properties, duration: 201)
        let extended = snapshot("long.mp3", properties: properties, duration: 245)
        let issues = TagEditorAnalysis.basicIssues(in: [first, second, extended])
        #expect(issues.filter { $0.kind == .possibleDuplicates }.map(\.fileIDs) == [Set([first.id, second.id])])
        #expect(!issues.contains { $0.kind == .identicalFiles })
        #expect(issues.filter { $0.kind == .missingArtwork }.count == 3)
        #expect(issues.filter { $0.kind == .missingTrackNumber }.count == 3)
    }

    @Test func folderContainmentDoesNotMatchSiblingWithSamePrefix() {
        let folder = URL(fileURLWithPath: "/tmp/tag-editor-test/Music")
        #expect(TagEditorAnalysis.contains(folder.appendingPathComponent("Album/file.mp3"), in: folder))
        #expect(!TagEditorAnalysis.contains(URL(fileURLWithPath: "/tmp/tag-editor-test/Music Elsewhere/file.mp3"), in: folder))
        #expect(!TagEditorAnalysis.contains(folder, in: folder))
    }

    @Test func folderScanIncludesUnregisteredFilesButLibraryScanUsesExactURLs() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Music", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let registered = try makeWave(in: folder, name: "registered.wav")
        let unregistered = try makeWave(in: folder, name: "unregistered.wav")
        let outside = try makeWave(in: root, name: "outside.wav")
        let service = TagEditorFileService()
        let disk = try await service.scan(folder: folder, library: nil) { _ in }
        #expect(Set(disk.files.map(\.id)) == Set([registered.path, unregistered.path]))
        let library = TagLibraryLocations(folder: folder, files: [registered, outside], unavailableCount: 2)
        let filtered = try await service.scan(folder: folder, library: library) { _ in }
        #expect(filtered.files.map(\.id) == [registered.path])
        #expect(filtered.excludedLibraryItems == 3)
        let duplicates = try await service.identicalFiles(disk.files, folder: folder) { _ in }
        #expect(duplicates.count == 1)
        #expect(duplicates.first?.fileIDs == Set([registered.path, unregistered.path]))
    }

    @Test func artworkRemovalIsExplicitAndSkipsFilesWithoutArtwork() throws {
        let bare = snapshot("bare.mp3", properties: [:])
        let covered = TagFileSnapshot(url: URL(fileURLWithPath: "/tmp/covered.mp3"), properties: [:], duration: 1, size: 100, modified: nil, artworkCount: 2, artworkThumbnail: nil)
        #expect(try TagEditPlan.make(files: [bare, covered], replacements: [:]).isEmpty)
        let edits = try TagEditPlan.make(files: [bare, covered], replacements: [:], artwork: TagArtworkEdit(data: nil, mimeType: ""))
        #expect(edits.count == 1)
        #expect(edits.first?.id == covered.id)
        #expect(edits.first?.artwork != nil)
        #expect(edits.first?.artwork?.data == nil)
    }

    @Test func applyAndUndoRestoreOriginalBytesAfterReloadingHistory() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeWave(in: root, name: "one.wav")
        let originalBytes = try Data(contentsOf: source)
        let file = try TagFileIO.read(source)
        let edits = try TagEditPlan.make(files: [file], replacements: [.album: ["New Album"], .artist: ["Artist"]])
        let historyURL = root.appendingPathComponent("history", isDirectory: true)
        let store = TagEditorHistory(directory: historyURL)
        try await store.apply(edits, folder: root) { _ in }
        #expect(try TagFileIO.read(source).values(.album) == ["New Album"])
        let reopened = TagEditorHistory(directory: historyURL)
        let operations = try await reopened.operations()
        let operation = try #require(operations.first)
        #expect(operation.status == .applied)
        #expect(operation.files[0].changes.count == 2)
        try await reopened.undo(operation) { _ in }
        #expect(try Data(contentsOf: source) == originalBytes)
        #expect(try await reopened.operations().isEmpty)
    }

    @Test func staleFileInBatchPreventsEverySourceWrite() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try makeWave(in: root, name: "one.wav")
        let second = try makeWave(in: root, name: "two.wav")
        let firstBytes = try Data(contentsOf: first)
        let snapshots = try [first, second].map(TagFileIO.read)
        let edits = try TagEditPlan.make(files: snapshots, replacements: [.album: ["New Album"]])
        // Simulate an external change after the user opened the preview.
        let handle = try FileHandle(forWritingTo: second)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0, 0]))
        try handle.close()
        let changedBytes = try Data(contentsOf: second)
        let store = TagEditorHistory(directory: root.appendingPathComponent("history"))
        await #expect(throws: (any Error).self) { try await store.apply(edits, folder: root) { _ in } }
        #expect(try Data(contentsOf: first) == firstBytes)
        #expect(try Data(contentsOf: second) == changedBytes)
    }

    @Test func undoRefusesToOverwriteAnExternalEdit() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeWave(in: root, name: "one.wav")
        let edits = try TagEditPlan.make(files: [TagFileIO.read(source)], replacements: [.album: ["New Album"]])
        let store = TagEditorHistory(directory: root.appendingPathComponent("history"))
        try await store.apply(edits, folder: root) { _ in }
        let operations = try await store.operations()
        let operation = try #require(operations.first)
        let handle = try FileHandle(forWritingTo: source)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([1, 2, 3, 4]))
        try handle.close()
        let externalBytes = try Data(contentsOf: source)
        await #expect(throws: (any Error).self) { try await store.undo(operation) { _ in } }
        #expect(try Data(contentsOf: source) == externalBytes)
        #expect(try await store.operations().count == 1)
    }

    @Test func interruptedJournalCanRecoverAfterRelaunch() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeWave(in: root, name: "one.wav")
        let originalBytes = try Data(contentsOf: source)
        let edits = try TagEditPlan.make(files: [TagFileIO.read(source)], replacements: [.album: ["New Album"]])
        let historyURL = root.appendingPathComponent("history", isDirectory: true)
        let store = TagEditorHistory(directory: historyURL)
        try await store.apply(edits, folder: root) { _ in }
        let operations = try await store.operations()
        var operation = try #require(operations.first)
        // Model termination after a source replacement, before the final journal update.
        operation.status = .applying
        let manifest = historyURL.appendingPathComponent(operation.id.uuidString).appendingPathComponent("operation.json")
        try JSONEncoder().encode(operation).write(to: manifest, options: .atomic)
        let reopened = TagEditorHistory(directory: historyURL)
        let recovered = try await reopened.operations()
        let pending = try #require(recovered.first)
        #expect(pending.requiresRecovery)
        try await reopened.undo(pending) { _ in }
        #expect(try Data(contentsOf: source) == originalBytes)
        #expect(try await reopened.operations().isEmpty)
    }

    private func snapshot(_ name: String, properties: [String: [String]], duration: TimeInterval = 200) -> TagFileSnapshot {
        TagFileSnapshot(url: URL(fileURLWithPath: "/tmp/tag-editor-test/\(name)"), properties: properties, duration: duration, size: 1000, modified: nil, artworkCount: 0, artworkThumbnail: nil)
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tag-editor-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeWave(in root: URL, name: String) throws -> URL {
        let sampleCount = 8_000
        var data = Data("RIFF".utf8)
        func number<T: FixedWidthInteger>(_ value: T) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        number(UInt32(36 + sampleCount * 2))
        data.append(Data("WAVEfmt ".utf8))
        number(UInt32(16)); number(UInt16(1)); number(UInt16(1))
        number(UInt32(8_000)); number(UInt32(16_000)); number(UInt16(2)); number(UInt16(16))
        data.append(Data("data".utf8)); number(UInt32(sampleCount * 2))
        data.append(Data(repeating: 0, count: sampleCount * 2))
        let url = root.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
#endif
