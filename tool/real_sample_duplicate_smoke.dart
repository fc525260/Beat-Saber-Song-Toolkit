import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final keepTemp = args.contains('--keep-temp');
  final sampleRoot = Directory(
    _option(args, '--sample-root=') ?? p.join('test', 'Beat Saber  songs'),
  );
  final packKeyword = _option(args, '--pack=') ?? '中文';
  if (!await sampleRoot.exists()) {
    stderr.writeln('Sample root not found: ${sampleRoot.path}');
    exitCode = 2;
    return;
  }

  final packDir = await _findPackDirectory(sampleRoot, packKeyword);
  if (packDir == null) {
    stderr.writeln(
      'Pack directory not found under ${sampleRoot.path}: $packKeyword',
    );
    exitCode = 2;
    return;
  }

  final tempRoot = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_real_sample_duplicate_smoke_',
  );
  try {
    final installed = await scanInstalledLibrary(packDir);
    final groups = findInstalledDuplicateGroups(installed);
    if (groups.isEmpty) {
      throw StateError('Expected duplicate groups in ${packDir.path}.');
    }

    final group = groups.first;
    final candidates = installedDuplicateRemovalCandidates([group]);
    if (candidates.isEmpty) {
      throw StateError('Expected duplicate removal candidates.');
    }

    final tempLibrary = await Directory(
      p.join(tempRoot.path, 'CustomLevels'),
    ).create(recursive: true);
    final sourceDirs = <String>[];
    for (final entry in group.entries) {
      final sourceDir = entry.directory;
      sourceDirs.add(sourceDir.path);
      await copyDirectoryRecursive(
        sourceDir,
        Directory(p.join(tempLibrary.path, p.basename(sourceDir.path))),
      );
    }

    final rescanned = await scanInstalledLibrary(tempLibrary);
    final tempGroups = findInstalledDuplicateGroups(rescanned);
    if (tempGroups.isEmpty) {
      throw StateError('Expected duplicate groups in temp library.');
    }
    final tempCandidates =
        installedDuplicateRemovalCandidates([tempGroups.first]);
    if (tempCandidates.isEmpty) {
      throw StateError('Expected temp duplicate candidates.');
    }

    final backupDirectory = Directory(
      p.join(tempRoot.path, 'CustomLevels_backup', 'duplicates'),
    );
    final missingCandidate = InstalledSongEntry(
      directory: Directory(p.join(tempLibrary.path, 'missing duplicate')),
      directoryName: 'missing duplicate',
      hasInfoDat: true,
      mapId: tempCandidates.first.mapId,
      title: tempCandidates.first.title,
    );
    final deleteResult = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [...tempCandidates, missingCandidate],
      backupDirectory: backupDirectory,
    );
    if (deleteResult.requested != tempCandidates.length + 1 ||
        deleteResult.deleted != tempCandidates.length ||
        deleteResult.backups.length != tempCandidates.length ||
        deleteResult.skippedMissing != 1) {
      throw StateError('Duplicate backup delete did not behave as expected.');
    }

    final finalEntries = await scanInstalledLibrary(tempLibrary);
    final finalGroups = findInstalledDuplicateGroups(finalEntries);
    if (finalGroups.isNotEmpty) {
      throw StateError('Duplicate groups should be empty after delete.');
    }

    for (final entry in tempCandidates) {
      if (await entry.directory.exists()) {
        throw StateError('Selected temp duplicate directory still exists.');
      }
    }
    var sourceDirsStillExist = true;
    for (final sourceDir in sourceDirs) {
      sourceDirsStillExist =
          sourceDirsStillExist && await Directory(sourceDir).exists();
    }
    if (!sourceDirsStillExist) {
      throw StateError('Real sample source directory was modified.');
    }

    print('sampleRoot=${sampleRoot.path}');
    print('pack=${p.basename(packDir.path)}');
    print('tempRoot=${tempRoot.path}');
    print('sourceDuplicateGroups=${groups.length}');
    print('sourceDuplicateCandidateCount=${candidates.length}');
    print('copiedDuplicateDirs=${sourceDirs.length}');
    print(
      'delete requested=${deleteResult.requested} '
      'deleted=${deleteResult.deleted} backups=${deleteResult.backups.length} '
      'skippedMissing=${deleteResult.skippedMissing}',
    );
    print('backupDirectory=${backupDirectory.path}');
    print('sourceDirsStillExist=$sourceDirsStillExist');
    print('finalDuplicateGroups=${finalGroups.length}');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

String? _option(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

Future<Directory?> _findPackDirectory(
  Directory sampleRoot,
  String keyword,
) async {
  final normalizedKeyword = keyword.toLowerCase();
  final directories = await sampleRoot
      .list(followLinks: false)
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  directories.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  for (final directory in directories) {
    if (p.basename(directory.path).toLowerCase().contains(normalizedKeyword)) {
      return directory;
    }
  }
  return directories.isEmpty ? null : directories.first;
}

const _usage = r'''
Usage:
  dart run tool\real_sample_duplicate_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --pack=KEYWORD     Pick a pack directory by name keyword. Defaults to 中文.
  --keep-temp        Keep the temporary duplicate test directory.
  --help, -h         Show this help.

The script scans one real sample pack read-only, copies duplicate groups into a
system temp library, deletes duplicate candidates with backup, and verifies the
temp copy is cleaned up while the real sample directory remains untouched.
''';
