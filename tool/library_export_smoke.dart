import 'dart:convert';
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
    'beat_saber_song_toolkit_library_export_smoke_',
  );

  try {
    final library = await Directory(
      p.join(tempRoot.path, 'CustomLevels'),
    ).create();
    await _createSong(
      library,
      'abc - Exported',
      id: 'abc',
      songName: 'Exported Song',
      coverFilename: 'cover.png',
      coverBytes: [1, 2, 3, 4],
    );
    await _createSong(
      library,
      'No Id Song',
      songName: 'No Id Song',
    );
    await Directory(p.join(library.path, 'def - Missing Info')).create();

    final entries = await scanInstalledLibrary(library);
    final libraryBplist = File(p.join(tempRoot.path, 'library.bplist'));
    await exportBplistFromInstalledEntries(
      entries: entries,
      outputFile: libraryBplist,
      playlistTitle: 'Smoke Library',
      playlistAuthor: 'Smoke Tester',
      playlistDescription: 'Installed library export smoke',
    );
    final libraryJson = await _readJsonObject(libraryBplist);
    final librarySongs = _songs(libraryJson);
    if (libraryJson['playlistTitle'] != 'Smoke Library' ||
        libraryJson['playlistAuthor'] != 'Smoke Tester' ||
        libraryJson['image'] != 'data:image/png;base64,AQIDBA==' ||
        librarySongs.length != 1 ||
        librarySongs.single['key'] != 'abc' ||
        librarySongs.single['songName'] != 'Exported Song') {
      throw StateError('Installed library bplist export is not as expected.');
    }

    const hashA = '0123456789abcdef0123456789abcdef01234567';
    const hashB = 'abcdef0123456789abcdef0123456789abcdef01';
    const hashC = '1111111111111111111111111111111111111111';
    final playerData = File(p.join(tempRoot.path, 'PlayerData.dat'));
    await playerData.writeAsString(
      jsonEncode({
        'localPlayers': [
          {
            'favoritesLevelIds': [
              'custom_level_$hashA',
              'CUSTOM_LEVEL_$hashA',
              'custom_level_invalid',
              hashB,
            ],
          },
          {
            'favoritesLevelIds': [
              'custom_level_$hashC',
              'custom_level_$hashB',
            ],
          },
        ],
      }),
      flush: true,
    );
    final favoriteHashes = await readFavoriteHashesFromPlayerData(playerData);
    if (favoriteHashes.join('|') != '$hashA|$hashB|$hashC') {
      throw StateError(
        'Favorite hash parsing order/dedup failed: '
        '${favoriteHashes.join(', ')}.',
      );
    }

    final favoritesBplist = File(p.join(tempRoot.path, 'favorites.bplist'));
    await exportFavoriteHashesBplist(
      hashes: favoriteHashes,
      outputFile: favoritesBplist,
      playlistTitle: 'Smoke Favorites',
      playlistImage: 'data:image/jpeg;base64,abc',
    );
    final favoritesJson = await _readJsonObject(favoritesBplist);
    final favoriteSongs = _songs(favoritesJson);
    final exportedHashes =
        favoriteSongs.map((song) => song['hash']?.toString() ?? '').join('|');
    if (favoritesJson['playlistTitle'] != 'Smoke Favorites' ||
        favoritesJson['playlistAuthor'] != 'Smoke Favorites - BSSFM@WGzeyu' ||
        exportedHashes != '$hashA|$hashB|$hashC') {
      throw StateError('Favorite bplist export is not as expected.');
    }

    print('tempRoot=${tempRoot.path}');
    print('library=${library.path}');
    print('installedEntries=${entries.length}');
    print('libraryBplist=${libraryBplist.path}');
    print('libraryExportedSongs=${librarySongs.length}');
    print(
        'libraryExportedKeys=${librarySongs.map((song) => song['key']).join(',')}');
    print('playerData=${playerData.path}');
    print('favoriteHashes=${favoriteHashes.length}');
    print('favoritesBplist=${favoritesBplist.path}');
    print('favoriteExportedHashes=${favoriteSongs.length}');
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
  String? id,
  required String songName,
  String? coverFilename,
  List<int>? coverBytes,
}) async {
  final songDir = await Directory(p.join(parent.path, directoryName)).create();
  final coverLine = coverFilename == null
      ? ''
      : ',\n  "_coverImageFilename": "$coverFilename"';
  await File(p.join(songDir.path, 'Info.dat')).writeAsString('''
{
  "_songName": "$songName",
  "_songAuthorName": "Artist",
  "_levelAuthorName": "Mapper",
  "_beatsPerMinute": 128$coverLine
}
''', flush: true);
  await File(p.join(songDir.path, 'song.egg')).writeAsString('audio');
  if (coverFilename != null && coverBytes != null) {
    await File(p.join(songDir.path, coverFilename)).writeAsBytes(coverBytes);
  }
  if (id != null) {
    await File(p.join(songDir.path, '$id.dat')).writeAsString('{}');
  }
  return songDir;
}

Future<Map<String, dynamic>> _readJsonObject(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Expected JSON object in ${file.path}.');
  }
  return decoded;
}

List<Map<String, dynamic>> _songs(Map<String, dynamic> json) {
  final songs = json['songs'];
  if (songs is! List) {
    throw StateError('Expected songs array.');
  }
  return songs.whereType<Map<String, dynamic>>().toList(growable: false);
}

const _usage = r'''
Usage:
  dart run tool\library_export_smoke.dart [options]

Options:
  --keep-temp   Keep the temp library and exported bplist files.
  --help, -h    Show this help.

The script creates a temporary CustomLevels-shaped library, exports the
exportable installed songs to bplist, parses a temporary PlayerData.dat
favorites file, exports the favorite hashes to bplist, and verifies both JSON
outputs. It never touches a real Beat Saber installation or the real sample
directory.
''';
