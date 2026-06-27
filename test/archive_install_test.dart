import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('extracts archive bytes into the target directory', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final archive = Archive()
      ..addFile(
        ArchiveFile('song.txt', 4, 'test'.codeUnits),
      );
    final bytes = ZipEncoder().encode(archive);

    await extractZipBytesToDirectory(bytes, tempDir);

    final extracted = File(
      '${tempDir.path}${Platform.pathSeparator}song.txt',
    );
    expect(await extracted.exists(), isTrue);
    expect(await extracted.readAsString(), 'test');
  });

  test('blocks archive entries outside the target directory', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final archive = Archive()
      ..addFile(
        ArchiveFile('../outside.txt', 4, 'test'.codeUnits),
      );
    final bytes = ZipEncoder().encode(archive);

    expect(
      () => extractZipBytesToDirectory(bytes, tempDir),
      throwsA(isA<FormatException>()),
    );
  });

  test('finds installed map directory by id and info.dat', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Song',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{}');

    final found = await findInstalledMapDirectory(_testMap(), tempDir);

    expect(found?.path, songDir.path);
  });

  test('finds installed map directory in extra skip directories', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    final skipDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_skip_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (await skipDir.exists()) {
        await skipDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${skipDir.path}${Platform.pathSeparator}abc - Existing',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{}');

    final found = await findInstalledMapDirectory(
      _testMap(),
      tempDir,
      extraDirectories: [skipDir],
    );

    expect(found?.path, songDir.path);
  });

  test('builds installed song directory names from templates', () {
    expect(installedSongDirectoryName(_testMap()), 'abc - Song');
    expect(
      installedSongDirectoryName(
        _testMap(),
        template: '[bsr] ([歌名] - [作者])',
      ),
      'abc (Song - Artist)',
    );
    expect(
      installedSongDirectoryName(
        _testMap(),
        template: '[歌名]<>[制作者] [bpm]',
      ),
      'Song__Mapper 180',
    );
  });

  test('builds ascii-only installed song directory names', () {
    expect(
      installedSongDirectoryName(
        _testMap(
          name: '备用名',
          songName: '歌曲名',
          songAuthorName: '作者',
          levelAuthorName: '制作者',
        ),
        template: '[id] - [歌名] - [作者] - [制作者]',
        asciiOnly: true,
      ),
      'abc - ___ - __ - ___',
    );
  });

  test('parses installed directory names with custom templates', () {
    expect(parseInstalledDirectoryName('abc - Song').mapId, 'abc');
    expect(parseInstalledDirectoryName('abc (Song - Artist)').mapId, 'abc');
    expect(parseInstalledDirectoryName('abc_Song').mapId, 'abc');
    expect(parseInstalledDirectoryName('not-a-map').mapId, isNull);
  });

  test('finds installed map directory with custom template name', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc (Song - Artist)',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{}');

    final found = await findInstalledMapDirectory(_testMap(), tempDir);

    expect(found?.path, songDir.path);
  });

  test('scans installed library entries', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Song',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('''
{
  "_songName": "Real Song",
  "_songAuthorName": "Artist",
  "_levelAuthorName": "Mapper",
  "_beatsPerMinute": 180
}
''');

    final entries = await scanInstalledLibrary(tempDir);

    expect(entries, hasLength(1));
    expect(entries.single.mapId, 'abc');
    expect(entries.single.title, 'Real Song');
    expect(entries.single.hasInfoDat, isTrue);
    expect(entries.single.info?.songAuthorName, 'Artist');
    expect(entries.single.info?.levelAuthorName, 'Mapper');
    expect(entries.single.info?.beatsPerMinute, 180);
  });

  test('parses modern info.dat field names', () {
    final info = InstalledSongInfo.fromJson({
      'songName': 'Modern Song',
      'songAuthorName': 'Modern Artist',
      'levelAuthorName': 'Modern Mapper',
      'beatsPerMinute': '160',
    });

    expect(info.songName, 'Modern Song');
    expect(info.songAuthorName, 'Modern Artist');
    expect(info.levelAuthorName, 'Modern Mapper');
    expect(info.beatsPerMinute, 160);
  });

  test('deletes installed map by id', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Song',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{}');

    final deleted = await deleteInstalledMapById(tempDir, 'ABC');

    expect(deleted?.mapId, 'abc');
    expect(await songDir.exists(), isFalse);
  });

  test('does not delete matching directory without info.dat', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Song',
    );
    await songDir.create(recursive: true);

    final deleted = await deleteInstalledMapById(tempDir, 'abc');

    expect(deleted, isNull);
    expect(await songDir.exists(), isTrue);
  });

  test('exports installed maps to bplist', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Song',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('''
{
  "_songName": "Song",
  "_songAuthorName": "Artist",
  "_levelAuthorName": "Mapper",
  "_beatsPerMinute": 180
}
''');

    final outputFile = File(
      '${tempDir.path}${Platform.pathSeparator}playlists'
      '${Platform.pathSeparator}songs.bplist',
    );
    await exportBplist(
      libraryDirectory: tempDir,
      outputFile: outputFile,
      playlistTitle: 'My Songs',
      playlistImage: 'data:image/jpeg;base64,abc',
    );

    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['playlistTitle'], 'My Songs');
    expect(decoded['playlistAuthor'], 'My Songs - BeatSpider@WGzeyu');
    expect(
      decoded['playlistDescription'],
      contains('BeatSpider是由WGzeyu制作的用于生成与整理曲包的免费软件'),
    );
    expect(decoded['image'], 'data:image/jpeg;base64,abc');
    expect(decoded['songs'], [
      {'key': 'abc', 'songName': 'Song'},
    ]);
  });

  test('exports selected installed entries to bplist', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final outputFile = File(
      '${tempDir.path}${Platform.pathSeparator}selected.bplist',
    );
    await exportBplistFromInstalledEntries(
      entries: [
        InstalledSongEntry(
          directory: Directory('installed/abc - Song'),
          directoryName: 'abc - Song',
          hasInfoDat: true,
          info: const InstalledSongInfo(
            songName: 'Song',
            songSubName: '',
            songAuthorName: 'Artist',
            levelAuthorName: 'Mapper',
            beatsPerMinute: 180,
          ),
          mapId: 'abc',
          title: 'Song',
        ),
        InstalledSongEntry(
          directory: Directory('installed/noid - Other'),
          directoryName: 'noid - Other',
          hasInfoDat: true,
          info: const InstalledSongInfo(
            songName: 'Other',
            songSubName: '',
            songAuthorName: '',
            levelAuthorName: '',
            beatsPerMinute: 0,
          ),
        ),
        InstalledSongEntry(
          directory: Directory('installed/def - Missing Info'),
          directoryName: 'def - Missing Info',
          hasInfoDat: false,
          mapId: 'def',
          title: 'Missing Info',
        ),
      ],
      outputFile: outputFile,
      playlistTitle: 'Filtered',
      playlistAuthor: 'Tester',
      playlistDescription: 'Filtered export',
      playlistImage: 'data:image/png;base64,abc',
    );

    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['playlistTitle'], 'Filtered');
    expect(decoded['playlistAuthor'], 'Tester');
    expect(decoded['playlistDescription'], 'Filtered export');
    expect(decoded['image'], 'data:image/png;base64,abc');
    expect(decoded['songs'], [
      {'key': 'abc', 'songName': 'Song'},
    ]);
  });

  test('exports scanned installed entries to bplist', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final first = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - First',
    );
    await first.create(recursive: true);
    await File('${first.path}${Platform.pathSeparator}Info.dat').writeAsString(
      '{"_songName":"First","_coverImageFilename":"cover.png"}',
    );
    await File('${first.path}${Platform.pathSeparator}cover.png')
        .writeAsBytes([1, 2, 3, 4]);

    final noId = Directory(
      '${tempDir.path}${Platform.pathSeparator}No Id Song',
    );
    await noId.create(recursive: true);
    await File('${noId.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"No Id"}');

    final missingInfo = Directory(
      '${tempDir.path}${Platform.pathSeparator}def - Missing Info',
    );
    await missingInfo.create(recursive: true);

    final entries = await scanInstalledLibrary(tempDir);
    final outputFile = File(
      '${tempDir.path}${Platform.pathSeparator}filtered.bplist',
    );

    await exportBplistFromInstalledEntries(
      entries: entries,
      outputFile: outputFile,
      playlistTitle: 'Scanned',
    );

    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['playlistTitle'], 'Scanned');
    expect(decoded['image'], 'data:image/png;base64,AQIDBA==');
    expect(decoded['songs'], [
      {'key': 'abc', 'songName': 'First'},
    ]);
  });

  test('exports favorite hashes from PlayerData to bplist', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const hashA = '0123456789abcdef0123456789abcdef01234567';
    const hashB = 'abcdef0123456789abcdef0123456789abcdef01';
    final playerData = File(
      '${tempDir.path}${Platform.pathSeparator}PlayerData.dat',
    );
    await playerData.writeAsString(
      jsonEncode({
        'localPlayers': [
          {
            'favoritesLevelIds': [
              'custom_level_$hashA',
              'CUSTOM_LEVEL_$hashA',
              hashB,
              'custom_level_invalid',
            ],
          },
        ],
      }),
    );

    final hashes = await readFavoriteHashesFromPlayerData(playerData);
    expect(hashes, [hashA, hashB]);

    final outputFile = File(
      '${tempDir.path}${Platform.pathSeparator}favorites.bplist',
    );
    await exportFavoriteHashesBplist(
      hashes: hashes,
      outputFile: outputFile,
      playlistImage: 'data:image/jpeg;base64,abc',
    );

    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['playlistTitle'], '导出收藏歌曲');
    expect(decoded['playlistAuthor'], '导出收藏歌曲 - BSSFM@WGzeyu');
    expect(
      decoded['PlaylistDescription'],
      contains('BeatSaberSongFolderManager(BS歌曲路径管理器)'),
    );
    expect(decoded['image'], 'data:image/jpeg;base64,abc');
    expect(decoded['songs'], [
      {'hash': hashA},
      {'hash': hashB},
    ]);
  });

  test('reads favorite hashes from multiple PlayerData players in order',
      () async {
    const hashA = '0123456789abcdef0123456789abcdef01234567';
    const hashB = 'abcdef0123456789abcdef0123456789abcdef01';
    const hashC = '1111111111111111111111111111111111111111';

    final hashes = favoriteHashesFromPlayerDataJson({
      'localPlayers': [
        {
          'favoritesLevelIds': [
            'custom_level_$hashA',
            'custom_level_$hashB',
          ],
        },
        {
          'favoritesLevelIds': [
            'CUSTOM_LEVEL_$hashA',
            'custom_level_$hashC',
            'custom_level_invalid',
          ],
        },
      ],
    });

    expect(hashes, [hashA, hashB, hashC]);
  });

  test('reads bplist map keys', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}${Platform.pathSeparator}songs.bplist');
    await file.writeAsString('''
{
  "playlistTitle": "My Songs",
  "songs": [
    {"key": "abc"},
    {"key": "ABC"},
    {"hash": "ignored"},
    {"key": ""}
  ]
}
''');

    final playlist = await readBplist(file);

    expect(playlist.title, 'My Songs');
    expect(playlist.mapIds, ['abc', 'ABC']);
    expect(
        playlist.entries.map((entry) => entry.hash), ['', '', 'ignored', '']);
  });

  test('exports installed songs to a zip archive', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Song',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Song"}');
    await File('${songDir.path}${Platform.pathSeparator}song.egg')
        .writeAsString('audio');

    final ignoredDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}ignored - No Info',
    );
    await ignoredDir.create(recursive: true);
    await File('${ignoredDir.path}${Platform.pathSeparator}song.egg')
        .writeAsString('ignored');

    final outputFile = File(
      '${tempDir.path}${Platform.pathSeparator}export'
      '${Platform.pathSeparator}songs.zip',
    );

    await exportInstalledSongsZip(
      libraryDirectory: tempDir,
      outputFile: outputFile,
    );

    final archive = ZipDecoder().decodeBytes(await outputFile.readAsBytes());
    final names = archive.files.map((file) => file.name).toList();

    expect(names, contains('abc - Song/info.dat'));
    expect(names, contains('abc - Song/song.egg'));
    expect(names, isNot(contains('ignored - No Info/song.egg')));
  });
}

BeatSaverMap _testMap({
  String name = 'Song',
  String songName = 'Song',
  String songAuthorName = 'Artist',
  String levelAuthorName = 'Mapper',
}) {
  return BeatSaverMap(
    id: 'abc',
    name: name,
    description: '',
    metadata: BeatSaverMetadata(
      songName: songName,
      songSubName: '',
      songAuthorName: songAuthorName,
      levelAuthorName: levelAuthorName,
      bpm: 180,
      durationSeconds: 120,
    ),
    stats: const BeatSaverStats(
      downloads: 0,
      plays: 0,
      upvotes: 0,
      downvotes: 0,
      score: 0,
      reviews: 0,
    ),
    versions: const [],
  );
}
