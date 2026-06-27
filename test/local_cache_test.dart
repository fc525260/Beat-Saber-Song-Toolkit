import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('reads LocalCache.saver docs as BeatSaver maps', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_local_cache_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    await file.writeAsString('''
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
      "stats": {
        "plays": 1,
        "downloads": 2,
        "upvotes": 3,
        "downvotes": 4,
        "score": 0.5
      },
      "uploaded": "2023-07-22T16:44:42Z",
      "versions": [
        {
          "hash": "abcdef",
          "downloadURL": "https://cdn.beatsaver.com/abcdef.zip",
          "coverURL": "https://cdn.beatsaver.com/abcdef.jpg",
          "diffs": [
            {"characteristic": "Standard", "difficulty": "ExpertPlus"}
          ]
        }
      ]
    }
  ],
  "info": {"total": 1, "page": 0, "itemsPerPage": 20}
}
''');

    final response = await readLocalCacheSaver(file);

    expect(response.metadata.total, 1);
    expect(response.maps, hasLength(1));
    expect(response.maps.single.id, '3446b');
    expect(response.maps.single.metadata.songName, 'Die In A Fire');
    expect(response.maps.single.latestVersion?.hash, 'abcdef');

    final parsed = readLocalCacheSaverString(await file.readAsString());
    expect(parsed.maps.single.id, response.maps.single.id);
  });

  test('parses LocalCache.time cache generation timestamps', () async {
    expect(
      parseLocalCacheTime('2026-06-10T12:34:56Z'),
      DateTime.parse('2026-06-10T12:34:56Z'),
    );
    expect(
      parseLocalCacheTime('1781094896'),
      DateTime.fromMillisecondsSinceEpoch(1781094896000),
    );
    expect(
      parseLocalCacheTime('1781094896000'),
      DateTime.fromMillisecondsSinceEpoch(1781094896000),
    );
    expect(parseLocalCacheTime(''), isNull);
    expect(parseLocalCacheTime('not a date'), isNull);
  });

  test('reads LocalCache.time next to LocalCache.saver when present', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_local_cache_time_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final timeFile =
        File('${directory.path}${Platform.pathSeparator}LocalCache.time');
    await timeFile.writeAsString('2026-06-10 12:34:56');

    expect(
      await readLocalCacheTime(timeFile),
      DateTime(2026, 6, 10, 12, 34, 56),
    );
    expect(
      await readLocalCacheTime(
        File('${directory.path}${Platform.pathSeparator}missing.time'),
      ),
      isNull,
    );
  });
}
