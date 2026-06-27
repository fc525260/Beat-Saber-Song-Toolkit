# Smoke Scripts

Run these commands from the repository root:

```powershell
D:\Software\flutter\bin\dart.bat run tool\toolbox_smoke.dart
```

## Safety Rules

- Default smoke commands are offline and do not contact BeatSaver.
- Real sample scripts read `test\Beat Saber  songs` only; any rename, delete,
  install, export, or playlist mutation is performed on system-temp copies.
- Scripts that contact BeatSaver require `--allow-network`.
- `tool\local_cache_validate.dart` stays offline unless `--api-sample=N` is
  provided for an explicit live API spot check.
- `tool\local_cache_update.dart` modifies the selected `LocalCache.saver` only
  after `--allow-network` is provided and a timestamped backup is created.
- Routine checks should use the project-local `LocalCache.saver` offline. Do
  not run update/rebuild/incremental/deleted-audit tools unless cache
  maintenance is the intended task.

## Primary Entrypoints

- `tool\final_acceptance_preflight.dart`: final offline preflight before manual release acceptance. It checks for leftover release processes, runs documentation/tool help tests, root `dart analyze`, and the release manual-acceptance launcher smoke, then verifies no release process remains.
- `tool\toolbox_smoke.dart`: full toolbox smoke. Runs SongCore, real-sample local-library, and playlist-sync smoke chains. Use after shared core changes.
- `tool\songcore_smoke.dart`: SongCore game/Mod detection, `folders.xml` lifecycle, and XML boundary smoke. It uses only temporary Beat Saber-shaped directories.
- `tool\real_sample_library_smoke.dart`: local-library smoke against the real sample root. It reads the sample directory only and writes exports/copies to system temp.
- `tool\playlist_sync_smoke.dart`: playlist-sync smoke against the real sample root. It reads the sample directory only and performs destructive operations on temp copies. Add `--allow-network --with-missing-download` to also download one missing ZIP from Fitness and Tech into system temp; add `--allow-network --with-missing-install` to install one missing song from each pack into a temp `CustomLevels` folder.

## Focused Entrypoints

- `tool\real_sample_audit.dart`: read-only summary of the real sample root. Pass the sample root as an optional positional path. Use `--missing`, `--missing-limit=N`, `--anomalies`, `--path-corrections`, or `--path-correction-limit=N` for deeper diagnostics.
- `tool\playlist_sync_operation_smoke.dart`: temp-copy playlist-only removal and backup-delete, including playlist entry count consistency checks.
- `tool\playlist_sync_missing_resolve_smoke.dart`: read-only real-sample missing-entry BeatSaver ID/hash resolution smoke. It writes only a temp hash cache and requires `--allow-network`.
- `tool\local_cache_snapshot_smoke.dart`: small live BeatSaver `/maps/latest` snapshot builder smoke. It requires `--allow-network`, fetches one page to system temp, verifies partial/state resume files, then cleans up. Add `--incremental` to seed a temp `LocalCache.saver` from older live rows and verify `/maps/latest?after=<last snapshot cursor>` merges newer rows into it. Add `--deleted-audit` to verify `/maps/deleted` candidate auditing without modifying the temp cache.
- `tool\local_cache_update.dart`: explicit cache maintenance command. It requires `--allow-network`, updates an existing `LocalCache.saver` in place through incremental `/maps/latest`, after copying a timestamped backup. It does not apply deleted-map cleanup.
- `tool\local_cache_inspect.dart`: prints `LocalCache.saver` size, map count, `info` metadata, and sibling `LocalCache.time`. Use `LocalCache.saver` from the project root for routine checks.
- `tool\local_cache_validate.dart`: validates `LocalCache.saver` structure, duplicate ids/hashes, and required version fields. It is offline by default; add `--api-sample=N` only when an explicit BeatSaver API spot check is needed.
- `tool\playlist_sync_missing_download_smoke.dart`: read-only real-sample missing-entry download smoke. It requires `--allow-network`, downloads ZIPs only to system temp, and verifies `Info.dat` plus audio.
- `tool\playlist_sync_missing_install_smoke.dart`: read-only real-sample missing-entry install smoke. It requires `--allow-network`, installs into a temporary `CustomLevels` directory, and verifies `scanInstalledLibrary`.
- `tool\songcore_detection_smoke.dart`: temporary invalid/game/mod directory detection checks.
- `tool\songcore_operation_smoke.dart`: temp Beat Saber SongCore save/read/remove lifecycle, including save/remove backup directory checks.
- `tool\songcore_xml_boundary_smoke.dart`: `folders.xml` placeholder/no-op/remove boundary checks.
- `tool\library_operation_smoke.dart`: temp local-library path correction with one success and one target-conflict failure, plus duplicate backup-delete including a missing selected duplicate skip.
- `tool\library_export_smoke.dart`: temp local-library `.bplist` and favorites export, including automatic installed cover image export.
- `tool\real_sample_library_export_smoke.dart`: read-only real-sample library export to temp, including automatic cover image checks.
- `tool\real_sample_duplicate_smoke.dart`: real duplicate group copied to temp, then backup-deleted, including a missing selected duplicate skip and source-preservation check.
- `tool\real_sample_path_correction_smoke.dart`: real path correction target copied to temp, then renamed.
- `tool\release_manual_acceptance.dart`: starts the Windows release with temporary `APPDATA` for manual GUI acceptance. It can launch temp-library, playlist-sync, fastlog, or search modes without touching user settings; destructive dialog checks should be opened and cancelled on the temp library only.
- `tool\release_manual_acceptance_smoke.dart`: Windows release launcher smoke. It runs the manual acceptance launcher in library, playlist-sync, fastlog, and search modes, verifies the release window title/responding state, closes the process, and removes the temporary launcher directories.

## Sample Root

Real-sample smoke scripts default to:

```text
test\Beat Saber  songs
```

Override it when needed:

```powershell
D:\Software\flutter\bin\dart.bat run tool\toolbox_smoke.dart --sample-root="F:\path\to\samples"
```

Use `--keep-temp` only on focused scripts when you need to inspect the temporary operation directory after a failure.
