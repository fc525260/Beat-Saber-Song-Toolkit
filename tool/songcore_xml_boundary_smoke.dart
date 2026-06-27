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
    'beat_saber_song_toolkit_songcore_xml_boundary_',
  );

  try {
    final game = await _createBeatSaberShape(tempRoot);
    final pack = await Directory(
      p.join(tempRoot.path, 'External Packs', 'Stable Pack'),
    ).create(recursive: true);
    await _createSong(pack, 'abc - Stable', 'Stable');

    final status = inspectBeatSaberGameDirectory(game);
    final foldersFile = status.songCoreFoldersFile;
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders version="2">
  <folder>
    <Name>Example</Name>
    <Path>C:\\Example\\Songs</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
  <folder>
    <Name>  </Name>
    <Path>  </Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
</folders>
''');

    final firstSave = await saveSongCoreFolderEntry(
      gameDirectory: game,
      songFolder: pack,
      name: 'Stable Pack',
    );
    if (!firstSave.added ||
        firstSave.updated ||
        firstSave.backupFile == null ||
        !await firstSave.backupFile!.exists()) {
      throw StateError('Initial save did not add with backup as expected.');
    }
    final afterFirstSave = await foldersFile.readAsString();
    final firstEntries = await readSongCoreFolderEntries(foldersFile);
    if (firstEntries.length != 1 ||
        firstEntries.single.name != 'Stable Pack' ||
        afterFirstSave.contains('Example')) {
      throw StateError('Placeholder entries were not filtered on save.');
    }

    final secondSave = await saveSongCoreFolderEntry(
      gameDirectory: game,
      songFolder: pack,
      name: 'Stable Pack',
    );
    final afterSecondSave = await foldersFile.readAsString();
    if (secondSave.added ||
        secondSave.updated ||
        secondSave.backupFile != null ||
        afterSecondSave != afterFirstSave) {
      throw StateError('Unchanged save should be a no-op.');
    }

    final noMatchRemove = await removeSongCoreFolderEntries(
      file: foldersFile,
      keys: [p.normalize(p.absolute(p.join(tempRoot.path, 'Missing')))],
    );
    final afterNoMatchRemove = await foldersFile.readAsString();
    if (noMatchRemove.removed != 0 ||
        noMatchRemove.backupFile != null ||
        afterNoMatchRemove != afterSecondSave) {
      throw StateError('No-match remove should not rewrite folders.xml.');
    }

    print('tempRoot=${tempRoot.path}');
    print('game=${game.path}');
    print('foldersFile=${foldersFile.path}');
    print(
        'firstSave added=${firstSave.added} backup=${firstSave.backupFile!.path}');
    print('secondSave added=${secondSave.added} updated=${secondSave.updated}');
    print('noMatchRemove removed=${noMatchRemove.removed}');
    print('entries=${firstEntries.length}');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<Directory> _createBeatSaberShape(Directory tempRoot) async {
  final game = await Directory(p.join(tempRoot.path, 'Beat Saber')).create();
  await File(p.join(game.path, 'Beat Saber.exe')).create();
  await Directory(p.join(game.path, 'Beat Saber_Data')).create();
  final plugins = await Directory(p.join(game.path, 'Plugins')).create();
  await File(p.join(plugins.path, 'SongCore.dll')).create();
  await File(p.join(plugins.path, 'PlaylistManager.dll')).create();
  return game;
}

Future<void> _createSong(
  Directory parent,
  String directoryName,
  String songName,
) async {
  final songDir = await Directory(p.join(parent.path, directoryName)).create();
  await File(p.join(songDir.path, 'Info.dat')).writeAsString(
    '{"_songName":"$songName","_songAuthorName":"Artist"}',
  );
  await File(p.join(songDir.path, 'song.egg')).writeAsString('audio');
}

const _usage = r'''
Usage:
  dart run tool\songcore_xml_boundary_smoke.dart [options]

Options:
  --keep-temp   Keep the temp Beat Saber directory after the smoke run.
  --help, -h    Show this help.

The script creates a temporary Beat Saber-shaped directory and verifies
SongCore folders.xml boundary behavior: placeholder entries are filtered when a
real entry is saved, unchanged saves are no-ops, and no-match removes do not
rewrite or back up folders.xml.
''';
