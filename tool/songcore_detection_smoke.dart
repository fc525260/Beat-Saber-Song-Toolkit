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
    'beat_saber_song_toolkit_songcore_detection_',
  );

  try {
    final invalid = await Directory(p.join(tempRoot.path, 'Not Beat Saber'))
        .create(recursive: true);
    _expectStatus(
      label: 'invalid',
      status: inspectBeatSaberGameDirectory(invalid),
      beatSaber: false,
      songCore: false,
      playlistManager: false,
    );

    final noMods = await _createBeatSaberShape(
      tempRoot,
      'Beat Saber No Mods',
      songCore: false,
      playlistManager: false,
    );
    _expectStatus(
      label: 'noMods',
      status: inspectBeatSaberGameDirectory(noMods),
      beatSaber: true,
      songCore: false,
      playlistManager: false,
    );

    final songCoreOnly = await _createBeatSaberShape(
      tempRoot,
      'Beat Saber SongCore Only',
      songCore: true,
      playlistManager: false,
    );
    _expectStatus(
      label: 'songCoreOnly',
      status: inspectBeatSaberGameDirectory(songCoreOnly),
      beatSaber: true,
      songCore: true,
      playlistManager: false,
    );

    final fullMods = await _createBeatSaberShape(
      tempRoot,
      'Beat Saber Full Mods',
      songCore: true,
      playlistManager: true,
    );
    final fullStatus = inspectBeatSaberGameDirectory(fullMods);
    _expectStatus(
      label: 'fullMods',
      status: fullStatus,
      beatSaber: true,
      songCore: true,
      playlistManager: true,
    );

    print('tempRoot=${tempRoot.path}');
    print('invalid beatSaber=false songCore=false playlistManager=false');
    print('noMods beatSaber=true songCore=false playlistManager=false');
    print('songCoreOnly beatSaber=true songCore=true playlistManager=false');
    print('fullMods beatSaber=true songCore=true playlistManager=true');
    print('foldersFile=${fullStatus.songCoreFoldersFile.path}');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<Directory> _createBeatSaberShape(
  Directory tempRoot,
  String name, {
  required bool songCore,
  required bool playlistManager,
}) async {
  final game = await Directory(p.join(tempRoot.path, name)).create();
  await File(p.join(game.path, 'Beat Saber.exe')).create();
  await Directory(p.join(game.path, 'Beat Saber_Data')).create();
  if (songCore || playlistManager) {
    final plugins = await Directory(p.join(game.path, 'Plugins')).create();
    if (songCore) {
      await File(p.join(plugins.path, 'SongCore.dll')).create();
    }
    if (playlistManager) {
      await File(p.join(plugins.path, 'PlaylistManager.dll')).create();
    }
  }
  return game;
}

void _expectStatus({
  required String label,
  required BeatSaberGameDirectoryStatus status,
  required bool beatSaber,
  required bool songCore,
  required bool playlistManager,
}) {
  if (status.isBeatSaberDirectory != beatSaber ||
      status.isSongCoreInstalled != songCore ||
      status.isPlaylistManagerInstalled != playlistManager) {
    throw StateError(
      '$label status mismatch: '
      'beatSaber=${status.isBeatSaberDirectory}, '
      'songCore=${status.isSongCoreInstalled}, '
      'playlistManager=${status.isPlaylistManagerInstalled}.',
    );
  }
}

const _usage = r'''
Usage:
  dart run tool\songcore_detection_smoke.dart [options]

Options:
  --keep-temp   Keep the temp directories after the smoke run.
  --help, -h    Show this help.

The script creates temporary directory shapes for invalid folders, Beat Saber
without mods, Beat Saber with only SongCore, and Beat Saber with SongCore plus
PlaylistManager. It verifies detection only and never writes folders.xml.
''';
