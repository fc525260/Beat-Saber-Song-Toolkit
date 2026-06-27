import 'dart:io';
import 'dart:convert';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('compares bplist entries with installed songs by id and name', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final idMatch = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Id Match',
    );
    await idMatch.create(recursive: true);
    await File('${idMatch.path}${Platform.pathSeparator}info.dat')
        .writeAsString('''
{
  "_songName": "Id Match",
  "_songAuthorName": "Artist",
  "_difficultyBeatmapSets": [
    {
      "_difficultyBeatmaps": [
        {"_difficulty": "Hard"},
        {"_difficulty": "ExpertPlus"}
      ]
    }
  ]
}
''');
    await File('${idMatch.path}${Platform.pathSeparator}song.egg')
        .writeAsString('audio');

    final nameMatch = Directory(
      '${tempDir.path}${Platform.pathSeparator}noid - Name Match',
    );
    await nameMatch.create(recursive: true);
    await File('${nameMatch.path}${Platform.pathSeparator}info.dat')
        .writeAsString('''
{
  "_songName": "Name Match",
  "_songAuthorName": "Artist"
}
''');

    final playlist = BplistPlaylist(
      title: 'Sync',
      entries: const [
        BplistSongEntry(key: 'ABC', hash: 'HASH1'),
        BplistSongEntry(key: '', hash: 'HASH2'),
        BplistSongEntry(key: '', hash: 'HASH3'),
      ],
    );

    final result = await comparePlaylistWithInstalledLibrary(
      playlist: playlist,
      libraryDirectory: tempDir,
      hashDetails: const {
        'hash2': BeatSaverHashDetail(
          id: 'def',
          name: 'NameMatch',
          description: 'from cache',
        ),
      },
    );

    expect(result, hasLength(3));
    expect(result[0].matchType, PlaylistSyncMatchType.mapId);
    expect(result[0].installedEntry?.mapId, 'abc');
    expect(result[0].hasEgg, isTrue);
    expect(result[0].installedEntry?.info?.difficulties, [
      'ExpertPlus',
      'Hard',
    ]);

    expect(result[1].matchType, PlaylistSyncMatchType.normalizedName);
    expect(result[1].beatSaverDetail?.id, 'def');
    expect(result[1].installedEntry?.info?.songName, 'Name Match');
    expect(result[1].hasEgg, isFalse);

    expect(result[2].matchType, PlaylistSyncMatchType.missing);
    expect(result[2].isInstalled, isFalse);
  });

  test('compares hash-only bplist entries with installed song hash', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}1001c (Hash Only)',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}Info.dat')
        .writeAsString('''
{
  "_songName": "Hash Only",
  "_songAuthorName": "Artist",
  "_difficultyBeatmapSets": [
    {
      "_difficultyBeatmaps": [
        {
          "_difficulty": "Normal",
          "_beatmapFilename": "NormalStandard.dat"
        }
      ]
    }
  ]
}
''');
    await File('${songDir.path}${Platform.pathSeparator}NormalStandard.dat')
        .writeAsString('{"_notes":[]}');
    await File('${songDir.path}${Platform.pathSeparator}song.egg')
        .writeAsString('audio');
    final extraDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}1002d (Local Only)',
    );
    await extraDir.create(recursive: true);
    await File('${extraDir.path}${Platform.pathSeparator}Info.dat')
        .writeAsString('''
{
  "_songName": "Local Only",
  "_difficultyBeatmapSets": [
    {
      "_difficultyBeatmaps": [
        {
          "_difficulty": "Normal",
          "_beatmapFilename": "NormalStandard.dat"
        }
      ]
    }
  ]
}
''');
    await File('${extraDir.path}${Platform.pathSeparator}NormalStandard.dat')
        .writeAsString('{"_notes":[{"_time":1}]}');

    final hash = await computeInstalledSongHash(songDir);
    expect(hash, '5b4eb89e6e28377a1dab1c96d1fd5689c175b8a9');

    final comparison = await comparePlaylistWithInstalledLibraryDetailed(
      playlist: BplistPlaylist(
        title: 'Hash Sync',
        entries: [BplistSongEntry(key: '', hash: hash!)],
      ),
      libraryDirectory: tempDir,
    );
    final result = comparison.entries;

    expect(result, hasLength(1));
    expect(result.single.matchType, PlaylistSyncMatchType.localHash);
    expect(result.single.installedEntry?.directoryName, '1001c (Hash Only)');
    expect(result.single.hasEgg, isTrue);
    expect(
      comparison.localOnlyInstalledEntries.map((entry) => entry.directoryName),
      ['1002d (Local Only)'],
    );
  });

  test('removes selected entries from bplist while preserving metadata',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "playlistAuthor": "Author",
  "image": "data:image/jpeg;base64,abc",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'ABC', hash: 'HASH1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 1);
    expect(decoded['playlistTitle'], 'Sync');
    expect(decoded['playlistAuthor'], 'Author');
    expect(decoded['image'], 'data:image/jpeg;base64,abc');
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'hash2', 'songName': 'Keep'},
    ]);
  });

  test('removes hash-only selected entries from bplist', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Hash Sync",
  "songs": [
    {"hash": "hash1", "songName": "Remove by hash"},
    {"key": "abc", "hash": "hash2", "songName": "Keep by key"},
    {"hash": "hash3", "songName": "Keep by hash"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: 'HASH1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 1);
    expect(decoded['songs'], [
      {'key': 'abc', 'hash': 'hash2', 'songName': 'Keep by key'},
      {'hash': 'hash3', 'songName': 'Keep by hash'},
    ]);
  });

  test('keeps non object bplist song entries when removing selected entries',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Mixed Sync",
  "songs": [
    "raw string",
    42,
    null,
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 1);
    expect(decoded['songs'], [
      'raw string',
      42,
      null,
      {'key': 'def', 'hash': 'hash2', 'songName': 'Keep'},
    ]);
  });

  test('does not rewrite bplist when songs is missing or not a list', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final missingSongsFile = File(
      '${tempDir.path}${Platform.pathSeparator}missing.bplist',
    );
    const missingSongsJson = '''
{"playlistTitle":"Missing Songs","customData":{"keep":true}}
''';
    await missingSongsFile.writeAsString(missingSongsJson);

    final objectSongsFile = File(
      '${tempDir.path}${Platform.pathSeparator}object.bplist',
    );
    const objectSongsJson = '''
{"playlistTitle":"Object Songs","songs":{"key":"abc","hash":"hash1"}}
''';
    await objectSongsFile.writeAsString(objectSongsJson);

    const selected = [
      PlaylistSyncEntry(
        playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
        beatSaverDetail: null,
        installedEntry: null,
        matchType: PlaylistSyncMatchType.missing,
        hasEgg: false,
      ),
    ];

    expect(
      await removePlaylistSyncEntriesFromBplist(
        playlistFile: missingSongsFile,
        entries: selected,
      ),
      0,
    );
    expect(await missingSongsFile.readAsString(), missingSongsJson);
    expect(
      await removePlaylistSyncEntriesFromBplist(
        playlistFile: objectSongsFile,
        entries: selected,
      ),
      0,
    );
    expect(await objectSongsFile.readAsString(), objectSongsJson);
  });

  test('does not rewrite bplist when no selected entries match', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{"playlistTitle":"No Match","songs":[{"key":"abc","hash":"hash1"}]}
''';
    await playlistFile.writeAsString(playlistJson);

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'missing', hash: 'hash2'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    expect(removed, 0);
    expect(await playlistFile.readAsString(), playlistJson);
  });

  test('does not remove different keyed entries with the same hash', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Duplicate Hash Sync",
  "songs": [
    {"key": "abc", "hash": "samehash", "songName": "Remove by key"},
    {"key": "def", "hash": "samehash", "songName": "Keep different key"},
    {"hash": "samehash", "songName": "Keep hash only"},
    {"hash": "hash2", "songName": "Keep other hash"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'ABC', hash: 'SAMEHASH'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 1);
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'samehash', 'songName': 'Keep different key'},
      {'hash': 'samehash', 'songName': 'Keep hash only'},
      {'hash': 'hash2', 'songName': 'Keep other hash'},
    ]);
  });

  test('does not remove same-key entries with different hashes', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Same Key Sync",
  "songs": [
    {"key": "abc", "hash": "oldhash", "songName": "Keep old hash"},
    {"key": "abc", "hash": "newhash", "songName": "Remove new hash"},
    {"key": "def", "hash": "newhash", "songName": "Keep different key"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'ABC', hash: 'NEWHASH'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 1);
    expect(decoded['songs'], [
      {'key': 'abc', 'hash': 'oldhash', 'songName': 'Keep old hash'},
      {'key': 'def', 'hash': 'newhash', 'songName': 'Keep different key'},
    ]);
  });

  test('key-only removal keeps legacy same-key matching', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Key Only Sync",
  "songs": [
    {"key": "abc", "hash": "oldhash", "songName": "Remove old hash"},
    {"key": "abc", "hash": "newhash", "songName": "Remove new hash"},
    {"key": "def", "hash": "newhash", "songName": "Keep different key"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'ABC', hash: ''),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 2);
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'newhash', 'songName': 'Keep different key'},
    ]);
  });

  test('hash-only removal does not remove keyed entries with the same hash',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Hash Only Sync",
  "songs": [
    {"key": "abc", "hash": "samehash", "songName": "Keep keyed"},
    {"hash": "samehash", "songName": "Remove hash only"},
    {"hash": "hash2", "songName": "Keep other hash"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: 'SAMEHASH'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 1);
    expect(decoded['songs'], [
      {'key': 'abc', 'hash': 'samehash', 'songName': 'Keep keyed'},
      {'hash': 'hash2', 'songName': 'Keep other hash'},
    ]);
  });

  test(
      'combined key and hash-only removal keeps different keyed same-hash rows',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Combined Sync",
  "songs": [
    {"key": "abc", "hash": "samehash", "songName": "Remove keyed"},
    {"key": "def", "hash": "samehash", "songName": "Keep different key"},
    {"hash": "samehash", "songName": "Remove hash only"},
    {"hash": "otherhash", "songName": "Keep other hash"}
  ]
}
''');

    final removed = await removePlaylistSyncEntriesFromBplist(
      playlistFile: playlistFile,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'ABC', hash: 'SAMEHASH'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: 'SAMEHASH'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(removed, 2);
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'samehash', 'songName': 'Keep different key'},
      {'hash': 'otherhash', 'songName': 'Keep other hash'},
    ]);
  });

  test('backs up playlist and installed songs before deleting sync entries',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''');

    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    );
    await songDir.create(recursive: true);
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    await File('${songDir.path}${Platform.pathSeparator}song.egg')
        .writeAsString('audio');
    final nestedDir = await Directory(
      '${songDir.path}${Platform.pathSeparator}CustomData',
    ).create();
    await File('${nestedDir.path}${Platform.pathSeparator}cover.json')
        .writeAsString('{"cover":true}');

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: const BeatSaverHashDetail(
            id: 'abc',
            name: 'Remove',
            description: '',
          ),
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: true,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.deleted, 1);
    expect(result.removedPlaylistEntries, 1);
    expect(await result.playlistBackup!.exists(), isTrue);
    expect(result.songBackups, hasLength(1));
    expect(
      await File(
        '${result.songBackups.single.path}${Platform.pathSeparator}song.egg',
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        '${result.songBackups.single.path}${Platform.pathSeparator}'
        'CustomData${Platform.pathSeparator}cover.json',
      ).readAsString(),
      '{"cover":true}',
    );
    expect(await songDir.exists(), isFalse);

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'hash2', 'songName': 'Keep'},
    ]);
  });

  test('deduplicates repeated selected entries before backup delete', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"}
  ]
}
''');

    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final entry = PlaylistSyncEntry(
      playlistEntry: const BplistSongEntry(key: 'ABC', hash: 'HASH1'),
      beatSaverDetail: null,
      installedEntry: InstalledSongEntry(
        directory: songDir,
        directoryName: 'abc - Remove',
        hasInfoDat: true,
        info: const InstalledSongInfo(
          songName: 'Remove',
          songSubName: '',
          songAuthorName: '',
          levelAuthorName: '',
          beatsPerMinute: 0,
        ),
        mapId: 'abc',
        title: 'Remove',
      ),
      matchType: PlaylistSyncMatchType.mapId,
      hasEgg: false,
    );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [entry, entry],
    );

    expect(result.requested, 2);
    expect(result.deleted, 1);
    expect(result.removedPlaylistEntries, 1);
    expect(result.songBackups, hasLength(1));
    expect(await songDir.exists(), isFalse);
  });

  test('does not back up the same installed directory twice', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove A"},
    {"key": "def", "hash": "hash2", "songName": "Remove B"}
  ]
}
''');

    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}shared - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');

    PlaylistSyncEntry selected(String key, String hash) => PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: key, hash: hash),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'shared - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: key,
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [
        selected('abc', 'hash1'),
        selected('def', 'hash2'),
      ],
    );

    expect(result.requested, 2);
    expect(result.deleted, 1);
    expect(result.removedPlaylistEntries, 2);
    expect(result.songBackups, hasLength(1));
    expect(await songDir.exists(), isFalse);
    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], isEmpty);
  });

  test('does not delete installed directories whose playlist rows are gone',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"}
  ]
}
''');

    final presentDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${presentDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final staleDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}def - Stale',
    ).create();
    await File('${staleDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Stale"}');

    PlaylistSyncEntry selected({
      required String key,
      required String hash,
      required Directory directory,
      required String title,
    }) =>
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: key, hash: hash),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: directory,
            directoryName: directory.uri.pathSegments
                .where((segment) => segment.isNotEmpty)
                .last,
            hasInfoDat: true,
            info: InstalledSongInfo(
              songName: title,
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: key,
            title: title,
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [
        selected(
          key: 'abc',
          hash: 'hash1',
          directory: presentDir,
          title: 'Remove',
        ),
        selected(
          key: 'def',
          hash: 'hash2',
          directory: staleDir,
          title: 'Stale',
        ),
      ],
    );

    expect(result.requested, 2);
    expect(result.removedPlaylistEntries, 1);
    expect(result.deleted, 1);
    expect(result.songBackups, hasLength(1));
    expect(await presentDir.exists(), isFalse);
    expect(await staleDir.exists(), isTrue);
    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], isEmpty);
  });

  test('does not delete hash-only installed directories whose rows are gone',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"hash": "hash1", "songName": "Remove hash only"}
  ]
}
''');

    final presentDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}hash1 - Remove',
    ).create();
    await File('${presentDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final staleDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}hash2 - Stale',
    ).create();
    await File('${staleDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Stale"}');

    PlaylistSyncEntry selected({
      required String hash,
      required Directory directory,
      required String title,
    }) =>
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: hash),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: directory,
            directoryName: directory.uri.pathSegments
                .where((segment) => segment.isNotEmpty)
                .last,
            hasInfoDat: true,
            info: InstalledSongInfo(
              songName: title,
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: null,
            title: title,
          ),
          matchType: PlaylistSyncMatchType.normalizedName,
          hasEgg: false,
        );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [
        selected(hash: 'hash1', directory: presentDir, title: 'Remove'),
        selected(hash: 'hash2', directory: staleDir, title: 'Stale'),
      ],
    );

    expect(result.requested, 2);
    expect(result.removedPlaylistEntries, 1);
    expect(result.deleted, 1);
    expect(result.songBackups, hasLength(1));
    expect(await presentDir.exists(), isFalse);
    expect(await staleDir.exists(), isTrue);
    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], isEmpty);
  });

  test('creates separate song directory backups for consecutive deletes',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''';
    final songDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    );

    Future<void> restoreSource(String marker) async {
      await playlistFile.writeAsString(playlistJson);
      await songDir.create(recursive: true);
      await File('${songDir.path}${Platform.pathSeparator}song.egg')
          .writeAsString(marker);
    }

    PlaylistSyncEntry selectedEntry() => PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: const BeatSaverHashDetail(
            id: 'abc',
            name: 'Remove',
            description: '',
          ),
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: true,
        );

    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );
    await restoreSource('first');
    final first = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [selectedEntry()],
    );
    await restoreSource('second');
    final second = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [selectedEntry()],
    );

    expect(first.songBackups, hasLength(1));
    expect(second.songBackups, hasLength(1));
    expect(
        first.songBackups.single.path, isNot(second.songBackups.single.path));
    expect(await first.songBackups.single.exists(), isTrue);
    expect(await second.songBackups.single.exists(), isTrue);
    expect(
      await File(
        '${first.songBackups.single.path}${Platform.pathSeparator}song.egg',
      ).readAsString(),
      'first',
    );
    expect(
      await File(
        '${second.songBackups.single.path}${Platform.pathSeparator}song.egg',
      ).readAsString(),
      'second',
    );
  });

  test('removes playlist entry when selected installed directory is missing',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''');

    final missingSongDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Missing',
    );
    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: const BeatSaverHashDetail(
            id: 'abc',
            name: 'Remove',
            description: '',
          ),
          installedEntry: InstalledSongEntry(
            directory: missingSongDir,
            directoryName: 'abc - Missing',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.deleted, 0);
    expect(result.removedPlaylistEntries, 1);
    expect(await result.playlistBackup!.exists(), isTrue);
    expect(result.songBackups, isEmpty);
    expect(await missingSongDir.exists(), isFalse);

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'hash2', 'songName': 'Keep'},
    ]);
  });

  test('does not delete installed directory when selected playlist row is gone',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''');

    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');

    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );
    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.deleted, 0);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(result.songBackups, isEmpty);
    expect(await songDir.exists(), isTrue);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('does not delete installed directory when same-key hash row is gone',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "oldhash", "songName": "Keep old hash"}
  ]
}
''';
    await playlistFile.writeAsString(playlistJson);
    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - New Hash',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"New Hash"}');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'newhash'),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - New Hash',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'New Hash',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'New Hash',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.deleted, 0);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(result.songBackups, isEmpty);
    expect(await songDir.exists(), isTrue);
    expect(await backupDirectory.exists(), isFalse);
    expect(await playlistFile.readAsString(), playlistJson);
  });

  test('does not delete installed directory when playlist songs is missing',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{"playlistTitle":"Missing Songs","customData":{"keep":true}}
''';
    await playlistFile.writeAsString(playlistJson);

    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.deleted, 0);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(result.songBackups, isEmpty);
    expect(await playlistFile.readAsString(), playlistJson);
    expect(await songDir.exists(), isTrue);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('does not delete installed directory when playlist songs is not a list',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{"playlistTitle":"Object Songs","songs":{"key":"abc","hash":"hash1"}}
''';
    await playlistFile.writeAsString(playlistJson);

    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.deleted, 0);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(result.songBackups, isEmpty);
    expect(await playlistFile.readAsString(), playlistJson);
    expect(await songDir.exists(), isTrue);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('does not delete installed directory when playlist JSON is invalid',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('{not json');
    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    await expectLater(
      deletePlaylistSyncEntriesWithBackup(
        playlistFile: playlistFile,
        backupDirectory: backupDirectory,
        entries: [
          PlaylistSyncEntry(
            playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
            beatSaverDetail: null,
            installedEntry: InstalledSongEntry(
              directory: songDir,
              directoryName: 'abc - Remove',
              hasInfoDat: true,
              info: const InstalledSongInfo(
                songName: 'Remove',
                songSubName: '',
                songAuthorName: '',
                levelAuthorName: '',
                beatsPerMinute: 0,
              ),
              mapId: 'abc',
              title: 'Remove',
            ),
            matchType: PlaylistSyncMatchType.mapId,
            hasEgg: false,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await songDir.exists(), isTrue);
    expect(await backupDirectory.exists(), isFalse);
    expect(await playlistFile.readAsString(), '{not json');
  });

  test(
      'does not delete installed directory when playlist JSON is not an object',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
[{"key":"abc","hash":"hash1"}]
''';
    await playlistFile.writeAsString(playlistJson);
    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    await expectLater(
      deletePlaylistSyncEntriesWithBackup(
        playlistFile: playlistFile,
        backupDirectory: backupDirectory,
        entries: [
          PlaylistSyncEntry(
            playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
            beatSaverDetail: null,
            installedEntry: InstalledSongEntry(
              directory: songDir,
              directoryName: 'abc - Remove',
              hasInfoDat: true,
              info: const InstalledSongInfo(
                songName: 'Remove',
                songSubName: '',
                songAuthorName: '',
                levelAuthorName: '',
                beatsPerMinute: 0,
              ),
              mapId: 'abc',
              title: 'Remove',
            ),
            matchType: PlaylistSyncMatchType.mapId,
            hasEgg: false,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await songDir.exists(), isTrue);
    expect(await backupDirectory.exists(), isFalse);
    expect(await playlistFile.readAsString(), playlistJson);
  });

  test('backs up playlist before removing entries without deleting songs',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "customData": {"keep": true},
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''');
    final songDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    ).create();
    await File('${songDir.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Remove"}');

    final result = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup',
      ),
      entries: [
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: InstalledSongEntry(
            directory: songDir,
            directoryName: 'abc - Remove',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Remove',
              songSubName: '',
              songAuthorName: '',
              levelAuthorName: '',
              beatsPerMinute: 0,
            ),
            mapId: 'abc',
            title: 'Remove',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removedPlaylistEntries, 1);
    expect(await result.playlistBackup!.exists(), isTrue);
    expect(await songDir.exists(), isTrue);
    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['playlistTitle'], 'Sync');
    expect(decoded['customData'], {'keep': true});
    expect(decoded['songs'], [
      {'key': 'def', 'hash': 'hash2', 'songName': 'Keep'},
    ]);
  });

  test('does not back up playlist-only removal when no rows match', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{"playlistTitle":"Sync","songs":[{"key":"def","hash":"hash2"}]}
''';
    await playlistFile.writeAsString(playlistJson);
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(await playlistFile.readAsString(), playlistJson);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('playlist-only removal counts only rows that still exist', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"}
  ]
}
''');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'def', hash: 'hash2'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 2);
    expect(result.removedPlaylistEntries, 1);
    expect(await result.playlistBackup!.exists(), isTrue);
    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], isEmpty);
  });

  test('playlist-only removal counts only hash-only rows that still exist',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Sync",
  "songs": [
    {"hash": "hash1", "songName": "Remove hash only"}
  ]
}
''');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: 'hash2'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 2);
    expect(result.removedPlaylistEntries, 1);
    expect(await result.playlistBackup!.exists(), isTrue);
    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['songs'], isEmpty);
  });

  test('does not back up playlist-only removal when songs is missing',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{"playlistTitle":"Missing Songs","customData":{"keep":true}}
''';
    await playlistFile.writeAsString(playlistJson);
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(await playlistFile.readAsString(), playlistJson);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('does not back up playlist-only removal when songs is not a list',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{"playlistTitle":"Object Songs","songs":{"key":"abc","hash":"hash1"}}
''';
    await playlistFile.writeAsString(playlistJson);
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final result = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: const [
        PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removedPlaylistEntries, 0);
    expect(result.playlistBackup, isNull);
    expect(await playlistFile.readAsString(), playlistJson);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('does not back up playlist-only removal when JSON is invalid', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    await playlistFile.writeAsString('{not json');
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    await expectLater(
      removePlaylistSyncEntriesFromBplistWithBackup(
        playlistFile: playlistFile,
        backupDirectory: backupDirectory,
        entries: const [
          PlaylistSyncEntry(
            playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
            beatSaverDetail: null,
            installedEntry: null,
            matchType: PlaylistSyncMatchType.missing,
            hasEgg: false,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await playlistFile.readAsString(), '{not json');
    expect(await backupDirectory.exists(), isFalse);
  });

  test('does not back up playlist-only removal when JSON is not an object',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
[{"key":"abc","hash":"hash1"}]
''';
    await playlistFile.writeAsString(playlistJson);
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    await expectLater(
      removePlaylistSyncEntriesFromBplistWithBackup(
        playlistFile: playlistFile,
        backupDirectory: backupDirectory,
        entries: const [
          PlaylistSyncEntry(
            playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
            beatSaverDetail: null,
            installedEntry: null,
            matchType: PlaylistSyncMatchType.missing,
            hasEgg: false,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await playlistFile.readAsString(), playlistJson);
    expect(await backupDirectory.exists(), isFalse);
  });

  test('creates separate playlist backups for consecutive removals', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}songs.bplist',
    );
    const playlistJson = '''
{
  "playlistTitle": "Sync",
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "def", "hash": "hash2", "songName": "Keep"}
  ]
}
''';
    await playlistFile.writeAsString(playlistJson);
    const selected = [
      PlaylistSyncEntry(
        playlistEntry: BplistSongEntry(key: 'abc', hash: 'hash1'),
        beatSaverDetail: null,
        installedEntry: null,
        matchType: PlaylistSyncMatchType.missing,
        hasEgg: false,
      ),
    ];
    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup',
    );

    final first = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: selected,
    );
    await playlistFile.writeAsString(playlistJson);
    final second = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: selected,
    );

    expect(first.playlistBackup?.path, isNot(second.playlistBackup?.path));
    expect(await first.playlistBackup!.exists(), isTrue);
    expect(await second.playlistBackup!.exists(), isTrue);
    expect(await first.playlistBackup!.readAsString(), playlistJson);
    expect(await second.playlistBackup!.readAsString(), playlistJson);
  });

  test('scans real playlist and library before backup delete sync entries',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('playlist_sync_scan_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}real.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Real Sync",
  "playlistAuthor": "Tester",
  "customData": {"keep": true},
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Remove"},
    {"key": "", "hash": "hash2", "songName": "Name Match"},
    {"key": "missing", "hash": "hash3", "songName": "Missing"}
  ]
}
''');

    final idMatch = Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Remove',
    );
    await idMatch.create(recursive: true);
    await File('${idMatch.path}${Platform.pathSeparator}Info.dat')
        .writeAsString('''
{
  "_songName": "Remove",
  "_songAuthorName": "Artist"
}
''');
    await File('${idMatch.path}${Platform.pathSeparator}song.egg')
        .writeAsString('audio');

    final nameMatch = Directory(
      '${tempDir.path}${Platform.pathSeparator}zzz - Name Match',
    );
    await nameMatch.create(recursive: true);
    await File('${nameMatch.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Name Match"}');

    final playlist = await readBplist(playlistFile);
    final compared = await comparePlaylistWithInstalledLibrary(
      playlist: playlist,
      libraryDirectory: tempDir,
      hashDetails: const {
        'hash2': BeatSaverHashDetail(
          id: 'def',
          name: 'NameMatch',
          description: '',
        ),
      },
    );

    expect(compared.map((entry) => entry.matchType), [
      PlaylistSyncMatchType.mapId,
      PlaylistSyncMatchType.normalizedName,
      PlaylistSyncMatchType.missing,
    ]);

    final result = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: Directory(
        '${tempDir.path}${Platform.pathSeparator}backup${Platform.pathSeparator}sync',
      ),
      entries: compared.where((entry) => entry.isInstalled),
    );

    expect(result.requested, 2);
    expect(result.deleted, 2);
    expect(result.removedPlaylistEntries, 2);
    expect(await idMatch.exists(), isFalse);
    expect(await nameMatch.exists(), isFalse);
    expect(await result.playlistBackup!.exists(), isTrue);
    expect(result.songBackups, hasLength(2));

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['playlistTitle'], 'Real Sync');
    expect(decoded['playlistAuthor'], 'Tester');
    expect(decoded['customData'], {'keep': true});
    expect(decoded['songs'], [
      {'key': 'missing', 'hash': 'hash3', 'songName': 'Missing'},
    ]);
  });

  test('runs real-like playlist sync remove then backup delete lifecycle',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('playlist_sync_lifecycle_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}mixed.bplist',
    );
    await playlistFile.writeAsString('''
{
  "playlistTitle": "Mixed Lifecycle",
  "playlistAuthor": "Tester",
  "description": "keep metadata",
  "image": "data:image/png;base64,abc",
  "customData": {"source": "test"},
  "songs": [
    {"key": "abc", "hash": "hash1", "songName": "Delete by id"},
    {"hash": "hash2", "songName": "Delete by name"},
    {"hash": "hash3", "songName": "Remove missing only"}
  ]
}
''');

    final idMatch = await Directory(
      '${tempDir.path}${Platform.pathSeparator}abc - Delete by id',
    ).create(recursive: true);
    await File('${idMatch.path}${Platform.pathSeparator}Info.dat')
        .writeAsString('''
{
  "_songName": "Delete by id",
  "_songAuthorName": "Artist",
  "_difficultyBeatmapSets": [
    {
      "_difficultyBeatmaps": [
        {"_difficulty": "Expert"}
      ]
    }
  ]
}
''');
    await File('${idMatch.path}${Platform.pathSeparator}song.egg')
        .writeAsString('audio');

    final nameMatch = await Directory(
      '${tempDir.path}${Platform.pathSeparator}noid - Delete by name',
    ).create(recursive: true);
    await File('${nameMatch.path}${Platform.pathSeparator}info.dat')
        .writeAsString('{"_songName":"Delete by name"}');

    var compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(playlistFile),
      libraryDirectory: tempDir,
      hashDetails: const {
        'hash2': BeatSaverHashDetail(
          id: 'def',
          name: 'Deletebyname',
          description: '',
        ),
      },
    );
    expect(compared.map((entry) => entry.matchType), [
      PlaylistSyncMatchType.mapId,
      PlaylistSyncMatchType.normalizedName,
      PlaylistSyncMatchType.missing,
    ]);

    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup${Platform.pathSeparator}sync',
    );
    final playlistOnly = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: compared.where((entry) => !entry.isInstalled),
    );

    expect(playlistOnly.requested, 1);
    expect(playlistOnly.removedPlaylistEntries, 1);
    expect(await playlistOnly.playlistBackup!.exists(), isTrue);
    expect(await idMatch.exists(), isTrue);
    expect(await nameMatch.exists(), isTrue);

    compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(playlistFile),
      libraryDirectory: tempDir,
      hashDetails: const {
        'hash2': BeatSaverHashDetail(
          id: 'def',
          name: 'Deletebyname',
          description: '',
        ),
      },
    );
    expect(compared.map((entry) => entry.matchType), [
      PlaylistSyncMatchType.mapId,
      PlaylistSyncMatchType.normalizedName,
    ]);

    final deleteResult = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: compared,
    );

    expect(deleteResult.requested, 2);
    expect(deleteResult.deleted, 2);
    expect(deleteResult.removedPlaylistEntries, 2);
    expect(await deleteResult.playlistBackup!.exists(), isTrue);
    expect(deleteResult.songBackups, hasLength(2));
    expect(await idMatch.exists(), isFalse);
    expect(await nameMatch.exists(), isFalse);
    expect(
      await File(
        '${deleteResult.songBackups.first.path}${Platform.pathSeparator}Info.dat',
      ).exists(),
      isTrue,
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['playlistTitle'], 'Mixed Lifecycle');
    expect(decoded['playlistAuthor'], 'Tester');
    expect(decoded['description'], 'keep metadata');
    expect(decoded['image'], 'data:image/png;base64,abc');
    expect(decoded['customData'], {'source': 'test'});
    expect(decoded['songs'], isEmpty);
  });

  test('runs hash-only local-hash remove then backup delete lifecycle',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'playlist_sync_hash_lifecycle_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<Directory> createHashableSong({
      required String directoryName,
      required String songName,
      required String beatmapBody,
    }) async {
      final songDir = await Directory(
        '${tempDir.path}${Platform.pathSeparator}$directoryName',
      ).create(recursive: true);
      await File('${songDir.path}${Platform.pathSeparator}Info.dat')
          .writeAsString('''
{
  "_songName": "$songName",
  "_songAuthorName": "Artist",
  "_difficultyBeatmapSets": [
    {
      "_difficultyBeatmaps": [
        {
          "_difficulty": "Normal",
          "_beatmapFilename": "NormalStandard.dat"
        }
      ]
    }
  ]
}
''');
      await File('${songDir.path}${Platform.pathSeparator}NormalStandard.dat')
          .writeAsString(beatmapBody);
      await File('${songDir.path}${Platform.pathSeparator}song.egg')
          .writeAsString('audio');
      return songDir;
    }

    final removeDir = await createHashableSong(
      directoryName: '1001c (Hash Delete)',
      songName: 'Hash Delete',
      beatmapBody: '{"_notes":[]}',
    );
    final keepDir = await createHashableSong(
      directoryName: '1002d (Hash Keep)',
      songName: 'Hash Keep',
      beatmapBody: '{"_notes":[{"_time":1}]}',
    );
    final removeHash = await computeInstalledSongHash(removeDir);
    final keepHash = await computeInstalledSongHash(keepDir);
    expect(removeHash, isNotNull);
    expect(keepHash, isNotNull);
    expect(removeHash, isNot(keepHash));

    final playlistFile = File(
      '${tempDir.path}${Platform.pathSeparator}hash_only.bplist',
    );
    await playlistFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'playlistTitle': 'Hash Only Lifecycle',
        'playlistAuthor': 'Tester',
        'songs': [
          {'hash': removeHash, 'songName': 'Hash Delete'},
          {'hash': keepHash, 'songName': 'Hash Keep'},
          {
            'hash': '0000000000000000000000000000000000000000',
            'songName': 'Missing'
          },
        ],
      }),
    );

    var compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(playlistFile),
      libraryDirectory: tempDir,
    );
    expect(compared.map((entry) => entry.matchType), [
      PlaylistSyncMatchType.localHash,
      PlaylistSyncMatchType.localHash,
      PlaylistSyncMatchType.missing,
    ]);

    final backupDirectory = Directory(
      '${tempDir.path}${Platform.pathSeparator}backup${Platform.pathSeparator}sync',
    );
    final playlistOnly = await removePlaylistSyncEntriesFromBplistWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: compared.where((entry) => !entry.isInstalled),
    );

    expect(playlistOnly.requested, 1);
    expect(playlistOnly.removedPlaylistEntries, 1);
    expect(await playlistOnly.playlistBackup!.exists(), isTrue);
    expect(await removeDir.exists(), isTrue);
    expect(await keepDir.exists(), isTrue);

    compared = await comparePlaylistWithInstalledLibrary(
      playlist: await readBplist(playlistFile),
      libraryDirectory: tempDir,
    );
    expect(compared.map((entry) => entry.matchType), [
      PlaylistSyncMatchType.localHash,
      PlaylistSyncMatchType.localHash,
    ]);

    final deleteResult = await deletePlaylistSyncEntriesWithBackup(
      playlistFile: playlistFile,
      backupDirectory: backupDirectory,
      entries: [compared.first],
    );

    expect(deleteResult.requested, 1);
    expect(deleteResult.deleted, 1);
    expect(deleteResult.removedPlaylistEntries, 1);
    expect(await deleteResult.playlistBackup!.exists(), isTrue);
    expect(deleteResult.songBackups, hasLength(1));
    expect(await removeDir.exists(), isFalse);
    expect(await keepDir.exists(), isTrue);
    expect(
      await File(
        '${deleteResult.songBackups.single.path}${Platform.pathSeparator}Info.dat',
      ).exists(),
      isTrue,
    );

    final decoded = jsonDecode(await playlistFile.readAsString());
    expect(decoded['playlistTitle'], 'Hash Only Lifecycle');
    expect(decoded['playlistAuthor'], 'Tester');
    expect(decoded['songs'], [
      {'hash': keepHash, 'songName': 'Hash Keep'},
    ]);
  });
}
