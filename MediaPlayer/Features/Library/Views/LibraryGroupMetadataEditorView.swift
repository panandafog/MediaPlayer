#if os(macOS)
import MusicKit
import SwiftUI
import UniformTypeIdentifiers

enum LibraryGroupEditTarget {
    case artist(LibraryArtist)
    case album(LibraryAlbum)

    var songs: [Song] {
        let allSongs: [Song] = switch self {
        case .artist(let artist): artist.songs
        case .album(let album): album.songs
        }
        var seen: Set<MusicItemID> = []
        return allSongs.filter { seen.insert($0.id).inserted }
    }

    var name: String {
        switch self {
        case .artist(let artist): artist.name
        case .album(let album): album.title
        }
    }

    var isAlbum: Bool {
        if case .album = self { return true }
        return false
    }
}

private nonisolated enum LibraryGroupEditError: LocalizedError {
    case unsupportedCredit(String)
    case unsupportedAlbum

    var errorDescription: String? {
        switch self {
        case .unsupportedCredit(let title):
            "The artist name could not be located safely in the credits of “\(title)”. No changes were made."
        case .unsupportedAlbum:
            "The selected files do not have one consistent album title. No changes were made."
        }
    }
}

struct LibraryGroupMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlayerSettingsKey.smartArtistSeparatorCharacters)
    private var separatorCharacters = SmartArtistGroupingSettings.defaultSeparatorCharacters

    let target: LibraryGroupEditTarget
    let onSaved: () -> Void

    @State private var originals: [EditableTrackMetadata] = []
    @State private var selectedFolder: URL?
    @State private var isImporting = false
    @State private var proposedName = ""
    @State private var changesAlbumArtist = false
    @State private var proposedAlbumArtist = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isSaveBlocked = false
    @State private var completedCount = 0
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var showsConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Matching audio files…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if originals.isEmpty {
                    ContentUnavailableView {
                        Label("Choose an Audio Folder", systemImage: "folder")
                    } description: {
                        Text("Select a folder containing every track in this \(target.isAlbum ? "album" : "artist group"). Trackfold will match all files before changing any tags.")
                    } actions: {
                        Button("Choose Folder…") { isImporting = true }
                    }
                } else {
                    form
                }
            }
            .navigationTitle(target.isAlbum ? "Edit Album" : "Edit Artist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { showsConfirmation = true }
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 360)
        .interactiveDismissDisabled(isSaving)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let folder = urls.first else { return }
                Task { await loadTracks(in: folder) }
            case .failure(let error):
                loadError = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Update tags in \(originals.count) audio files?",
            isPresented: $showsConfirmation
        ) {
            Button("Update \(originals.count) Tracks") {
                Task { await save() }
            }
        } message: {
            Text("This writes tags directly to the matched files. Music may need to refresh or reimport them to display the changes.")
        }
        .alert(
            "Could Not Edit Files",
            isPresented: Binding(
                get: { saveError != nil || loadError != nil },
                set: { if !$0 { saveError = nil; loadError = nil } }
            )
        ) {
            Button("OK") { saveError = nil; loadError = nil }
        } message: {
            Text(saveError ?? loadError ?? "")
        }
    }

    private var form: some View {
        Form {
            Section(target.isAlbum ? "Album" : "Artist") {
                LabeledContent("Folder", value: selectedFolder?.path ?? "")
                Button("Choose Another Folder…") { isImporting = true }
                TextField(target.isAlbum ? "Album Title" : "Artist Name", text: $proposedName)
                if target.isAlbum {
                    Toggle("Change Album Artist", isOn: $changesAlbumArtist)
                    if changesAlbumArtist {
                        TextField("Album Artist", text: $proposedAlbumArtist)
                    }
                }
            }

            Section {
                Text("Only these \(originals.count) matched audio files will be updated. Music's library database is not edited directly.")
                    .foregroundStyle(.secondary)
                if !target.isAlbum {
                    Text("Collaborations keep their other credited artists and separators.")
                        .foregroundStyle(.secondary)
                }
            }

            if isSaving {
                Section {
                    ProgressView("Updating tracks… \(completedCount) of \(originals.count)")
                }
            }
        }
        .disabled(isSaving)
    }

    private var canSave: Bool {
        guard !isLoading, !isSaving, !isSaveBlocked, loadError == nil,
              !originals.isEmpty,
              !proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if target.isAlbum, changesAlbumArtist,
           proposedAlbumArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return proposedName != target.name
            || (target.isAlbum && changesAlbumArtist && originals.contains {
                $0.albumArtist != proposedAlbumArtist
            })
    }

    private func loadTracks(in folder: URL) async {
        isLoading = true
        defer { isLoading = false }
        originals = []
        selectedFolder = nil
        loadError = nil
        let songs = target.songs
        guard !songs.isEmpty,
              target.name != "Unknown Artist",
              target.name != "Unknown Album" else {
            loadError = "This group has no editable artist or album name."
            return
        }

        do {
            let loaded = try await AudioFileMetadataService().match(songs.map { SongFileIdentity(song: $0) }, in: folder)
            for (song, metadata) in zip(songs, loaded) {
                try validate(metadata, for: song)
            }
            originals = loaded
            selectedFolder = folder
            proposedName = target.name
            let albumArtists = Set(loaded.map(\.albumArtist))
            proposedAlbumArtist = albumArtists.count == 1 ? loaded[0].albumArtist : ""
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func validate(_ metadata: EditableTrackMetadata, for song: Song) throws {
        switch target {
        case .artist(let artist):
            guard ArtistCreditRewriter.replacing(
                artist.name,
                in: metadata.artist,
                with: artist.name,
                separatorCharacters: separatorCharacters
            ) != nil else {
                throw LibraryGroupEditError.unsupportedCredit(song.title)
            }
        case .album(let album):
            guard metadata.album == album.title else {
                throw LibraryGroupEditError.unsupportedAlbum
            }
        }
    }

    private func save() async {
        guard canSave else { return }
        guard let selectedFolder else { return }
        let service = AudioFileMetadataService()
        var changes: [(original: EditableTrackMetadata, edited: EditableTrackMetadata)] = []
        for original in originals {
            var edited = original
            switch target {
            case .artist(let artist):
                guard let credit = ArtistCreditRewriter.replacing(
                    artist.name,
                    in: original.artist,
                    with: proposedName,
                    separatorCharacters: separatorCharacters
                ) else {
                    saveError = LibraryGroupEditError.unsupportedCredit(original.title).localizedDescription
                    return
                }
                edited.artist = credit
            case .album:
                edited.album = proposedName
                if changesAlbumArtist {
                    edited.albumArtist = proposedAlbumArtist
                }
            }
            if edited != original {
                changes.append((original, edited))
            }
        }
        guard !changes.isEmpty else { return }

        isSaving = true
        completedCount = 0
        var applied: [(original: EditableTrackMetadata, edited: EditableTrackMetadata)] = []
        do {
            for change in changes {
                try await service.save(change.edited, replacing: change.original, accessThrough: selectedFolder)
                applied.append(change)
                completedCount += 1
            }
            NotificationCenter.default.post(name: .musicTrackMetadataDidChange, object: nil)
            onSaved()
            dismiss()
        } catch {
            var rollbackFailed = false
            for change in applied.reversed() {
                do {
                    try await service.save(change.original, replacing: change.edited, accessThrough: selectedFolder)
                } catch {
                    rollbackFailed = true
                }
            }
            NotificationCenter.default.post(name: .musicTrackMetadataDidChange, object: nil)
            isSaveBlocked = true
            saveError = rollbackFailed
                ? "The update stopped, and some tracks could not be restored. Reopen the group to review its tracks. \(error.localizedDescription)"
                : "The update stopped. Previously updated tracks were restored, but the failing track may have changed. Reopen the group before retrying. \(error.localizedDescription)"
        }
        isSaving = false
    }
}
#endif
