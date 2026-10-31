#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct TagBatchEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: TagEditorModel
    let files: [TagFileSnapshot]
    let artistToRename: String?
    @AppStorage(PlayerSettingsKey.smartArtistSeparatorCharacters)
    private var separators = SmartArtistGroupingSettings.defaultSeparatorCharacters

    @State private var enabledFields: Set<TagField> = []
    @State private var values: [TagField: String] = [:]
    @State private var renamesArtist = false
    @State private var artistName = ""
    @State private var artworkAction = ArtworkAction.keep
    @State private var artworkData: Data?
    @State private var artworkMIMEType = "image/jpeg"
    @State private var showsImagePicker = false
    @State private var preview: [TagFileEdit]?
    @State private var confirmsApply = false
    @State private var errorMessage: String?

    private enum ArtworkAction: String, CaseIterable, Identifiable {
        case keep = "Keep Existing", replace = "Replace All Embedded Artwork", remove = "Remove All Embedded Artwork"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let preview {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            Text("Review every change below. Nothing has been written yet.").font(.headline)
                            Text("Original files are backed up for Undo in History. Backups are kept between app launches and require disk space.")
                                .foregroundStyle(.secondary)
                            ForEach(preview) { edit in
                                TagChangePreview(
                                    path: edit.original.url.path, title: edit.original.title,
                                    changes: edit.changes,
                                    changesArtwork: edit.artwork != nil,
                                    beforeArtwork: edit.original.artworkThumbnail,
                                    afterArtwork: edit.artwork.flatMap { $0.data }.flatMap(TagFileIO.thumbnail),
                                    beforeArtworkCount: edit.original.artworkCount,
                                    afterArtworkCount: edit.artwork?.data == nil ? 0 : 1
                                )
                            }
                        }.padding(20)
                    }
                } else {
                    form
                }
            }
            .navigationTitle(preview == nil ? "Edit \(files.count) Files" : "Review \(preview?.count ?? 0) Files")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction).disabled(model.isWriting)
                }
                if preview != nil {
                    ToolbarItem { Button("Back") { preview = nil }.disabled(model.isWriting) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if preview == nil {
                        Button("Review Changes…", action: review)
                            .disabled(enabledFields.isEmpty && !renamesArtist && artworkAction == .keep)
                    } else {
                        Button("Apply Changes…") { confirmsApply = true }.disabled(model.isBusy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.isWriting { ProgressView(model.progress).padding().frame(maxWidth: .infinity) }
            }
        }
        .frame(width: 700, height: 680)
        .interactiveDismissDisabled(model.isWriting)
        .confirmationDialog("Write changes to \(preview?.count ?? 0) files?", isPresented: $confirmsApply) {
            Button("Apply Reviewed Changes") {
                guard let preview else { return }
                Task { _ = await model.apply(preview); dismiss() }
            }
        } message: { Text("Only the changes shown in this preview will be applied. You can restore the originals from History.") }
        .fileImporter(isPresented: $showsImagePicker, allowedContentTypes: [.jpeg, .png]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let resource = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
                guard (resource.fileSize ?? Int.max) <= 25 * 1024 * 1024 else { throw TagEditorError.message("Choose a cover smaller than 25 MB.") }
                let data = try Data(contentsOf: url)
                guard TagFileIO.thumbnail(data) != nil else { throw TagEditorError.message("This image could not be read.") }
                artworkData = data
                artworkMIMEType = resource.contentType?.preferredMIMEType ?? "image/jpeg"
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Cannot Prepare Changes", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onAppear {
            for field in TagField.allCases {
                let distinct = Set(files.map { $0.values(field) })
                if distinct.count == 1 { values[field] = files[0].values(field).joined(separator: field.supportsMultipleValues ? "\n" : "") }
            }
            artistName = artistToRename ?? ""
        }
    }

    private var form: some View {
        Form {
            Section {
                Text("Enable only the fields you want to change. Enabled fields replace the value in every selected file; an empty value clears that field. Unchecked fields keep each file's existing values.")
                    .foregroundStyle(.secondary)
                Text(model.folder?.path ?? "").font(.caption).textSelection(.enabled)
            }
            if let artistToRename {
                Section("Artist Group") {
                    Toggle("Rename only “\(artistToRename)” in credits", isOn: $renamesArtist)
                    if renamesArtist {
                        TextField("New Artist Name", text: $artistName)
                        Text("Other credited artists and separate artist values are preserved.").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Tags") {
                ForEach(TagField.allCases) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(field.title, isOn: Binding(
                            get: { enabledFields.contains(field) },
                            set: { if $0 { enabledFields.insert(field) } else { enabledFields.remove(field) } }
                        ))
                        .disabled(field == .artist && renamesArtist)
                        TextField(
                            Set(files.map { $0.values(field) }).count > 1 ? "Multiple values — enter replacement" : "Empty clears this field",
                            text: Binding(get: { values[field] ?? "" }, set: { values[field] = $0 }), axis: .vertical
                        )
                        .lineLimit(1...4)
                        .disabled(!enabledFields.contains(field) || (field == .artist && renamesArtist))
                        if field.supportsMultipleValues && enabledFields.contains(field) {
                            Text("One value per line; punctuation inside a name is preserved.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Cover Art") {
                Picker("Artwork", selection: $artworkAction) {
                    ForEach(ArtworkAction.allCases) { Text($0.rawValue).tag($0) }
                }
                if artworkAction == .replace {
                    HStack {
                        TagCoverThumbnail(data: artworkData, size: 80)
                        Button("Choose Cover…") { showsImagePicker = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func review() {
        do {
            var fields = enabledFields
            if renamesArtist { fields.remove(.artist) }
            if artworkAction == .replace && artworkData == nil { throw TagEditorError.message("Choose a cover image first.") }
            let artwork: TagArtworkEdit? = switch artworkAction {
            case .keep: nil
            case .replace: TagArtworkEdit(data: artworkData, mimeType: artworkMIMEType)
            case .remove: TagArtworkEdit(data: nil, mimeType: "")
            }
            let edits = try TagEditPlan.make(
                files: files,
                replacements: Dictionary(uniqueKeysWithValues: fields.map { ($0, $0.values(from: values[$0] ?? "")) }),
                artistRename: renamesArtist ? artistToRename.map { TagArtistRename(name: $0, replacement: artistName, separators: separators) } : nil,
                artwork: artwork
            )
            guard !edits.isEmpty else { throw TagEditorError.message("The selected values already match these files.") }
            try TagFileIO.validate(edits)
            preview = edits
        } catch { errorMessage = error.localizedDescription }
    }
}

struct TagChangePreview: View {
    let path: String
    let title: String
    let changes: [TagPropertyChange]
    let changesArtwork: Bool
    let beforeArtwork: Data?
    let afterArtwork: Data?
    let beforeArtworkCount: Int
    let afterArtworkCount: Int

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                HStack { Text("Before").frame(maxWidth: .infinity, alignment: .leading); Text("After").frame(maxWidth: .infinity, alignment: .leading) }
                    .font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(change.field.title).font(.caption.bold())
                        HStack(alignment: .top) {
                            Text(display(change.before)).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                            Text(display(change.after)).frame(maxWidth: .infinity, alignment: .leading)
                        }.textSelection(.enabled)
                    }
                }
                if changesArtwork {
                    Text("Embedded Artwork").font(.caption.bold())
                    HStack {
                        VStack { TagCoverThumbnail(data: beforeArtwork, size: 80); Text("\(beforeArtworkCount) images") }.frame(maxWidth: .infinity)
                        Image(systemName: "arrow.right")
                        VStack { TagCoverThumbnail(data: afterArtwork, size: 80); Text("\(afterArtworkCount) images") }.frame(maxWidth: .infinity)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }
    }

    private func display(_ values: [String]) -> String { values.isEmpty ? "(empty)" : values.joined(separator: "\n") }
}

struct TagEditorHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: TagEditorModel
    @State private var reviewed: TagHistoryOperation?
    @State private var confirmsUndo = false

    var body: some View {
        NavigationStack {
            Group {
                if let reviewed {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            Text("Restore the original files from this operation. Files changed by a later operation or another application will not be overwritten.")
                            if reviewed.requiresRecovery { Text("This operation was interrupted. Files already restored will be skipped.").foregroundStyle(.secondary) }
                            ForEach(reviewed.files) { file in
                                TagChangePreview(
                                    path: file.url.path, title: file.before.title, changes: file.changes.map(\.reversed),
                                    changesArtwork: file.changesArtwork,
                                    beforeArtwork: file.after.artworkThumbnail, afterArtwork: file.before.artworkThumbnail,
                                    beforeArtworkCount: file.after.artworkCount, afterArtworkCount: file.before.artworkCount
                                )
                            }
                        }.padding(20)
                    }
                } else {
                    List(model.history) { operation in
                        Button { reviewed = operation } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(operation.date.formatted(date: .abbreviated, time: .shortened))
                                    Text("\(operation.files.count) files · \(operation.requiresRecovery ? "Recovery required" : "Applied")").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Review Undo…")
                            }
                        }.buttonStyle(.plain)
                    }
                    .overlay { if model.history.isEmpty { ContentUnavailableView("No Applied Edits", systemImage: "clock.arrow.circlepath") } }
                }
            }
            .navigationTitle(reviewed == nil ? "Edit History" : "Review Undo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", action: dismiss.callAsFunction).disabled(model.isWriting) }
                if reviewed != nil {
                    ToolbarItem { Button("Back") { reviewed = nil }.disabled(model.isWriting) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Restore Originals…") { confirmsUndo = true }.disabled(model.isBusy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.isWriting { ProgressView(model.progress).padding() }
            }
        }
        .frame(width: 700, height: 640)
        .interactiveDismissDisabled(model.isWriting)
        .confirmationDialog("Restore these \(reviewed?.files.count ?? 0) original files?", isPresented: $confirmsUndo) {
            Button("Restore Reviewed Files") {
                guard let reviewed else { return }
                Task { _ = await model.undo(reviewed); dismiss() }
            }
        }
    }
}
#endif
