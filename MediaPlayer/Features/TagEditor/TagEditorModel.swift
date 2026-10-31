#if os(macOS)
import AppKit
import Combine
import Foundation

enum TagEditorFocus {
    case song(title: String, artist: String, album: String)
    case artist(String)
    case album(title: String, artist: String)
}

enum TagEditorPage: Hashable {
    case tracks, artists, albums, issues
    case artist(String), album(String), issue(TagIssueKind)
    var title: String {
        switch self {
        case .tracks: "Tracks"
        case .artists: "Artists"
        case .albums: "Albums"
        case .issues: "Problems"
        case .artist(let name): name
        case .album(let id): id.components(separatedBy: "\u{0}").last ?? "Album"
        case .issue(let kind): kind.title
        }
    }
}

struct TagEditorGroup: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let files: [TagFileSnapshot]
}

@MainActor
final class TagEditorModel: ObservableObject {
    static let windowID = "tag-editor"
    @Published private(set) var folder: URL?
    @Published private(set) var source: TagEditorSource
    @Published private(set) var files: [TagFileSnapshot] = []
    @Published private(set) var issues: [TagEditorIssue] = []
    @Published private(set) var history: [TagHistoryOperation] = []
    @Published private(set) var isBusy = false
    @Published private(set) var isWriting = false
    @Published private(set) var progress = ""
    @Published private(set) var excludedCount = 0
    @Published private(set) var didCheckDuplicates = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selection: Set<String> = []
    @Published var section: TagEditorPage = .tracks
    @Published var path: [TagEditorPage] = []

    private let service = TagEditorFileService()
    private let historyStore = TagEditorHistory()
    private let defaults: UserDefaults
    private var scanTask: Task<Void, Never>?
    private var scanID = UUID()
    private var hasStarted = false
    private var pendingFocus: TagEditorFocus?
    private var folderAccess = false
    private var suggestedFolder: URL?
    private var albumIDsByFile: [String: String] = [:]
    private static let bookmarkKey = "tagEditorFolderBookmark"
    private static let sourceKey = "tagEditorSource"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        source = defaults.string(forKey: Self.sourceKey).flatMap(TagEditorSource.init(rawValue:)) ?? .library
    }

    var currentPage: TagEditorPage { path.last ?? section }
    var selectedFiles: [TagFileSnapshot] { files.filter { selection.contains($0.id) } }

    func open(_ focus: TagEditorFocus? = nil) {
        pendingFocus = focus
        if hasStarted && !isBusy { focusSelection() }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await reloadHistory()
        if let data = defaults.data(forKey: Self.bookmarkKey) {
            do {
                var stale = false
                let saved = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
                if await service.readableMusicFolder(candidates: [saved]) != nil {
                    try useFolder(saved)
                    refresh()
                    return
                }
            } catch { /* A moved or disconnected folder is resolved by the chooser. */ }
        }
        isBusy = true
        progress = "Locating music…"
        var candidates: [URL] = []
        if source == .library, let locations = try? await service.libraryLocations(), let root = locations.folder {
            candidates.append(root)
        }
        let musicFolders = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)
        candidates += musicFolders.flatMap { root in
            [root.appendingPathComponent("Music/Media"), root.appendingPathComponent("iTunes/iTunes Media"), root]
        }
        suggestedFolder = candidates.first
        if let found = await service.readableMusicFolder(candidates: candidates, requiringAudio: true) {
            do { try useFolder(found); isBusy = false; refresh(); return }
            catch { suggestedFolder = found }
        }
        isBusy = false
        chooseFolder()
    }

    func chooseFolder() {
        guard !isWriting else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose Your Music Folder"
        panel.message = "Choose the folder to browse and edit. Its subfolders will be included. You can change it at any time in the tag editor."
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder ?? suggestedFolder
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do { try self.useFolder(url); self.refresh() }
            catch { self.errorMessage = error.localizedDescription }
        }
    }

    private func useFolder(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            if folderAccess { folder?.stopAccessingSecurityScopedResource() }
            folderAccess = access
            folder = url
            defaults.set(data, forKey: Self.bookmarkKey)
            selection = []
            path = []
        } catch {
            if access { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    func setSource(_ value: TagEditorSource) {
        guard !isWriting, source != value else { return }
        source = value
        defaults.set(value.rawValue, forKey: Self.sourceKey)
        refresh()
    }

    func refresh() {
        guard !isWriting, let folder else { return }
        scanTask?.cancel()
        let id = UUID()
        scanID = id
        let source = source
        isBusy = true
        progress = "Reading audio files…"
        files = []
        issues = []
        excludedCount = 0
        albumIDsByFile = [:]
        selection = []
        didCheckDuplicates = false
        scanTask = Task { [weak self, service] in
            do {
                let locations = source == .library ? try await service.libraryLocations() : nil
                try Task.checkCancellation()
                let result = try await service.scan(folder: folder, library: locations) { [weak self] count in
                    await self?.updateProgress("Read \(count) files…", id: id)
                }
                guard let self, self.scanID == id, !Task.isCancelled else { return }
                self.files = result.files
                self.indexAlbumIDs()
                self.issues = result.issues
                self.excludedCount = result.excludedLibraryItems
                self.isBusy = false
                self.focusSelection()
            } catch is CancellationError {
            } catch {
                guard let self, self.scanID == id else { return }
                self.isBusy = false
                self.errorMessage = source == .library
                    ? "Could not read the music library. You can switch to All Audio Files in Folder. \(error.localizedDescription)"
                    : error.localizedDescription
            }
        }
    }

    func cancelScan() {
        guard !isWriting else { return }
        scanTask?.cancel()
        scanID = UUID()
        isBusy = false
    }

    func findDuplicates() {
        guard !isBusy, let folder else { return }
        let id = UUID()
        scanID = id
        let files = files
        isBusy = true
        progress = "Checking identical files…"
        scanTask = Task { [weak self, service] in
            do {
                let duplicates = try await service.identicalFiles(files, folder: folder) { [weak self] count in
                    await self?.updateProgress("Compared \(count) files…", id: id)
                }
                guard let self, self.scanID == id, !Task.isCancelled else { return }
                self.issues.removeAll { $0.kind == .identicalFiles }
                self.issues += duplicates
                self.didCheckDuplicates = true
                self.isBusy = false
                self.section = .issues
                self.path = []
            } catch is CancellationError {
            } catch {
                guard let self, self.scanID == id else { return }
                self.isBusy = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func apply(_ edits: [TagFileEdit]) async -> Bool {
        guard !isBusy, let folder else { return false }
        isBusy = true
        isWriting = true
        var succeeded = false
        do {
            try await historyStore.apply(edits, folder: folder) { [weak self] text in
                await self?.updateWriteProgress(text)
            }
            succeeded = true
        } catch { errorMessage = error.localizedDescription }
        await reloadHistory()
        isWriting = false
        isBusy = false
        if source == .library {
            NotificationCenter.default.post(name: .musicTrackMetadataDidChange, object: nil)
        }
        refresh()
        return succeeded
    }

    func undo(_ operation: TagHistoryOperation) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        isWriting = true
        var succeeded = false
        do {
            try await historyStore.undo(operation) { [weak self] text in await self?.updateWriteProgress(text) }
            succeeded = true
        } catch { errorMessage = error.localizedDescription }
        await reloadHistory()
        isWriting = false
        isBusy = false
        if source == .library {
            NotificationCenter.default.post(name: .musicTrackMetadataDidChange, object: nil)
        }
        refresh()
        return succeeded
    }

    private func updateWriteProgress(_ value: String) { progress = value }
    private func updateProgress(_ value: String, id: UUID) { if scanID == id { progress = value } }
    private func reloadHistory() async {
        do { history = try await historyStore.operations() }
        catch { errorMessage = "Could not load edit history: \(error.localizedDescription)" }
    }

    func artists(in files: [TagFileSnapshot]) -> [TagEditorGroup] {
        var groups: [String: [TagFileSnapshot]] = [:]
        for file in files {
            for name in artistNames(file) { groups[name, default: []].append(file) }
        }
        return groups.map { name, files in
            TagEditorGroup(id: name, name: name, subtitle: "\(Set(files.map { albumIDsByFile[$0.id] ?? $0.albumID }).count) albums · \(files.count) tracks", files: files)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func albums(in files: [TagFileSnapshot]) -> [TagEditorGroup] {
        Dictionary(grouping: files, by: { albumIDsByFile[$0.id] ?? $0.albumID }).map { id, files in
            TagEditorGroup(id: id, name: files[0].album, subtitle: "\(id.components(separatedBy: "\u{0}").first ?? files[0].albumArtist) · \(files.count) tracks", files: files)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func artistNames(_ file: TagFileSnapshot) -> [String] {
        let values = file.values(.artist)
        if values.count > 1 { return Array(Set(values)).sorted() }
        if defaults.bool(forKey: PlayerSettingsKey.usesSmartArtistGrouping) {
            return CombinedArtistNameParser.names(from: file.artist, separatorCharacters: defaults.string(forKey: PlayerSettingsKey.smartArtistSeparatorCharacters) ?? SmartArtistGroupingSettings.defaultSeparatorCharacters)
        }
        return [file.artist]
    }

    private func indexAlbumIDs() {
        let credits = Dictionary(grouping: files, by: \.album).mapValues { Set($0.map(\.albumArtist)) }
        albumIDsByFile = Dictionary(uniqueKeysWithValues: files.map { file in
            let artist = file.text(.albumArtist).isEmpty
                ? AlbumArtistNameResolver.canonicalName(for: file.artist, among: credits[file.album] ?? [])
                : file.albumArtist
            return (file.id, artist + "\u{0}" + file.album)
        })
    }

    func files(on page: TagEditorPage) -> [TagFileSnapshot] {
        let scoped: [TagFileSnapshot]
        switch page {
        case .artist(let name): scoped = files.filter { artistNames($0).contains(name) }
        case .album(let id): scoped = files.filter { (albumIDsByFile[$0.id] ?? $0.albumID) == id }.sorted {
            let left = [Int($0.text(.disc).split(separator: "/").first ?? "") ?? 0, Int($0.text(.track).split(separator: "/").first ?? "") ?? 0]
            let right = [Int($1.text(.disc).split(separator: "/").first ?? "") ?? 0, Int($1.text(.track).split(separator: "/").first ?? "") ?? 0]
            return left == right ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : left.lexicographicallyPrecedes(right)
        }
        case .issue(let kind):
            let ids = issueFileIDs(kind)
            scoped = files.filter { ids.contains($0.id) }
        default: scoped = files
        }
        guard !searchText.isEmpty else { return scoped }
        return scoped.filter { [$0.title, $0.artist, $0.album, $0.url.path].contains { $0.localizedStandardContains(searchText) } }
    }

    func issueFileIDs(_ kind: TagIssueKind) -> Set<String> {
        issues.filter { $0.kind == kind }.reduce(into: Set<String>()) { $0.formUnion($1.fileIDs) }
    }

    private func focusSelection() {
        guard let focus = pendingFocus else { return }
        pendingFocus = nil
        searchText = ""
        section = .tracks
        path = []
        switch focus {
        case .song(let title, let artist, let album):
            let matches = files.filter { $0.text(.title) == title && $0.text(.artist) == artist && $0.text(.album) == album }
            selection = Set(matches.map(\.id))
            if matches.isEmpty { searchText = title }
        case .artist(let name): path = [.artist(name)]
        case .album(let title, let artist):
            if let match = albums(in: files).first(where: { $0.name == title && ($0.files[0].albumArtist == artist || $0.files.contains { artistNames($0).contains(artist) }) }) {
                path = [.album(match.id)]
            } else { searchText = title }
        }
    }
}
#endif
