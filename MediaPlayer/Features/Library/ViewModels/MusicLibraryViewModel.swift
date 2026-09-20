//
//  MusicLibraryViewModel.swift
//  MediaPlayer
//
//

import Combine
import Foundation
import MusicKit
import OSLog

@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published private(set) var authorizationStatus = MusicAuthorization.currentStatus
    @Published private(set) var songs: [Song] = []
    @Published private(set) var filteredSongs: [Song] = []
    @Published private(set) var filteredArtists: [LibraryArtist] = []
    @Published private(set) var filteredAlbums: [LibraryAlbum] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var filteredPlaylists: [Playlist] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            refreshFilteredContent(debounce: true)
        }
    }
    @Published var sortOption: MusicLibrarySortOption {
        didSet {
            defaults.set(
                sortOption.rawValue,
                forKey: PlayerSettingsKey.librarySortOption
            )
            refreshFilteredContent()
        }
    }
    @Published var section: MusicLibrarySection {
        didSet {
            defaults.set(
                section.rawValue,
                forKey: PlayerSettingsKey.librarySection
            )
        }
    }

    private let service: any MusicLibraryLoading
    private let defaults: UserDefaults
    private var songsBySortOption: [MusicLibrarySortOption: [Song]] = [:]
    private var artists: [LibraryArtist] = []
    private var albums: [LibraryAlbum] = []
    private var filteringTask: Task<Void, Never>?
    private var groupingTask: Task<Void, Never>?
    private var hasLoadedLibrary = false
    private var smartArtistSeparatorCharacters =
        SmartArtistGroupingSettings.defaultSeparatorCharacters
    private var usesSmartArtistGrouping = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PlayerApp",
        category: "MusicLibrary"
    )

    init(
        service: any MusicLibraryLoading = MusicKitLibraryService(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.defaults = defaults
        sortOption = defaults.string(forKey: PlayerSettingsKey.librarySortOption)
            .flatMap(MusicLibrarySortOption.init(rawValue:))
            ?? .title
        section = defaults.string(forKey: PlayerSettingsKey.librarySection)
            .flatMap(MusicLibrarySection.init(rawValue:))
            ?? .songs
    }

    var sortedSongs: [Song] {
        songsBySortOption[sortOption] ?? []
    }

    var isEmpty: Bool {
        songs.isEmpty && playlists.isEmpty
    }

    func artist(containing song: Song) -> LibraryArtist? {
        if usesSmartArtistGrouping {
            let preferredArtistNames = MusicLibraryGrouping.artistNames(
                for: song,
                usesSmartArtistGrouping: true,
                artistSeparatorCharacters: smartArtistSeparatorCharacters
            )

            for artistName in preferredArtistNames {
                if let artist = artists.first(where: { $0.name == artistName }) {
                    return artist
                }
            }
        }

        return artists.first { artist in
            artist.songs.contains(where: { $0.id == song.id })
        }
    }

    func album(containing song: Song) -> LibraryAlbum? {
        albums.first { album in
            album.songs.contains(where: { $0.id == song.id })
        }
    }

    func artist(id: LibraryArtist.ID) -> LibraryArtist? {
        artists.first(where: { $0.id == id })
    }

    func album(id: LibraryAlbum.ID) -> LibraryAlbum? {
        albums.first(where: { $0.id == id })
    }

    func configureSmartArtistGrouping(
        isEnabled: Bool,
        separatorCharacters: String
    ) {
        let normalizedSeparatorCharacters =
            SmartArtistGroupingSettings
            .normalizedSeparatorCharacters(separatorCharacters)
        let wasEnabled = usesSmartArtistGrouping
        let separatorsChanged = smartArtistSeparatorCharacters
            != normalizedSeparatorCharacters

        guard wasEnabled != isEnabled || separatorsChanged else {
            return
        }

        usesSmartArtistGrouping = isEnabled
        smartArtistSeparatorCharacters = normalizedSeparatorCharacters
        guard hasLoadedLibrary else {
            return
        }

        guard wasEnabled != isEnabled || isEnabled else {
            return
        }

        groupingTask?.cancel()
        let songs = songs
        let playlists = playlists

        groupingTask = Task { [weak self] in
            let content = await Task.detached(priority: .userInitiated) {
                MusicLibraryContent.build(
                    from: songs,
                    usesSmartArtistGrouping: isEnabled,
                    artistSeparatorCharacters: normalizedSeparatorCharacters
                )
            }.value

            guard !Task.isCancelled else {
                return
            }

            self?.apply(content, songs: songs, playlists: playlists)
        }
    }

    private func refreshFilteredContent(debounce: Bool = false) {
        filteringTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            filteredSongs = sortedSongs
            filteredArtists = artists
            filteredAlbums = albums
            filteredPlaylists = playlists
            return
        }

        let songs = sortedSongs
        let artists = artists
        let albums = albums
        let playlists = playlists

        filteringTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            guard !Task.isCancelled else {
                return
            }

            let filteredContent = await Task.detached(priority: .userInitiated) {
                MusicLibraryFiltering.filteredContent(
                    query: query,
                    songs: songs,
                    artists: artists,
                    albums: albums,
                    playlists: playlists
                )
            }.value

            guard !Task.isCancelled else {
                return
            }

            self?.applyFilteredContent(filteredContent)
        }
    }

    func loadIfAuthorized() async {
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .authorized else {
            return
        }

        guard !hasLoadedLibrary else {
            return
        }

        await loadLibrary()
    }

    func requestAuthorization() async {
        authorizationStatus = await MusicAuthorization.request()
        guard authorizationStatus == .authorized else {
            return
        }

        await loadLibrary()
    }

    func loadLibrary() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            async let loadedSongs = service.fetchSongs()
            async let loadedPlaylists = service.fetchPlaylists()

            let (songs, playlists) = try await (loadedSongs, loadedPlaylists)
            var groupingPreference = usesSmartArtistGrouping
            var separatorPreference = smartArtistSeparatorCharacters
            var content = await buildLibraryContent(
                from: songs,
                usesSmartArtistGrouping: groupingPreference,
                artistSeparatorCharacters: separatorPreference
            )

            while groupingPreference != usesSmartArtistGrouping
                || separatorPreference != smartArtistSeparatorCharacters {
                groupingPreference = usesSmartArtistGrouping
                separatorPreference = smartArtistSeparatorCharacters
                content = await buildLibraryContent(
                    from: songs,
                    usesSmartArtistGrouping: groupingPreference,
                    artistSeparatorCharacters: separatorPreference
                )
            }

            apply(content, songs: songs, playlists: playlists)
            hasLoadedLibrary = true
        } catch {
            report("Could not load your music library.", error: error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func report(_ message: String, error: Error) {
        logger.error("\(message, privacy: .public) \(error.localizedDescription, privacy: .public)")
        errorMessage = message
    }

    private func apply(
        _ content: MusicLibraryContent,
        songs: [Song],
        playlists: [Playlist]
    ) {
        self.songs = songs
        self.playlists = playlists
        songsBySortOption = content.songsBySortOption
        artists = content.artists
        albums = content.albums
        refreshFilteredContent()
    }

    private func applyFilteredContent(_ content: MusicLibraryFilteredContent) {
        filteredSongs = content.songs
        filteredArtists = content.artists
        filteredAlbums = content.albums
        filteredPlaylists = content.playlists
    }

    private func buildLibraryContent(
        from songs: [Song],
        usesSmartArtistGrouping: Bool,
        artistSeparatorCharacters: String
    ) async -> MusicLibraryContent {
        await Task.detached(priority: .userInitiated) {
            MusicLibraryContent.build(
                from: songs,
                usesSmartArtistGrouping: usesSmartArtistGrouping,
                artistSeparatorCharacters: artistSeparatorCharacters
            )
        }.value
    }
}
