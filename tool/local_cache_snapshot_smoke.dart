import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final maxPages = _intOption(args, '--max-pages=', fallback: 1);
  final pageSize = _intOption(args, '--page-size=', fallback: 10);
  final allowNetwork = args.contains('--allow-network');
  final incremental = args.contains('--incremental');
  final deletedAudit = args.contains('--deleted-audit');
  final keepTemp = args.contains('--keep-temp');
  if (!allowNetwork) {
    stderr.writeln(
      'This smoke contacts BeatSaver. Re-run with --allow-network only when '
      'a live API check was explicitly requested.',
    );
    exitCode = 2;
    return;
  }
  final tempDir = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_local_cache_snapshot_',
  );
  final output = File(p.join(tempDir.path, 'LocalCache.saver'));

  try {
    if (incremental) {
      await _runIncrementalSmoke(
        output: output,
        pageSize: pageSize,
        keepTemp: keepTemp,
        tempDir: tempDir,
      );
      return;
    }
    if (deletedAudit) {
      await _runDeletedAuditSmoke(
        output: output,
        pageSize: pageSize,
        tempDir: tempDir,
      );
      return;
    }

    final result = await buildLocalCacheSnapshot(
      outputFile: output,
      options: LocalCacheSnapshotOptions(
        pageSize: pageSize,
        maxPages: maxPages,
        delayBetweenRequests: const Duration(milliseconds: 500),
      ),
      onProgress: (progress) {
        print(
          'progress pages=${progress.pagesFetched} '
          'maps=${progress.fetchedMaps} '
          'completed=${progress.completed} paused=${progress.paused}',
        );
      },
    );

    final partial = File('${output.path}.partial.ndjson');
    final state = File('${output.path}.snapshot_state.json');
    print('tempDir=${tempDir.path}');
    print('output=${output.path}');
    print('pages=${result.pagesFetched}');
    print('maps=${result.fetchedMaps}');
    print('completed=${result.completed}');
    print('paused=${result.paused}');
    print('partialExists=${await partial.exists()}');
    print('stateExists=${await state.exists()}');

    if (result.fetchedMaps <= 0) {
      stderr.writeln('No BeatSaver maps were fetched.');
      exitCode = 1;
      return;
    }
    if (!result.paused && !result.completed) {
      stderr.writeln('Snapshot builder ended without paused/completed state.');
      exitCode = 1;
      return;
    }
    if (result.completed && !await output.exists()) {
      stderr.writeln('Completed snapshot did not write LocalCache.saver.');
      exitCode = 1;
      return;
    }
    if (result.paused && (!await partial.exists() || !await state.exists())) {
      stderr.writeln('Paused snapshot did not leave resume files.');
      exitCode = 1;
      return;
    }

    print('localCacheSnapshotSmoke=passed');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempDir.path}');
    } else if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _runDeletedAuditSmoke({
  required File output,
  required int pageSize,
  required Directory tempDir,
}) async {
  final client = BeatSaverClient();
  final deletedPageSize = pageSize.clamp(1, 100);
  final deletedPage = await client.getDeletedMapsPageRaw(
    pageSize: deletedPageSize,
  );
  final deletedDocs = (deletedPage['docs'] is List)
      ? (deletedPage['docs'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
  if (deletedDocs.isEmpty) {
    stderr.writeln('No deleted BeatSaver maps were returned.');
    exitCode = 1;
    return;
  }

  final firstDeletedId = deletedDocs.first['id']?.toString().trim();
  if (firstDeletedId == null || firstDeletedId.isEmpty) {
    stderr.writeln('Deleted BeatSaver response did not include a map id.');
    exitCode = 1;
    return;
  }
  await output.writeAsString(
    jsonEncode({
      'docs': [
        {
          'id': firstDeletedId,
          'name': 'Deleted Smoke Seed',
          'description': 'temporary audit seed',
          'updatedAt': '2026-01-01T00:00:00Z',
          'metadata': {
            'songName': 'Deleted Smoke Seed',
            'songAuthorName': 'Artist',
            'levelAuthorName': 'Mapper',
          },
          'stats': {},
          'versions': [],
        },
      ],
      'info': {
        'total': 1,
        'page': 0,
        'itemsPerPage': 1,
      },
    }),
    flush: true,
  );
  final before =
      deletedDocs.length > 1 ? deletedDocs.last['deletedAt']?.toString() : null;
  final result = await auditLocalCacheDeletedCandidates(
    outputFile: output,
    client: client,
    options: LocalCacheSnapshotOptions(
      pageSize: deletedPageSize,
      maxPages: 1,
      delayBetweenRequests: Duration.zero,
    ),
  );
  final matched = result.candidates.where((candidate) {
    return candidate.id.toLowerCase() == firstDeletedId.toLowerCase() &&
        candidate.inLocalCache;
  }).length;

  print('tempDir=${tempDir.path}');
  print('output=${output.path}');
  print('seedDeletedId=$firstDeletedId');
  print('seedDeletedBefore=$before');
  print('pages=${result.pagesFetched}');
  print('deleted=${result.deletedMaps.length}');
  print('candidates=${result.candidates.length}');
  print('localMatches=$matched');
  print('completed=${result.completed}');
  print('paused=${result.paused}');
  print('nextBefore=${result.nextBefore}');

  if (result.pagesFetched != 1 || result.deletedMaps.isEmpty) {
    stderr.writeln('Deleted audit did not read one deleted-map page.');
    exitCode = 1;
    return;
  }
  if (matched != 1) {
    stderr.writeln('Deleted audit did not flag the seeded local cache map.');
    exitCode = 1;
    return;
  }
  if (!await output.exists()) {
    stderr.writeln('Deleted audit unexpectedly removed LocalCache.saver.');
    exitCode = 1;
    return;
  }

  print('localCacheDeletedAuditSmoke=passed');
}

Future<void> _runIncrementalSmoke({
  required File output,
  required int pageSize,
  required bool keepTemp,
  required Directory tempDir,
}) async {
  final client = BeatSaverClient();
  final seedPageSize = pageSize.clamp(3, 100);
  final latestPage = await client.getLatestMapsPageRaw(
    pageSize: seedPageSize,
    sort: 'UPDATED',
  );
  final docs = (latestPage['docs'] is List)
      ? (latestPage['docs'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
  if (docs.length < 2) {
    stderr.writeln('Not enough BeatSaver latest docs for incremental smoke.');
    exitCode = 1;
    return;
  }

  final seedDocs = docs.skip(1).toList(growable: false);
  await output.writeAsString(
    jsonEncode({
      'docs': seedDocs,
      'info': {
        'total': seedDocs.length,
        'page': 0,
        'itemsPerPage': seedDocs.length,
      },
    }),
    flush: true,
  );

  final result = await updateLocalCacheSnapshot(
    outputFile: output,
    client: client,
    options: LocalCacheSnapshotOptions(
      pageSize: seedPageSize,
      delayBetweenRequests: const Duration(milliseconds: 500),
    ),
    onProgress: (progress) {
      print(
        'incrementalProgress pages=${progress.pagesFetched} '
        'maps=${progress.fetchedMaps} '
        'completed=${progress.completed} paused=${progress.paused}',
      );
    },
  );

  final partial = File('${output.path}.incremental.partial.ndjson');
  final state = File('${output.path}.incremental_state.json');
  final parsed = await readLocalCacheSaver(output);
  final expectedId = docs.first['id']?.toString().trim().toLowerCase();
  final ids = parsed.maps.map((map) => map.id.toLowerCase()).toSet();

  print('tempDir=${tempDir.path}');
  print('output=${output.path}');
  print('since=${result.since}');
  print('pages=${result.pagesFetched}');
  print('fetched=${result.fetchedMaps}');
  print('added=${result.addedMaps}');
  print('updated=${result.updatedMaps}');
  print('total=${result.totalMaps}');
  print('completed=${result.completed}');
  print('paused=${result.paused}');
  print('partialExists=${await partial.exists()}');
  print('stateExists=${await state.exists()}');
  print('expectedLatestId=$expectedId');
  print(
      'expectedLatestMerged=${expectedId != null && ids.contains(expectedId)}');

  if (!result.completed || result.paused) {
    stderr.writeln('Incremental update did not complete.');
    exitCode = 1;
    return;
  }
  if (expectedId == null || !ids.contains(expectedId)) {
    stderr.writeln('Incremental update did not merge the newer latest map.');
    exitCode = 1;
    return;
  }
  if (await partial.exists() || await state.exists()) {
    stderr.writeln('Completed incremental update left resume files behind.');
    exitCode = 1;
    return;
  }
  if (result.addedMaps <= 0 && result.updatedMaps <= 0) {
    stderr.writeln('Incremental update reported no merged maps.');
    exitCode = 1;
    return;
  }

  print('localCacheSnapshotIncrementalSmoke=passed');
}

int _intOption(
  List<String> args,
  String prefix, {
  required int fallback,
}) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return int.tryParse(arg.substring(prefix.length)) ?? fallback;
    }
  }
  return fallback;
}

const _usage = r'''
Usage:
  dart run tool\local_cache_snapshot_smoke.dart [options]

Options:
  --max-pages=N  Limit fetched /maps/latest pages. Defaults to 1.
  --page-size=N  BeatSaver page size, clamped to 1..100. Defaults to 10.
  --allow-network
                 Required. Confirms this run may contact BeatSaver.
  --incremental  Verify incremental merge against a small live latest sample.
  --deleted-audit Verify /maps/deleted candidate auditing without deleting.
  --keep-temp    Keep temp files for inspection.
  --help, -h     Show this help.

Fetches a small /maps/latest sample into a resumable LocalCache snapshot build.
This is a live BeatSaver smoke and refuses to run without --allow-network.
The default intentionally pauses after one page, leaving partial/state files in
system temp only long enough to verify resumability, then cleans them up.
With --incremental, seeds a temp LocalCache.saver from older rows in a live
latest page and verifies updateLocalCacheSnapshot merges newer rows back in.
With --deleted-audit, seeds a temp LocalCache.saver with one live deleted map id
and verifies the audit flags it as a candidate without modifying the cache.
''';
