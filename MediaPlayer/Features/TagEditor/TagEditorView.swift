#if os(macOS)
import AppKit
import SwiftUI

struct TagEditorView: View {
    @ObservedObject var model: TagEditorModel
    @State private var editingFiles: [TagFileSnapshot] = []
    @State private var editingArtist: String?
    @State private var showsEditor = false
    @State private var showsHistory = false

    var body: some View {
        VStack(spacing: 0) {
            sourceBar
            Divider()
            NavigationSplitView {
                List(selection: Binding<TagEditorPage?>(get: { model.section }, set: {
                    if let value = $0 { model.section = value; model.path = []; model.selection = [] }
                })) {
                    Label("Tracks", systemImage: "music.note.list").tag(TagEditorPage.tracks)
                    Label("Artists", systemImage: "music.mic").tag(TagEditorPage.artists)
                    Label("Albums", systemImage: "square.stack").tag(TagEditorPage.albums)
                    Label("Problems", systemImage: "exclamationmark.magnifyingglass").tag(TagEditorPage.issues)
                }
                .navigationSplitViewColumnWidth(min: 140, ideal: 175)
            } detail: {
                NavigationStack(path: Binding(get: { model.path }, set: { model.path = $0; model.selection = [] })) {
                    page(model.section)
                        .navigationDestination(for: TagEditorPage.self) { page($0) }
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 800, minHeight: 560)
        .toolbar {
            ToolbarItemGroup {
                Button("Refresh", systemImage: "arrow.clockwise", action: model.refresh)
                    .disabled(model.isBusy || model.folder == nil)
                Button("Find Problems", systemImage: "exclamationmark.magnifyingglass", action: model.findDuplicates)
                    .disabled(model.isBusy || model.files.isEmpty)
                Button("History", systemImage: "clock.arrow.circlepath") { showsHistory = true }
                    .disabled(model.isBusy)
                Button("Edit Selected…", systemImage: "pencil") { edit(model.selectedFiles) }
                    .disabled(model.isBusy || model.selectedFiles.isEmpty)
            }
        }
        .task { await model.start() }
        .sheet(isPresented: $showsEditor) {
            TagBatchEditorView(model: model, files: editingFiles, artistToRename: editingArtist)
        }
        .sheet(isPresented: $showsHistory) { TagEditorHistoryView(model: model) }
        .alert("Tag Editor", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var sourceBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                Text(model.folder?.path ?? "Choose the folder containing your music")
                    .lineLimit(2).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Button(model.folder == nil ? "Choose Folder…" : "Change Folder…", action: model.chooseFolder)
                    .disabled(model.isBusy)
            }
            HStack {
                Picker("Show", selection: Binding(get: { model.source }, set: model.setSource)) {
                    ForEach(TagEditorSource.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(model.isBusy)
                MacLibrarySearchField(text: $model.searchText, prompt: "Title, artist, album or file", accessibilityLabel: "Search audio files")
                    .frame(width: 230)
            }
            if model.source == .library {
                Text("Local library files inside this folder. \(model.excludedCount) unavailable or outside the folder.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Reads audio files in this folder and its subfolders. The music library is not accessed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            if model.isBusy {
                ProgressView().controlSize(.small)
                Text(model.progress)
                if !model.isWriting { Button("Stop", action: model.cancelScan) }
            } else {
                Text("\(model.files.count) files · \(model.selection.count) selected")
            }
            Spacer()
            if model.history.contains(where: \.requiresRecovery) {
                Button("Interrupted edit — open History") { showsHistory = true }
            }
        }
        .font(.caption).padding(10)
    }

    @ViewBuilder
    private func page(_ page: TagEditorPage) -> some View {
        Group {
            if model.folder == nil {
                ContentUnavailableView {
                    Label("Choose Your Music Folder", systemImage: "folder")
                } description: {
                    Text("Select the directory to start browsing and editing tags.")
                } actions: { Button("Choose Folder…", action: model.chooseFolder) }
            } else {
                switch page {
                case .artists: groupList(model.artists(in: model.files(on: page)), artists: true)
                case .albums: groupList(model.albums(in: model.files(on: page)), artists: false)
                case .artist:
                    VStack(spacing: 0) {
                        HStack {
                            Text("Albums").font(.headline)
                            Spacer()
                            Button("Edit All Shown Artist Tracks…") { edit(model.files(on: page)) }.disabled(model.isBusy)
                        }.padding(12)
                        groupList(model.albums(in: model.files(on: page)), artists: false)
                        Divider()
                        trackList(model.files(on: page))
                    }
                case .issues: issuesList
                case .issue(let kind):
                    VStack(spacing: 0) {
                        if kind == .possibleDuplicates {
                            Text("These tracks have similar tags and durations. They may be different recordings; nothing is deleted automatically.")
                                .font(.callout).foregroundStyle(.secondary).padding()
                        }
                        if kind == .unreadable {
                            List(model.issues.filter { $0.kind == .unreadable }) { issue in
                                VStack(alignment: .leading) {
                                    Text(issue.fileIDs.sorted().joined(separator: "\n")).textSelection(.enabled)
                                    Text(issue.detail).foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            if kind == .identicalFiles || kind == .possibleDuplicates {
                                List(model.issues.filter { $0.kind == kind }) { issue in
                                    Button {
                                        model.selection = issue.fileIDs
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(issue.detail)
                                            Text(issue.fileIDs.sorted().joined(separator: "\n")).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }.buttonStyle(.plain)
                                }.frame(maxHeight: 170)
                                Divider()
                            }
                            trackList(model.files(on: page))
                        }
                    }
                default: trackList(model.files(on: page))
                }
            }
        }
        .navigationTitle(page.title)
    }

    private func groupList(_ groups: [TagEditorGroup], artists: Bool) -> some View {
        List(groups) { group in
            NavigationLink(value: artists ? TagEditorPage.artist(group.id) : .album(group.id)) {
                HStack(spacing: 12) {
                    TagCoverThumbnail(data: group.files.first?.artworkThumbnail)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name).font(.headline)
                        Text(group.subtitle).foregroundStyle(.secondary)
                    }
                }
            }
            .contextMenu {
                Button("Edit All Tracks…") { edit(group.files, artist: artists ? group.name : nil) }.disabled(model.isBusy)
            }
        }
        .overlay { if groups.isEmpty && !model.isBusy { ContentUnavailableView("No Files Found", systemImage: "music.note") } }
    }

    private func trackList(_ files: [TagFileSnapshot]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button("Select All") { model.selection = Set(files.map(\.id)) }
                Button("Edit All Shown…") { edit(files) }.disabled(files.isEmpty || model.isBusy)
                Spacer()
                Text("\(files.count) tracks").foregroundStyle(.secondary)
            }.padding(10)
            List(selection: $model.selection) {
                ForEach(files) { file in
                    HStack(spacing: 12) {
                        TagCoverThumbnail(data: file.artworkThumbnail)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.title).font(.headline)
                            Text("\(file.artist) · \(file.album)").foregroundStyle(.secondary)
                            Text(file.url.path).font(.caption).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(file.text(.track)).foregroundStyle(.secondary)
                        Text(file.duration.map { TrackDurationFormatter.string(from: $0) } ?? "—").monospacedDigit()
                    }
                    .tag(file.id)
                    .contextMenu {
                        Button("Edit Tags…") { edit(model.selection.contains(file.id) ? model.selectedFiles : [file]) }.disabled(model.isBusy)
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                    }
                }
            }
            .overlay { if files.isEmpty && !model.isBusy { ContentUnavailableView("No Files Found", systemImage: "music.note") } }
        }
    }

    private var issuesList: some View {
        List {
            Section {
                Text("Checks run on file tags. Missing embedded artwork means the file itself has no cover, even if Music displays one.")
                Text(model.didCheckDuplicates ? "Identical-file comparison complete." : "Choose Find Problems to compare file contents for identical copies.")
            }.foregroundStyle(.secondary)
            ForEach(TagIssueKind.allCases) { kind in
                NavigationLink(value: TagEditorPage.issue(kind)) {
                    HStack { Text(kind.title); Spacer(); Text("\(model.issueFileIDs(kind).count)").foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var currentArtist: String? {
        if case .artist(let name) = model.currentPage { return name }
        return nil
    }

    private func edit(_ files: [TagFileSnapshot], artist: String? = nil) {
        guard !files.isEmpty, !model.isBusy else { return }
        editingFiles = files
        editingArtist = artist ?? currentArtist
        showsEditor = true
    }
}

struct TagCoverThumbnail: View {
    let data: Data?
    var size: CGFloat = 44
    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else { Image(systemName: "music.note").frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary) }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
#endif
