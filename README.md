# Trackfold

Cross-platform SwiftUI music player for iOS and macOS. The current MVP reads tracks from the user's Music library and plays them through MusicKit.

## macOS tag editor

Open **Tag Editor** from the library toolbar, the File menu (Shift–Command–E), or an artist, album or track's Edit button. The editor reads and writes local audio files directly with TagLib; it does not automate the Music app.

- On first launch it looks for the Music media folder and standard music directories. If none is accessible and contains audio, it asks for a folder. The current directory is always visible, changeable and saved with a security-scoped bookmark.
- **Music Library Files** uses iTunesLibrary's exact local file URLs and includes only files inside the chosen folder. Cloud-only, protected and out-of-folder tracks are excluded. **All Audio Files in Folder** recursively scans the directory without querying the music library.
- Browse tracks, artists and albums, search by tags or path, and select multiple tracks using the standard macOS list selection. Edit an entire album or artist from its context menu. Only explicitly enabled fields change; empty enabled values clear a tag. Multi-value artist, album-artist, composer and genre tags use one value per line. Artist-group renaming preserves other credited artists.
- Basic checks run after each scan: missing embedded artwork, missing title/artist/album, missing track numbers, whitespace, inconsistent album artists and possible duplicates with matching tags and similar durations. **Find Problems** additionally hashes same-sized files to find byte-identical copies. Candidates are not proof of identical recordings. No music files are deleted automatically.
- Every edit, including a cover replacement/removal, shows a per-file before/after preview and requires a separate confirmation. The whole batch is prepared and validated on private copies before any source file is replaced. Unsupported or lossy tag conversions stop the operation.
- **History** previews and confirms restoring the exact original file bytes. Backups and an operation journal survive app restarts; interrupted writes can be recovered there. Undo refuses to overwrite later edits, so undo overlapping operations newest-first. Full-file backups use disk space and are retained while the operation is applied; successful Undo removes its private backups. Keep independent backups of important music as well.

The regular player's MusicKit catalog may cache old metadata after a file edit; the tag editor itself refreshes directly from disk. Embedded-cover checks intentionally ignore artwork cached only in Music.

Tag-editor regression coverage is in `MediaPlayerTests/TagEditorTests.swift`, including pure batch planning, issue detection, byte-exact Undo and refusal to overwrite externally modified files.
