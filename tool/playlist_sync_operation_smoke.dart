import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }
  final keepTemp = args.contains('--keep-temp');
  final packFilter = _stringOption(args, '--pack=');
  final playlistFilter = _stringOption(args, '--playlist=');
  final deleteCount = _intOption(args, '--delete-count=', fallback: 1);
  final requestedCopyCount = _intOption(
    args,
    '--copy-count=',
    fallback: deleteCount + 1,
  );
  final copyCount = requestedCopyCount < deleteCount + 1
      ? deleteCount + 1
      : requestedCopyCount;
  if (deleteCount < 1) {
    stderr.writeln('--delete-count must be >= 1.');
    exitCode = 2;
    return;
  }
  final pathArg = args.where((arg) => !arg.startsWith('--')).firstOrNull;
  final sampleRoot = Directory(
    pathArg ?? p.join('test', 'Beat Saber  songs'),
  );
  if (!await sampleRoot.exists()) {
    stderr.writeln('Sample root not found: ${sampleRoot.path}');
    exitCode = 2;
    return;
  }

  final packDirs = await sampleRoot
      .list(followLinks: false)
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  packDirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final playlists = await sampleRoot
      .list(followLinks: false)
      .where(
        (entity) =>
            entity is File &&
            p.extension(entity.path).toLowerCase() == '.bplist',
      )
      .cast<File>()
      .toList();
  playlists.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final playlistByPackTitle = <String, File>{};
  for (final playlist in playlists) {
    playlistByPackTitle[_packTitle(p.basenameWithoutExtension(playlist.path))] =
        playlist;
  }

  _SmokeSource? source;
  for (final packDir in packDirs) {
    if (packFilter != null &&
        !_matchesFilter(p.basename(packDir.path), packFilter)) {
      continue;
    }
    final playlistFile =
        playlistByPackTitle[_packTitle(p.basename(packDir.path))];
    if (playlistFile == null) {
      continue;
    }
    if (playlistFilter != null &&
        !_matchesFilter(playlistFile.path, playlistFilter) &&
        !_matchesFilter(p.basename(playlistFile.path), playlistFilter)) {
      continue;
    }
    final compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(playlistFile),
      libraryDirectory: packDir,
    );
    final installed =
        compared.where((entry) => entry.isInstalled).take(copyCount).toList();
    final missing = compared.where((entry) => !entry.isInstalled).firstOrNull;
    if (installed.length >= copyCount && missing != null) {
      source = _SmokeSource(
        packDir: packDir,
        playlistFile: playlistFile,
        installed: installed,
        missing: missing,
      );
      break;
    }
  }

  if (source == null) {
    stderr.writeln('No real sample pack matched filters with enough installed '
        'rows and at least one missing row.');
    exitCode = 3;
    return;
  }

  final originalPlaylistText = await source.playlistFile.readAsString();
  final originalInstalledDirs = source.installed
      .map((entry) => entry.installedEntry!.directory)
      .toList(growable: false);

  final tempRoot = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_playlist_sync_smoke_',
  );
  try {
    final tempLibrary = await Directory(
      p.join(tempRoot.path, 'CustomLevels'),
    ).create(recursive: true);
    final tempPlaylist = await source.playlistFile.copy(
      p.join(tempRoot.path, p.basename(source.playlistFile.path)),
    );

    for (final entry in source.installed) {
      final sourceDir = entry.installedEntry!.directory;
      await copyDirectoryRecursive(
        sourceDir,
        Directory(p.join(tempLibrary.path, p.basename(sourceDir.path))),
      );
    }

    var compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(tempPlaylist),
      libraryDirectory: tempLibrary,
    );
    final initialPlaylistEntryCount =
        (await readBplist(tempPlaylist)).entries.length;
    final copiedInstalled =
        compared.where((entry) => entry.isInstalled).toList(growable: false);
    final selectedMissing = compared.firstWhere(
      (entry) => entry.hash == source!.missing.hash && !entry.isInstalled,
    );
    if (copiedInstalled.length != source.installed.length) {
      throw StateError(
        'Expected ${source.installed.length} copied installed rows, '
        'got ${copiedInstalled.length}.',
      );
    }

    final backupDirectory = Directory(p.join(tempRoot.path, 'backup'));
    final removeResult = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: tempPlaylist,
      entries: [selectedMissing],
      backupDirectory: backupDirectory,
    );
    if (removeResult.removedPlaylistEntries != 1 ||
        removeResult.playlistBackup == null ||
        !await removeResult.playlistBackup!.exists()) {
      throw StateError('Playlist-only removal did not create expected backup.');
    }
    final afterPlaylistOnlyEntryCount =
        (await readBplist(tempPlaylist)).entries.length;
    if (afterPlaylistOnlyEntryCount != initialPlaylistEntryCount - 1) {
      throw StateError(
        'Playlist-only removal count mismatch: '
        'initial=$initialPlaylistEntryCount '
        'after=$afterPlaylistOnlyEntryCount.',
      );
    }

    compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(tempPlaylist),
      libraryDirectory: tempLibrary,
    );
    final deleteTargets = compared
        .where((entry) => entry.isInstalled)
        .take(deleteCount)
        .toList(growable: false);
    final deleteDirs = deleteTargets
        .map((entry) => entry.installedEntry!.directory)
        .toList(growable: false);
    final deleteHashes = deleteTargets.map((entry) => entry.hash).toSet();
    final keepTargets = compared
        .where(
            (entry) => entry.isInstalled && !deleteHashes.contains(entry.hash))
        .toList(growable: false);
    final keepDirs = keepTargets
        .map((entry) => entry.installedEntry!.directory)
        .toList(growable: false);
    if (deleteTargets.length != deleteCount || keepTargets.isEmpty) {
      throw StateError(
          'Not enough temp installed rows for delete/keep checks.');
    }

    final deleteResult = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: tempPlaylist,
      entries: deleteTargets,
      backupDirectory: backupDirectory,
    );
    if (deleteResult.deleted != deleteTargets.length ||
        deleteResult.removedPlaylistEntries != deleteTargets.length ||
        deleteResult.playlistBackup == null ||
        deleteResult.songBackups.length != deleteTargets.length) {
      throw StateError('Backup delete did not produce expected result.');
    }
    for (final directory in deleteDirs) {
      if (await directory.exists()) {
        throw StateError('Selected temp installed directory still exists.');
      }
    }
    for (final directory in keepDirs) {
      if (!await directory.exists()) {
        throw StateError('Unselected temp installed directory was removed.');
      }
    }

    final finalPlaylist = await readBplist(tempPlaylist);
    final finalPlaylistEntryCount = finalPlaylist.entries.length;
    if (finalPlaylistEntryCount !=
        initialPlaylistEntryCount - 1 - deleteTargets.length) {
      throw StateError(
        'Final playlist entry count mismatch: '
        'initial=$initialPlaylistEntryCount '
        'playlistOnly=$afterPlaylistOnlyEntryCount '
        'deleteTargets=${deleteTargets.length} final=$finalPlaylistEntryCount.',
      );
    }
    final remainingHashes =
        finalPlaylist.entries.map((entry) => entry.hash).toSet();
    if (remainingHashes.contains(source.missing.hash) ||
        deleteHashes.any(remainingHashes.contains) ||
        !keepTargets.every((entry) => remainingHashes.contains(entry.hash))) {
      throw StateError('Final temp playlist rows are not as expected.');
    }

    final sourcePlaylistUnchanged =
        await source.playlistFile.readAsString() == originalPlaylistText;
    final sourceDirsStillExist = <bool>[];
    for (final directory in originalInstalledDirs) {
      sourceDirsStillExist.add(await directory.exists());
    }
    if (!sourcePlaylistUnchanged || sourceDirsStillExist.contains(false)) {
      throw StateError('Original real sample was modified.');
    }

    print('sampleRoot=${sampleRoot.path}');
    print('pack=${p.basename(source.packDir.path)}');
    print('playlist=${p.basename(source.playlistFile.path)}');
    print('tempRoot=${tempRoot.path}');
    print('initialPlaylistEntries=$initialPlaylistEntryCount');
    print('copiedInstalled=${copiedInstalled.length}');
    print('deleteCount=$deleteCount');
    print(
      'playlistOnly removed=${removeResult.removedPlaylistEntries} '
      'backup=${removeResult.playlistBackup!.path}',
    );
    print('afterPlaylistOnlyEntries=$afterPlaylistOnlyEntryCount');
    print(
      'backupDelete deleted=${deleteResult.deleted} '
      'playlistRemoved=${deleteResult.removedPlaylistEntries} '
      'songBackups=${deleteResult.songBackups.length}',
    );
    print('finalPlaylistEntries=$finalPlaylistEntryCount');
    print('sourceUnchanged=$sourcePlaylistUnchanged');
    print(
        'sourceDirsStillExist=${sourceDirsStillExist.every((exists) => exists)}');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

String _packTitle(String name) {
  return name.replaceFirst(RegExp(r'\s+更新至\[[^\]]+\].*$'), '').trim();
}

String? _stringOption(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

int _intOption(
  List<String> args,
  String prefix, {
  required int fallback,
}) {
  final value = _stringOption(args, prefix);
  return value == null ? fallback : int.tryParse(value) ?? fallback;
}

bool _matchesFilter(String value, String filter) {
  return value.toLowerCase().contains(filter.toLowerCase());
}

class _SmokeSource {
  const _SmokeSource({
    required this.packDir,
    required this.playlistFile,
    required this.installed,
    required this.missing,
  });

  final Directory packDir;
  final File playlistFile;
  final List<PlaylistSyncEntry> installed;
  final PlaylistSyncEntry missing;
}

const _usage = r'''
Usage:
  dart run tool\playlist_sync_operation_smoke.dart [sampleRoot] [options]

Options:
  --pack=TEXT          Only use a pack directory whose name contains TEXT.
  --playlist=TEXT     Only use a .bplist path/name containing TEXT.
  --copy-count=N      Copy N installed song directories to a temp library.
  --delete-count=N    Backup-delete N copied installed entries. Default: 1.
  --keep-temp         Keep the temp directory after the smoke run.
  --help, -h          Show this help.

Default sampleRoot:
  test\Beat Saber  songs

The script never writes to the sample root. It copies a real .bplist and a
small number of matched song directories into a system temp directory, then
runs playlist-only removal and backup-delete against the temp copy.
''';
