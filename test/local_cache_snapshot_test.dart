import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('decides whether a LocalCache snapshot should refresh by age', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_snapshot_age_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    expect(
      await shouldRefreshLocalCacheSnapshot(
        file,
        now: DateTime(2026, 6, 17),
      ),
      isTrue,
    );

    await file.writeAsString('{"docs":[]}');
    await file.setLastModified(DateTime(2026, 6, 10));
    expect(
      await shouldRefreshLocalCacheSnapshot(
        file,
        refreshAfter: const Duration(days: 15),
        now: DateTime(2026, 6, 17),
      ),
      isFalse,
    );
    expect(
      await shouldRefreshLocalCacheSnapshot(
        file,
        refreshAfter: const Duration(days: 7),
        now: DateTime(2026, 6, 17),
      ),
      isTrue,
    );
  });

  test('reads LocalCache saver snapshot metadata', () {
    final info = readLocalCacheSaverInfoString(jsonEncode({
      'docs': [],
      'info': {
        'generatedAt': '2026-06-18T01:00:00Z',
        'incrementalUpdatedAt': '2026-06-18T02:00:00Z',
        'incrementalAdded': 3,
        'incrementalUpdated': '2',
      },
    }));

    expect(info.generatedAt, DateTime.parse('2026-06-18T01:00:00Z'));
    expect(
      info.incrementalUpdatedAt,
      DateTime.parse('2026-06-18T02:00:00Z'),
    );
    expect(info.incrementalAdded, 3);
    expect(info.incrementalUpdated, 2);
  });

  test('pauses and resumes a LocalCache snapshot build', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_snapshot_resume_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final output =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    final pages = _FakeLatestPages({
      null: [
        _mapJson('aaa', '2026-06-17T10:00:00+00:00'),
        _mapJson('bbb', '2026-06-17T09:00:00+00:00'),
      ],
      '2026-06-17T09:00:00+00:00': [
        _mapJson('ccc', '2026-06-16T08:00:00+00:00'),
      ],
      '2026-06-16T08:00:00+00:00': const [],
    });

    final first = await buildLocalCacheSnapshot(
      outputFile: output,
      fetchPage: pages.fetch,
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
        maxPages: 1,
      ),
    );

    expect(first.paused, isTrue);
    expect(first.completed, isFalse);
    expect(first.fetchedMaps, 2);
    expect(await output.exists(), isFalse);
    expect(await File('${output.path}.partial.ndjson').exists(), isTrue);
    expect(await File('${output.path}.snapshot_state.json').exists(), isTrue);

    final second = await buildLocalCacheSnapshot(
      outputFile: output,
      fetchPage: pages.fetch,
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
      ),
    );

    expect(second.completed, isTrue);
    expect(second.paused, isFalse);
    expect(second.fetchedMaps, 3);
    expect(await output.exists(), isTrue);
    expect(await File('${output.path}.partial.ndjson').exists(), isFalse);
    expect(await File('${output.path}.snapshot_state.json').exists(), isFalse);

    final parsed = await readLocalCacheSaver(output);
    expect(parsed.maps.map((map) => map.id), ['aaa', 'bbb', 'ccc']);
    expect(parsed.metadata.total, 3);
    expect(pages.requests, [
      null,
      '2026-06-17T09:00:00+00:00',
      '2026-06-16T08:00:00+00:00',
    ]);
  });

  test('can pause from a callback before the next request', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_snapshot_pause_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final output =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    final pages = _FakeLatestPages({
      null: [_mapJson('aaa', '2026-06-17T10:00:00+00:00')],
      '2026-06-17T10:00:00+00:00': [
        _mapJson('bbb', '2026-06-16T10:00:00+00:00'),
      ],
    });
    var checks = 0;

    final result = await buildLocalCacheSnapshot(
      outputFile: output,
      fetchPage: pages.fetch,
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
      ),
      shouldPause: () {
        checks += 1;
        return checks > 1;
      },
    );

    expect(result.paused, isTrue);
    expect(result.completed, isFalse);
    expect(result.fetchedMaps, 1);
    expect(pages.requests, [null]);
  });

  test('audits deleted map candidates without changing LocalCache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_deleted_audit_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final output =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    final original = jsonEncode({
      'docs': [
        _mapJson('old', '2026-06-10T10:00:00+00:00'),
        _mapJson('keep', '2026-06-11T10:00:00+00:00'),
      ],
      'info': {'total': 2, 'page': 0, 'itemsPerPage': 2},
    });
    await output.writeAsString(original);
    final pages = _FakeDeletedPages({
      null: [
        _deletedJson('old', '2026-06-17T10:00:00+00:00'),
        _deletedJson('missing', '2026-06-17T09:00:00+00:00'),
      ],
      '2026-06-17T09:00:00+00:00': const [],
    });

    final result = await auditLocalCacheDeletedCandidates(
      outputFile: output,
      fetchPage: pages.fetch,
      after: '2026-06-01T00:00:00+00:00',
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
      ),
    );

    expect(result.completed, isTrue);
    expect(result.paused, isFalse);
    expect(result.pagesFetched, 1);
    expect(result.deletedMaps.map((entry) => entry.id), ['old', 'missing']);
    expect(
      result.candidates
          .where((candidate) => candidate.inLocalCache)
          .map((candidate) => candidate.id),
      ['old'],
    );
    expect(pages.requests, [null, '2026-06-17T09:00:00+00:00']);
    expect(pages.afterRequests, [
      '2026-06-01T00:00:00+00:00',
      '2026-06-01T00:00:00+00:00',
    ]);
    expect(await output.readAsString(), original);
  });

  test('incrementally merges new and updated maps into LocalCache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_snapshot_incremental_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final output =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    await output.writeAsString(jsonEncode({
      'docs': [
        _mapJson('old', '2026-06-10T10:00:00+00:00'),
        _mapJson('same', '2026-06-12T10:00:00+00:00'),
      ],
      'info': {'total': 2, 'page': 0, 'itemsPerPage': 2},
    }));

    final pages = _FakeLatestPages({
      null: [
        _mapJson('new', '2026-06-17T10:00:00+00:00'),
        _mapJson('same', '2026-06-16T10:00:00+00:00'),
      ],
      '2026-06-16T10:00:00+00:00': const [],
    });

    final result = await updateLocalCacheSnapshot(
      outputFile: output,
      fetchPage: pages.fetch,
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
      ),
    );

    expect(result.completed, isTrue);
    expect(result.paused, isFalse);
    expect(result.addedMaps, 1);
    expect(result.updatedMaps, 1);
    expect(result.totalMaps, 3);
    expect(result.since, '2026-06-12T10:00:00+00:00');
    expect(await File('${output.path}.incremental.partial.ndjson').exists(),
        isFalse);
    expect(
        await File('${output.path}.incremental_state.json').exists(), isFalse);
    expect(pages.requests, [null, '2026-06-16T10:00:00+00:00']);
    expect(pages.afterRequests, [
      '2026-06-12T10:00:00+00:00',
      '2026-06-12T10:00:00+00:00',
    ]);

    final parsed = await readLocalCacheSaver(output);
    expect(parsed.maps.map((map) => map.id), ['new', 'same', 'old']);
    expect(
        parsed.maps.singleWhere((map) => map.id == 'same').name, 'Song same');
    final raw = jsonDecode(await output.readAsString()) as Map<String, dynamic>;
    expect(raw['info']['incrementalAdded'], 1);
    expect(raw['info']['incrementalUpdated'], 1);
  });

  test('pauses and resumes incremental LocalCache updates safely', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_snapshot_incremental_resume_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final output =
        File('${directory.path}${Platform.pathSeparator}LocalCache.saver');
    await output.writeAsString(jsonEncode({
      'docs': [_mapJson('old', '2026-06-10T10:00:00+00:00')],
      'info': {'total': 1, 'page': 0, 'itemsPerPage': 1},
    }));

    final pages = _FakeLatestPages({
      null: [_mapJson('new', '2026-06-17T10:00:00+00:00')],
      '2026-06-17T10:00:00+00:00': const [],
    });

    final first = await updateLocalCacheSnapshot(
      outputFile: output,
      fetchPage: pages.fetch,
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
        maxPages: 1,
      ),
    );

    expect(first.paused, isTrue);
    expect(first.completed, isFalse);
    expect(first.fetchedMaps, 1);
    expect(
        (await readLocalCacheSaver(output)).maps.map((map) => map.id), ['old']);
    expect(await File('${output.path}.incremental.partial.ndjson').exists(),
        isTrue);

    final second = await updateLocalCacheSnapshot(
      outputFile: output,
      fetchPage: pages.fetch,
      options: const LocalCacheSnapshotOptions(
        delayBetweenRequests: Duration.zero,
      ),
    );

    expect(second.completed, isTrue);
    expect(second.addedMaps, 1);
    expect((await readLocalCacheSaver(output)).maps.map((map) => map.id),
        ['new', 'old']);
  });
}

class _FakeLatestPages {
  _FakeLatestPages(this.pages);

  final Map<String?, List<Map<String, dynamic>>> pages;
  final requests = <String?>[];
  final afterRequests = <String?>[];

  Future<Map<String, dynamic>> fetch({
    String? before,
    String? after,
    required int pageSize,
    required String sort,
    bool? automapper,
  }) async {
    requests.add(before);
    afterRequests.add(after);
    return {
      'docs': pages[before] ?? const [],
      'info': {
        'total': pages.values.fold<int>(0, (sum, docs) => sum + docs.length),
      },
    };
  }
}

class _FakeDeletedPages {
  _FakeDeletedPages(this.pages);

  final Map<String?, List<Map<String, dynamic>>> pages;
  final requests = <String?>[];
  final afterRequests = <String?>[];

  Future<Map<String, dynamic>> fetch({
    String? before,
    String? after,
    required int pageSize,
  }) async {
    requests.add(before);
    afterRequests.add(after);
    return {'docs': pages[before] ?? const []};
  }
}

Map<String, dynamic> _mapJson(String id, String updatedAt) {
  return jsonDecode('''
{
  "id": "$id",
  "name": "Song $id",
  "description": "sample",
  "updatedAt": "$updatedAt",
  "metadata": {
    "songName": "Song $id",
    "songAuthorName": "Artist",
    "levelAuthorName": "Mapper"
  },
  "stats": {},
  "versions": [
    {
      "hash": "${id}hash",
      "createdAt": "$updatedAt",
      "downloadURL": "https://cdn.beatsaver.com/$id.zip",
      "diffs": []
    }
  ]
}
''') as Map<String, dynamic>;
}

Map<String, dynamic> _deletedJson(String id, String deletedAt) {
  return {
    'id': id,
    'deletedAt': deletedAt,
  };
}
