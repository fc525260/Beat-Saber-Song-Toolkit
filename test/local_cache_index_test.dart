import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('builds reads and writes a lightweight LocalCache index', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_local_cache_index_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final source =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    await source.writeAsString(_localCacheJson);
    final maps = readLocalCacheSaverString(_localCacheJson).maps;
    final stat = await source.stat();

    final index = LocalCacheIndex.fromMaps(
      sourceFile: source,
      sourceStat: stat,
      maps: maps,
    );

    expect(index.version, localCacheIndexFormatVersion);
    expect(index.matchesSource(source, stat), isTrue);
    expect(index.entries, hasLength(1));
    expect(index.entries.single.id, '3446b');
    expect(index.entries.single.hash, 'abcdef');
    expect(index.entries.single.searchText, contains('die in a fire'));
    expect(index.entries.single.searchText, contains('firestrike_'));
    expect(index.getByHash('ABCDEF')?.id, '3446b');
    expect(index.getByHash('missing'), isNull);
    expect(index.search('die fire').map((entry) => entry.id), ['3446b']);
    expect(index.search('notfound'), isEmpty);
    expect(index.search(''), hasLength(1));

    final indexFile =
        File('${directory.path}${Platform.pathSeparator}LocalCache.index.json');
    await writeLocalCacheIndex(indexFile, index);
    final restored = await readLocalCacheIndex(indexFile);

    expect(restored, isNotNull);
    expect(restored!.matchesSource(source, stat), isTrue);
    expect(restored.getByHash('abcdef')?.songName, 'Die In A Fire');
  });

  test('returns null when LocalCache index file is missing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_missing_local_cache_index_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    expect(
      await readLocalCacheIndex(
        File('${directory.path}${Platform.pathSeparator}missing.json'),
      ),
      isNull,
    );
  });

  test('keeps the first LocalCache index entry for duplicate hashes', () {
    final index = LocalCacheIndex(
      version: localCacheIndexFormatVersion,
      sourcePath: 'LocalCache.saver',
      sourceBytes: 1,
      sourceModifiedMilliseconds: 2,
      entries: const [
        LocalCacheIndexEntry(
          id: 'first',
          hash: 'abcdef',
          name: 'First',
          songName: 'First',
          songAuthorName: '',
          levelAuthorName: '',
          uploaderName: '',
          searchText: 'first',
        ),
        LocalCacheIndexEntry(
          id: 'second',
          hash: 'abcdef',
          name: 'Second',
          songName: 'Second',
          songAuthorName: '',
          levelAuthorName: '',
          uploaderName: '',
          searchText: 'second',
        ),
      ],
    );

    expect(index.getByHash('ABCDEF')?.id, 'first');
    expect(index.getByHash('abcdef')?.id, 'first');
  });
}

const _localCacheJson = '''
{
  "docs": [
    {
      "id": "3446b",
      "name": "[Unexpected Covers] The Living Tombstone - Die In A Fire",
      "description": "sample",
      "uploader": {"id": 3376, "name": "FireStrike_"},
      "metadata": {
        "bpm": 110.0,
        "duration": 186,
        "songName": "Die In A Fire",
        "songSubName": "Markiplier AI Cover",
        "songAuthorName": "The Living Tombstone",
        "levelAuthorName": "FireStrike"
      },
      "tags": ["meme", "ai"],
      "versions": [
        {
          "hash": "ABCDEF",
          "downloadURL": "https://cdn.beatsaver.com/abcdef.zip",
          "diffs": []
        }
      ]
    }
  ],
  "info": {"total": 1, "page": 0, "itemsPerPage": 20}
}
''';
