import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }
  final keepTemp = args.contains('--keep-temp');
  final tempRoot = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_library_smoke_',
  );

  try {
    final library = await Directory(
      p.join(tempRoot.path, 'CustomLevels'),
    ).create();
    final wrong = await _createSong(
      library,
      'abc - Wrong',
      id: 'abc',
      songName: 'Correct Song',
      songAuthorName: 'Artist',
      levelAuthorName: 'Mapper',
      bpm: 128,
    );
    final keep = await _createSong(
      library,
      'def - Keep',
      id: 'def',
      songName: 'Keep',
      songAuthorName: 'Artist',
      levelAuthorName: 'Mapper',
      bpm: 140,
    );
    final duplicate = await _createSong(
      library,
      'DEF - Remove',
      id: 'def',
      songName: 'Keep Copy',
      songAuthorName: 'Artist',
      levelAuthorName: 'Mapper',
      bpm: 140,
    );
    final conflictSource = await _createSong(
      library,
      '12345 - Wrong',
      id: '12345',
      songName: 'Conflict Song',
      songAuthorName: 'Artist',
      levelAuthorName: 'Mapper',
      bpm: 130,
    );
    final conflictExpectedName =
        '12345 - Conflict Song - Artist - Mapper - 130';
    final conflictTarget = await Directory(
      p.join(library.path, conflictExpectedName),
    ).create();

    final scanned = await scanInstalledLibrary(library);
    final corrections = suggestInstalledPathCorrections(
      scanned.where((entry) {
        final id = entry.mapId?.toLowerCase();
        return entry.hasInfoDat && (id == 'abc' || id == '12345');
      }),
      template: '[id] - [歌名] - [作者] - [制作者] - [bpm]',
    );
    if (corrections.length != 2) {
      throw StateError(
          'Expected two path corrections, got ${corrections.length}.');
    }
    final expectedName = 'abc - Correct Song - Artist - Mapper - 128';
    final successCorrection = corrections.firstWhere(
      (correction) => correction.entry.mapId?.toLowerCase() == 'abc',
    );
    final conflictCorrection = corrections.firstWhere(
      (correction) => correction.entry.mapId?.toLowerCase() == '12345',
    );
    if (successCorrection.expectedDirectoryName != expectedName) {
      throw StateError(
        'Expected correction "$expectedName", got '
        '"${successCorrection.expectedDirectoryName}".',
      );
    }
    if (conflictCorrection.expectedDirectoryName != conflictExpectedName) {
      throw StateError(
        'Expected conflict correction "$conflictExpectedName", got '
        '"${conflictCorrection.expectedDirectoryName}".',
      );
    }

    final renameResult = await applyInstalledPathCorrections(corrections);
    final renamed = Directory(p.join(library.path, expectedName));
    if (renameResult.requested != 2 ||
        renameResult.renamed != 1 ||
        renameResult.failed != 1 ||
        renameResult.failures.length != 1 ||
        renameResult.failures.single.expectedDirectoryName !=
            conflictExpectedName ||
        renameResult.failures.single.reason !=
            'Target directory already exists' ||
        !await renamed.exists() ||
        await wrong.exists() ||
        !await conflictSource.exists() ||
        !await conflictTarget.exists()) {
      throw StateError('Path correction did not rename as expected.');
    }
    await conflictTarget.delete();

    final rescanned = await scanInstalledLibrary(library);
    final remainingCorrections = suggestInstalledPathCorrections(
      rescanned.where((entry) {
        return entry.hasInfoDat && entry.mapId?.toLowerCase() == '12345';
      }),
      template: '[id] - [歌名] - [作者] - [制作者] - [bpm]',
    );
    if (remainingCorrections.length != 1 ||
        remainingCorrections.single.entry.directory.path !=
            conflictSource.path) {
      throw StateError('Expected one remaining conflict path correction.');
    }
    final duplicateGroups = findInstalledDuplicateGroups(rescanned);
    final candidates = installedDuplicateRemovalCandidates(duplicateGroups);
    if (candidates.map((entry) => entry.directoryName).join('|') !=
        'DEF - Remove') {
      throw StateError(
        'Expected DEF - Remove as duplicate candidate, got '
        '${candidates.map((entry) => entry.directoryName).join(', ')}.',
      );
    }

    final backupDirectory = Directory(
      p.join(tempRoot.path, 'CustomLevels_backup', 'duplicates'),
    );
    final missingDuplicate = InstalledSongEntry(
      directory: Directory(p.join(library.path, 'DEF - Already Gone')),
      directoryName: 'DEF - Already Gone',
      hasInfoDat: true,
      mapId: 'def',
      title: 'Keep Copy',
    );
    final deleteResult = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [...candidates, missingDuplicate],
      backupDirectory: backupDirectory,
    );
    if (deleteResult.requested != 2 ||
        deleteResult.deleted != 1 ||
        deleteResult.backups.length != 1 ||
        deleteResult.skippedMissing != 1 ||
        !await keep.exists() ||
        await duplicate.exists() ||
        !await File(p.join(deleteResult.backups.single.path, 'Info.dat'))
            .exists()) {
      throw StateError('Duplicate backup delete did not behave as expected.');
    }

    final finalEntries = await scanInstalledLibrary(library);
    final finalDuplicateGroups = findInstalledDuplicateGroups(finalEntries);
    if (finalDuplicateGroups.isNotEmpty) {
      throw StateError('Duplicate groups should be empty after delete.');
    }

    print('tempRoot=${tempRoot.path}');
    print('library=${library.path}');
    print('initialSongs=${scanned.length}');
    print(
      'rename requested=${renameResult.requested} '
      'renamed=${renameResult.renamed} failed=${renameResult.failed}',
    );
    print(
      'renameFailure=${renameResult.failures.single.sourcePath} -> '
      '${renameResult.failures.single.expectedDirectoryName} '
      'reason=${renameResult.failures.single.reason}',
    );
    print('remainingPathCorrections=${remainingCorrections.length}');
    print('renamedExists=${await renamed.exists()}');
    print('duplicateCandidates=${candidates.length}');
    print(
      'delete requested=${deleteResult.requested} '
      'deleted=${deleteResult.deleted} backups=${deleteResult.backups.length} '
      'skippedMissing=${deleteResult.skippedMissing}',
    );
    print('backupDirectory=${backupDirectory.path}');
    print('keepStillExists=${await keep.exists()}');
    print('duplicateRemoved=${!await duplicate.exists()}');
    print('finalDuplicateGroups=${finalDuplicateGroups.length}');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<Directory> _createSong(
  Directory parent,
  String directoryName, {
  required String id,
  required String songName,
  required String songAuthorName,
  required String levelAuthorName,
  required int bpm,
}) async {
  final songDir = await Directory(p.join(parent.path, directoryName)).create();
  await File(p.join(songDir.path, 'Info.dat')).writeAsString('''
{
  "_songName": "$songName",
  "_songAuthorName": "$songAuthorName",
  "_levelAuthorName": "$levelAuthorName",
  "_beatsPerMinute": $bpm
}
''');
  await File(p.join(songDir.path, 'song.egg')).writeAsString('audio');
  await File(p.join(songDir.path, '$id.dat')).writeAsString('{}');
  return songDir;
}

const _usage = r'''
Usage:
  dart run tool\library_operation_smoke.dart [options]

Options:
  --keep-temp   Keep the temp library after the smoke run.
  --help, -h    Show this help.

The script creates a temporary CustomLevels-shaped library, runs path
correction batch rename, scans duplicate candidates, backs up and deletes the
duplicate candidate, and verifies that the retained song and backup exist. It
never touches a real Beat Saber installation or the real sample directory.
''';
