#if os(macOS)
import MusicKit
import SwiftUI
import UniformTypeIdentifiers

struct TrackMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let song: Song
    let onSaved: () -> Void

    @State private var selectedURL: URL?
    @State private var original: EditableTrackMetadata?
    @State private var edited = EditableTrackMetadata.empty
    @State private var isImporting = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Reading audio file…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if original == nil {
                    ContentUnavailableView {
                        Label("Choose the Track's Audio File", systemImage: "music.note")
                    } description: {
                        Text("MusicKit does not provide the file location. Choose the original local file; Trackfold will verify its tags before editing.")
                    } actions: {
                        Button("Choose File…") { isImporting = true }
                    }
                } else {
                    Form {
                        Section("File") {
                            Text(selectedURL?.path ?? "")
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
                            Button("Choose Another File…") { isImporting = true }
                        }
                        Section("Track") {
                            TextField("Title", text: $edited.title)
                            TextField("Artist", text: $edited.artist)
                            if edited.artistValues.count > 1 {
                                Text("This file stores multiple artist values. Separate them with semicolons.")
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Album", text: $edited.album)
                            TextField("Album Artist", text: $edited.albumArtist)
                            TextField("Composer", text: $edited.composer)
                            TextField("Genre", text: $edited.genre)
                        }
                        Section("Position") {
                            TextField("Track Number", value: $edited.trackNumber, format: .number)
                            TextField("Disc Number", value: $edited.discNumber, format: .number)
                        }
                        Section {
                            Text("Changes are written to this audio file, not to Music's library database. Music may need to refresh or reimport the file to show new tags.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Track Tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction).disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isLoading || isSaving || original.map { edited == $0 } != false)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 440)
        .interactiveDismissDisabled(isSaving)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await load(url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Could Not Edit File", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load(_ url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let metadata = try await AudioFileMetadataService().load(at: url, matching: SongFileIdentity(song: song))
            selectedURL = url
            original = metadata
            edited = metadata
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let original else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await AudioFileMetadataService().save(edited, replacing: original)
            NotificationCenter.default.post(name: .musicTrackMetadataDidChange, object: nil)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
