import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_helpers.dart';
import 'hash_detail_cache.dart';
import 'installed_library.dart';
import 'playlist_export.dart';

class PlaylistSyncEntry {
  const PlaylistSyncEntry({
    required this.playlistEntry,
    required this.beatSaverDetail,
    required this.installedEntry,
    required this.matchType,
    required this.hasEgg,
  });

  final BplistSongEntry playlistEntry;
  final BeatSaverHashDetail? beatSaverDetail;
  final InstalledSongEntry? installedEntry;
  final PlaylistSyncMatchType matchType;
  final bool hasEgg;

  bool get isInstalled => installedEntry != null;
  String get hash => playlistEntry.hash.trim().toLowerCase();
  String get mapId => playlistEntry.key.trim().toLowerCase();
}

class PlaylistSyncComparison {
  const PlaylistSyncComparison({
    required this.entries,
    required this.localOnlyInstalledEntries,
  });

  final List<PlaylistSyncEntry> entries;
  final List<InstalledSongEntry> localOnlyInstalledEntries;
}

class PlaylistSyncDeleteResult {
  const PlaylistSyncDeleteResult({
    required this.requested,
    required this.deleted,
    required this.removedPlaylistEntries,
    this.playlistBackup,
    required this.songBackups,
  });

  final int requested;
  final int deleted;
  final int removedPlaylistEntries;
  final File? playlistBackup;
  final List<Directory> songBackups;
}

class PlaylistSyncPlaylistRemoveResult {
  const PlaylistSyncPlaylistRemoveResult({
    required this.requested,
    required this.removedPlaylistEntries,
    this.playlistBackup,
  });

  final int requested;
  final int removedPlaylistEntries;
  final File? playlistBackup;
}

enum PlaylistSyncMatchType {
  mapId,
  normalizedName,
  localHash,
  missing,
}

Future<List<PlaylistSyncEntry>> comparePlaylistWithInstalledLibrary({
  required BplistPlaylist playlist,
  required Directory libraryDirectory,
  Map<String, BeatSaverHashDetail> hashDetails = const {},
}) async {
  final comparison = await comparePlaylistWithInstalledLibraryDetailed(
    playlist: playlist,
    libraryDirectory: libraryDirectory,
    hashDetails: hashDetails,
  );
  return comparison.entries;
}

Future<PlaylistSyncComparison> comparePlaylistWithInstalledLibraryDetailed({
  required BplistPlaylist playlist,
  required Directory libraryDirectory,
  Map<String, BeatSaverHashDetail> hashDetails = const {},
}) async {
  final installed = await scanInstalledLibrary(libraryDirectory);
  final installedById = <String, InstalledSongEntry>{};
  final installedByName = <String, InstalledSongEntry>{};
  var installedByHash = const <String, InstalledSongEntry>{};
  final needsLocalHash = playlist.entries.any(
    (entry) => entry.hash.trim().isNotEmpty,
  );

  for (final entry in installed) {
    final mapId = entry.mapId?.trim().toLowerCase();
    if (mapId != null && mapId.isNotEmpty) {
      installedById.putIfAbsent(mapId, () => entry);
    }
    final name = _normalizedSongName(entry.info?.songName ?? entry.title ?? '');
    if (name.isNotEmpty) {
      installedByName.putIfAbsent(name, () => entry);
    }
  }

  if (needsLocalHash) {
    installedByHash = await _installedHashIndex(installed);
  }
  final playlistHashes = playlist.entries
      .map((entry) => entry.hash.trim().toLowerCase())
      .where((hash) => hash.isNotEmpty)
      .toSet();

  final results = <PlaylistSyncEntry>[];
  for (final entry in playlist.entries) {
    final mapId = entry.key.trim().toLowerCase();
    final hash = entry.hash.trim().toLowerCase();
    final detail = hashDetails[hash];

    var matchType = PlaylistSyncMatchType.missing;
    InstalledSongEntry? installedEntry;
    if (mapId.isNotEmpty) {
      installedEntry = installedById[mapId];
      if (installedEntry != null) {
        matchType = PlaylistSyncMatchType.mapId;
      }
    }

    if (installedEntry == null && detail != null) {
      final normalizedName = _normalizedSongName(detail.name);
      if (normalizedName.isNotEmpty) {
        installedEntry = installedByName[normalizedName];
        if (installedEntry != null) {
          matchType = PlaylistSyncMatchType.normalizedName;
        }
      }
    }

    if (installedEntry == null && hash.isNotEmpty) {
      installedEntry = installedByHash[hash];
      if (installedEntry != null) {
        matchType = PlaylistSyncMatchType.localHash;
      }
    }

    results.add(
      PlaylistSyncEntry(
        playlistEntry: entry,
        beatSaverDetail: detail,
        installedEntry: installedEntry,
        matchType: matchType,
        hasEgg: installedEntry == null ? false : await _hasEgg(installedEntry),
      ),
    );
  }

  final localOnlyInstalledEntries = needsLocalHash
      ? installedByHash.entries
          .where((entry) => !playlistHashes.contains(entry.key))
          .map((entry) => entry.value)
          .toList(growable: false)
      : const <InstalledSongEntry>[];

  return PlaylistSyncComparison(
    entries: results,
    localOnlyInstalledEntries: localOnlyInstalledEntries,
  );
}

Future<PlaylistSyncDeleteResult> deletePlaylistSyncEntriesWithBackup({
  required File playlistFile,
  required Iterable<PlaylistSyncEntry> entries,
  required Directory backupDirectory,
}) async {
  final selected = entries
      .where((entry) => entry.installedEntry != null)
      .toList(growable: false);
  if (selected.isEmpty) {
    throw ArgumentError('No installed playlist sync entries selected.');
  }

  final present = await _playlistSyncEntriesPresentInBplist(
    playlistFile: playlistFile,
    entries: selected,
  );
  if (present.isEmpty) {
    return PlaylistSyncDeleteResult(
      requested: selected.length,
      deleted: 0,
      removedPlaylistEntries: 0,
      songBackups: const [],
    );
  }

  final playlistBackup = await backupFileToDirectory(
    playlistFile,
    backupDirectory,
  );
  final removed = await removePlaylistSyncEntriesFromBplist(
    playlistFile: playlistFile,
    entries: present,
  );
  final songBackups = <Directory>[];
  final deletedSourcePaths = <String>{};
  var deleted = 0;
  for (final entry in present) {
    final installed = entry.installedEntry;
    if (installed == null) {
      continue;
    }
    final source = installed.directory;
    if (!deletedSourcePaths.add(_normalizedFileSystemPath(source.path))) {
      continue;
    }
    if (!await source.exists()) {
      continue;
    }
    final backup = await backupDirectoryToDirectory(source, backupDirectory);
    songBackups.add(backup);
    await source.delete(recursive: true);
    deleted += 1;
  }

  return PlaylistSyncDeleteResult(
    requested: selected.length,
    deleted: deleted,
    removedPlaylistEntries: removed,
    playlistBackup: playlistBackup,
    songBackups: songBackups,
  );
}

Future<List<PlaylistSyncEntry>> _playlistSyncEntriesPresentInBplist({
  required File playlistFile,
  required Iterable<PlaylistSyncEntry> entries,
}) async {
  final selected = entries.toList(growable: false);
  final decoded = jsonDecode(await playlistFile.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected bplist JSON object.');
  }
  final songs = decoded['songs'];
  if (songs is! List) {
    return const [];
  }
  final present = <PlaylistSyncEntry>[];
  final presentKeys = <String>{};
  for (final entry in selected) {
    final key = _playlistSyncEntrySelectionKey(entry);
    if (key == null || !presentKeys.add(key)) {
      continue;
    }
    if (_playlistSyncEntriesToRemove(songs, [entry]) > 0) {
      present.add(entry);
    }
  }
  return present;
}

Future<int> removePlaylistSyncEntriesFromBplist({
  required File playlistFile,
  required Iterable<PlaylistSyncEntry> entries,
}) async {
  final decoded = jsonDecode(await playlistFile.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected bplist JSON object.');
  }
  final songs = decoded['songs'];
  if (songs is! List) {
    return 0;
  }

  final keyedPairs = <String>{};
  final keyOnlyKeys = <String>{};
  final hashOnlyHashes = <String>{};
  for (final entry in entries) {
    final key = entry.playlistEntry.key.trim().toLowerCase();
    final hash = entry.playlistEntry.hash.trim().toLowerCase();
    if (key.isNotEmpty && hash.isNotEmpty) {
      keyedPairs.add('$key|$hash');
    } else if (key.isNotEmpty) {
      keyOnlyKeys.add(key);
    } else if (hash.isNotEmpty) {
      hashOnlyHashes.add(hash);
    }
  }
  if (keyedPairs.isEmpty && keyOnlyKeys.isEmpty && hashOnlyHashes.isEmpty) {
    return 0;
  }

  final kept = <Object?>[];
  var removed = 0;
  for (final song in songs) {
    if (song is Map) {
      final key = song['key']?.toString().trim().toLowerCase() ?? '';
      final hash = song['hash']?.toString().trim().toLowerCase() ?? '';
      if ((key.isNotEmpty && keyedPairs.contains('$key|$hash')) ||
          (key.isNotEmpty && keyOnlyKeys.contains(key)) ||
          (key.isEmpty && hash.isNotEmpty && hashOnlyHashes.contains(hash))) {
        removed += 1;
        continue;
      }
    }
    kept.add(song);
  }

  if (removed == 0) {
    return 0;
  }

  decoded['songs'] = kept;
  await playlistFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(decoded),
    flush: true,
  );
  return removed;
}

Future<PlaylistSyncPlaylistRemoveResult>
    removePlaylistSyncEntriesFromBplistWithBackup({
  required File playlistFile,
  required Iterable<PlaylistSyncEntry> entries,
  required Directory backupDirectory,
}) async {
  final selected = entries.toList(growable: false);
  if (selected.isEmpty) {
    throw ArgumentError('No playlist sync entries selected.');
  }

  final present = await _playlistSyncEntriesPresentInBplist(
    playlistFile: playlistFile,
    entries: selected,
  );
  if (present.isEmpty) {
    return PlaylistSyncPlaylistRemoveResult(
      requested: selected.length,
      removedPlaylistEntries: 0,
    );
  }

  final playlistBackup = await backupFileToDirectory(
    playlistFile,
    backupDirectory,
  );
  final removed = await removePlaylistSyncEntriesFromBplist(
    playlistFile: playlistFile,
    entries: present,
  );
  return PlaylistSyncPlaylistRemoveResult(
    requested: selected.length,
    removedPlaylistEntries: removed,
    playlistBackup: playlistBackup,
  );
}

int _playlistSyncEntriesToRemove(
  Iterable<Object?> songs,
  Iterable<PlaylistSyncEntry> entries,
) {
  final keyedPairs = <String>{};
  final keyOnlyKeys = <String>{};
  final hashOnlyHashes = <String>{};
  for (final entry in entries) {
    final key = entry.playlistEntry.key.trim().toLowerCase();
    final hash = entry.playlistEntry.hash.trim().toLowerCase();
    if (key.isNotEmpty && hash.isNotEmpty) {
      keyedPairs.add('$key|$hash');
    } else if (key.isNotEmpty) {
      keyOnlyKeys.add(key);
    } else if (hash.isNotEmpty) {
      hashOnlyHashes.add(hash);
    }
  }
  if (keyedPairs.isEmpty && keyOnlyKeys.isEmpty && hashOnlyHashes.isEmpty) {
    return 0;
  }

  var removed = 0;
  for (final song in songs) {
    if (song is Map) {
      final key = song['key']?.toString().trim().toLowerCase() ?? '';
      final hash = song['hash']?.toString().trim().toLowerCase() ?? '';
      if ((key.isNotEmpty && keyedPairs.contains('$key|$hash')) ||
          (key.isNotEmpty && keyOnlyKeys.contains(key)) ||
          (key.isEmpty && hash.isNotEmpty && hashOnlyHashes.contains(hash))) {
        removed += 1;
      }
    }
  }
  return removed;
}

String _normalizedSongName(String value) {
  return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

Future<Map<String, InstalledSongEntry>> _installedHashIndex(
  List<InstalledSongEntry> installed,
) async {
  const batchSize = 8;
  final index = <String, InstalledSongEntry>{};
  final hashable =
      installed.where((entry) => entry.hasInfoDat).toList(growable: false);
  for (var start = 0; start < hashable.length; start += batchSize) {
    final end = start + batchSize > hashable.length
        ? hashable.length
        : start + batchSize;
    final batch = hashable.sublist(start, end);
    final hashes = await Future.wait(
      batch.map((entry) => computeInstalledSongHash(entry.directory)),
    );
    for (var i = 0; i < batch.length; i += 1) {
      final hash = hashes[i];
      if (hash != null && hash.isNotEmpty) {
        index.putIfAbsent(hash, () => batch[i]);
      }
    }
  }
  return index;
}

String? _playlistSyncEntrySelectionKey(PlaylistSyncEntry entry) {
  final key = entry.playlistEntry.key.trim().toLowerCase();
  final hash = entry.playlistEntry.hash.trim().toLowerCase();
  if (key.isNotEmpty && hash.isNotEmpty) {
    return '$key|$hash';
  }
  if (key.isNotEmpty) {
    return 'key:$key';
  }
  if (hash.isNotEmpty) {
    return 'hash:$hash';
  }
  return null;
}

String _normalizedFileSystemPath(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

Future<bool> _hasEgg(InstalledSongEntry entry) async {
  await for (final entity in entry.directory.list(followLinks: false)) {
    if (entity is File && p.extension(entity.path).toLowerCase() == '.egg') {
      return true;
    }
  }
  return false;
}
