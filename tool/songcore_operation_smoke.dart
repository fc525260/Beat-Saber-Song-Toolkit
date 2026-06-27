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
    'beat_saber_song_toolkit_songcore_smoke_',
  );

  try {
    final game = await Directory(p.join(tempRoot.path, 'Beat Saber')).create();
    await File(p.join(game.path, 'Beat Saber.exe')).create();
    await Directory(p.join(game.path, 'Beat Saber_Data')).create();
    final customLevels = await Directory(
      p.join(game.path, 'Beat Saber_Data', 'CustomLevels'),
    ).create(recursive: true);
    final plugins = await Directory(p.join(game.path, 'Plugins')).create();
    await File(p.join(plugins.path, 'SongCore.dll')).create();
    await File(p.join(plugins.path, 'PlaylistManager.dll')).create();

    await _createSong(customLevels, 'abc - First', 'First');
    await _createSong(customLevels, 'def - Second', 'Second');
    await Directory(p.join(customLevels.path, 'broken')).create();

    final status = inspectBeatSaberGameDirectory(game);
    if (!status.isBeatSaberDirectory ||
        !status.isSongCoreInstalled ||
        !status.isPlaylistManagerInstalled) {
      throw StateError('Temp Beat Saber directory was not detected correctly.');
    }
    final validSongs = await countValidInstalledSongs(
      status.customLevelsDirectory,
    );
    if (validSongs != 2) {
      throw StateError('Expected 2 valid CustomLevels songs, got $validSongs.');
    }

    final foldersFile = status.songCoreFoldersFile;
    await foldersFile.parent.create(recursive: true);
    final normalizedCustomLevels = p.normalize(p.absolute(customLevels.path));
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders version="2">
  <folder>
    <Name>CustomLevels</Name>
    <Path>$normalizedCustomLevels</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');

    final externalPack = await Directory(
      p.join(tempRoot.path, 'External Packs', 'Favorites & Ranked'),
    ).create(recursive: true);
    await _createSong(externalPack, 'ghi - External', 'External');
    final cover = await File(
      p.join(tempRoot.path, 'External Packs', 'cover.png'),
    ).create(recursive: true);

    final saveResult = await saveSongCoreFolderEntry(
      gameDirectory: game,
      songFolder: externalPack,
      name: 'Favorites & Ranked',
      imageFile: cover,
    );
    if (!saveResult.added ||
        saveResult.updated ||
        saveResult.backupFile == null ||
        !await saveResult.backupFile!.exists()) {
      throw StateError('SongCore save did not add and backup as expected.');
    }
    final expectedBackupDirectory = Directory(
      p.join(foldersFile.parent.path, 'backups'),
    );
    if (p.normalize(saveResult.backupFile!.parent.path) !=
        p.normalize(expectedBackupDirectory.path)) {
      throw StateError('SongCore save backup directory is not as expected.');
    }

    var entries = await readSongCoreFolderEntries(foldersFile);
    final externalEntry = entries.firstWhere(
      (entry) => entry.name == 'Favorites & Ranked',
    );
    if (!entries.any((entry) => entry.name == 'CustomLevels') ||
        externalEntry.path != p.normalize(p.absolute(externalPack.path))) {
      throw StateError('Saved SongCore entries are not as expected.');
    }
    final savedXml = await foldersFile.readAsString();
    if (!savedXml.contains('<CustomSort pinned="true">1</CustomSort>') ||
        !savedXml.contains('Favorites &amp; Ranked')) {
      throw StateError(
          'SongCore XML did not preserve unknown fields/name escaping.');
    }

    final removeResult = await removeSongCoreFolderEntries(
      file: foldersFile,
      keys: [songCoreFolderEntryKey(externalEntry)],
    );
    if (removeResult.removed != 1 ||
        removeResult.backupFile == null ||
        !await removeResult.backupFile!.exists()) {
      throw StateError('SongCore remove did not backup/remove as expected.');
    }
    if (p.normalize(removeResult.backupFile!.parent.path) !=
        p.normalize(expectedBackupDirectory.path)) {
      throw StateError('SongCore remove backup directory is not as expected.');
    }
    final backupFiles = await expectedBackupDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.xml'))
        .toList();
    if (backupFiles.length < 2) {
      throw StateError(
        'Expected save and remove to leave at least 2 backup XML files, '
        'got ${backupFiles.length}.',
      );
    }
    if (!await externalPack.exists()) {
      throw StateError('External song pack directory was deleted.');
    }
    entries = await readSongCoreFolderEntries(foldersFile);
    if (entries.length != 1 || entries.single.name != 'CustomLevels') {
      throw StateError('SongCore entries after remove are not as expected.');
    }
    final removedXml = await foldersFile.readAsString();
    if (!removedXml.contains('<CustomSort pinned="true">1</CustomSort>') ||
        removedXml.contains('Favorites &amp; Ranked')) {
      throw StateError('SongCore XML after remove is not as expected.');
    }

    print('tempRoot=${tempRoot.path}');
    print('game=${game.path}');
    print('validSongs=$validSongs');
    print(
        'save added=${saveResult.added} backup=${saveResult.backupFile!.path}');
    print(
        'remove removed=${removeResult.removed} backup=${removeResult.backupFile!.path}');
    print('backupDirectory=${expectedBackupDirectory.path}');
    print('backupFiles=${backupFiles.length}');
    print('externalPackStillExists=${await externalPack.exists()}');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
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
  dart run tool\songcore_operation_smoke.dart [options]

Options:
  --keep-temp   Keep the temp Beat Saber directory after the smoke run.
  --help, -h    Show this help.

The script creates a temporary Beat Saber-shaped directory, saves an external
SongCore folder entry, reads it back, removes it from folders.xml, and verifies
that the external song pack directory still exists. It never touches a real
Beat Saber installation.
''';
