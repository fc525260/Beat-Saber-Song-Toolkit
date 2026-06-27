# Beat Saber Song Toolkit

Beat Saber Song Toolkit is a Flutter/Dart toolbox for Beat Saber song download,
playlist sync, and local library management. It started as a BeatSpider rewrite
and now combines the main workflows from:

- WGzeyu/BeatSpider
- WGzeyu/Beat-Saber-Song-Folder-Manager
- fc525260/Beat-Saber-Playlist-File-Sync

Current version: `0.1.0`.

## Layout

- Root package: `beat_saber_song_toolkit`
- Flutter app: `apps\beat_saber_song_toolkit_app`
- CLI entrypoint: `bin\beat_saber_song_toolkit.dart`
- Final GUI/release checklist: `docs\FINAL_ACCEPTANCE_CHECKLIST_CN.md`
- Smoke scripts: `tool\README.md`
- Windows release output: `apps\beat_saber_song_toolkit_app\build\windows\x64\runner\Release\Beat Saber Song Toolkit.exe`

Real sample data, when present, is read-only:

```text
test\Beat Saber  songs
```

Scripts that need destructive checks copy data to system temp first.

## Safety Model

- Default development commands are offline: `dart analyze`, `dart test`, and
  `tool\toolbox_smoke.dart` do not contact BeatSaver.
- Live BeatSaver checks must be explicit through flags such as
  `--allow-network` or `--api-sample=N`.
- CLI download/install/search/import commands require `--allow-network`.
- CLI deletion requires `--yes-delete`.
- Real sample data under `test\Beat Saber  songs` is read-only; destructive
  smoke scripts copy the needed files to system temp first.
- Deleted-map handling for `LocalCache.saver` is report-only. The app exports
  candidates for manual review and does not automatically remove cache entries.

## GUI Workspaces

The Flutter app has three main workspaces:

- `找歌下载`: search BeatSaver and related sources, manage current/skip lists,
  download ZIPs, install maps, use local ZIP/song cache, and export playlists.
- `本地曲库`: scan installed songs, export `.bplist`, export favorites from
  `PlayerData.dat`, inspect SongCore, save/read/remove `folders.xml` entries,
  find duplicates, backup-delete duplicates, and apply path corrections.
- `歌单同步`: compare a `.bplist` with an installed library, show one-to-one
  installed/missing rows, export current rows, remove entries from playlists,
  backup-delete selected installed entries, and download/install missing songs.

The last selected workspace is saved in `%APPDATA%\BeatSaberSongToolkit`.

## LocalCache.saver

The old WGzeyu remote cache endpoints are currently unavailable, so the app no
longer depends on them. The `本地缓存` data-source tab can:

- read an existing `LocalCache.saver`;
- build a fresh BeatSaver snapshot through official `/maps/latest`;
- pause and resume full snapshot building;
- incrementally update an existing snapshot with `/maps/latest?after=...`;
- show snapshot age and last incremental update stats;
- audit BeatSaver `/maps/deleted` candidates without modifying the cache;
- export deleted-candidate reports as TSV after an audit.

Important safety rule: deleted-map handling is intentionally report-only. The
app does not automatically remove entries from `LocalCache.saver`.

The project-local cache used for current development and routine offline checks is:

```text
LocalCache.saver
```

The app settings on this machine point `localCacheSaverPath` to that file. Use
this project-local cache by default; timestamped backups are kept only for
recovery if a cache update fails or produces bad data.

Default tests and smoke commands must stay offline for `LocalCache.saver`.
Refreshing the cache is still supported, but it is an explicit maintenance
operation: use the GUI rebuild/resume/incremental buttons or
`tool\local_cache_update.dart` only when a cache update is intended. The update
tool creates a timestamped backup before modifying the selected cache.

## Toolchain

Preferred local commands on this machine:

```powershell
D:\Software\flutter\bin\dart.bat analyze
D:\Software\flutter\bin\dart.bat test
D:\Software\flutter\bin\dart.bat run tool\toolbox_smoke.dart
```

From the Flutter app directory:

```powershell
D:\Software\flutter\bin\flutter.bat analyze
D:\Software\flutter\bin\flutter.bat test test\widget_test.dart
D:\Software\flutter\bin\flutter.bat build windows --release
```

During normal local development, prefer the offline analyze/test/smoke commands.
Windows release builds and visible GUI checks are reserved for explicit release
validation or the final unified GUI pass.

The Windows release executable is:

```text
apps\beat_saber_song_toolkit_app\build\windows\x64\runner\Release\Beat Saber Song Toolkit.exe
```

Local release artifacts are not tracked in git. The `release\` directory only
documents where GitHub-built artifacts are expected from:

```text
release\
```

GitHub can build a Windows x64 package through the manual workflow:

```text
.github\workflows\windows-release.yml
```

Focused smoke scripts:

```powershell
D:\Software\flutter\bin\dart.bat run tool\local_cache_inspect.dart LocalCache.saver
D:\Software\flutter\bin\dart.bat run tool\local_cache_validate.dart --cache=LocalCache.saver
D:\Software\flutter\bin\dart.bat run tool\songcore_smoke.dart
D:\Software\flutter\bin\dart.bat run tool\playlist_sync_smoke.dart
```

Networked cache maintenance and missing-song checks are opt-in:

```powershell
D:\Software\flutter\bin\dart.bat run tool\local_cache_update.dart --cache=LocalCache.saver --allow-network
D:\Software\flutter\bin\dart.bat run tool\local_cache_snapshot_smoke.dart --allow-network
D:\Software\flutter\bin\dart.bat run tool\local_cache_snapshot_smoke.dart --allow-network --incremental --page-size=5
D:\Software\flutter\bin\dart.bat run tool\local_cache_snapshot_smoke.dart --allow-network --deleted-audit --page-size=2
D:\Software\flutter\bin\dart.bat run tool\local_cache_validate.dart --cache=LocalCache.saver --api-sample=10
D:\Software\flutter\bin\dart.bat run tool\playlist_sync_smoke.dart --allow-network --with-missing-download
D:\Software\flutter\bin\dart.bat run tool\playlist_sync_smoke.dart --allow-network --with-missing-install
```

Do not run these opt-in commands during routine regression unless a live
BeatSaver check or cache maintenance update is the intended task.

Before final release sign-off, use `docs\FINAL_ACCEPTANCE_CHECKLIST_CN.md`.
That checklist separates automated coverage from Windows release GUI checks and
external inputs such as GCP Vision keys or a project release API.

## CLI Examples

Run from the repository root:

Networked CLI operations refuse to run unless `--allow-network` is present.
Deleting an installed song directory refuses to run unless `--yes-delete` is
present. Local list/export operations stay offline by default.
Use `--help` or `-h` to print usage without running an operation.

```powershell
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --help
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --query "camellia" --allow-network
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --download-id 1520 --out downloads --allow-network
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --install-id 1520 --install-out songs --allow-network
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --batch-install camellia --limit 3 --install-out songs --allow-network
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --list-installed --install-out songs
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --delete-id 1520 --install-out songs --yes-delete
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --export-bplist playlists\songs.bplist --install-out songs
D:\Software\flutter\bin\dart.bat run bin\beat_saber_song_toolkit.dart --import-bplist playlists\songs.bplist --install-out songs --allow-network
```

## Configuration

On Windows, app settings and caches are stored under:

```text
%APPDATA%\BeatSaberSongToolkit
```

On first run, an old `%APPDATA%\BeatSpiderReborn\settings.json` may be imported
for compatibility if the new settings file does not exist.

## Current External Dependencies

These are intentionally not hardcoded:

- release update API URL;
- GCP Vision API key for cover-label filtering;
- original BeatSpider default playlist cover sample.

`泽宇缓存(兼容)` remains available as a compatibility download mode, but should
not be treated as the default reliable source in the current environment.

## Network Mirrors

For mainland China networks, set mirrors before dependency or build commands:

```powershell
$env:PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"
$env:FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
```
