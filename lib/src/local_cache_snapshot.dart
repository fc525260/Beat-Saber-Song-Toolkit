import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'beatsaver_client.dart';

typedef LocalCacheSnapshotPauseCheck = FutureOr<bool> Function();
typedef LocalCacheSnapshotProgressCallback = void Function(
  LocalCacheSnapshotProgress progress,
);
typedef LatestMapsPageFetcher = Future<Map<String, dynamic>> Function({
  String? before,
  String? after,
  required int pageSize,
  required String sort,
  bool? automapper,
});
typedef DeletedMapsPageFetcher = Future<Map<String, dynamic>> Function({
  String? before,
  String? after,
  required int pageSize,
});

class LocalCacheSnapshotOptions {
  const LocalCacheSnapshotOptions({
    this.pageSize = 100,
    this.sort = 'UPDATED',
    this.automapper,
    this.delayBetweenRequests = const Duration(milliseconds: 750),
    this.maxPages,
    this.refreshAfter = const Duration(days: 15),
  });

  final int pageSize;
  final String sort;
  final bool? automapper;
  final Duration delayBetweenRequests;
  final int? maxPages;
  final Duration refreshAfter;

  int get normalizedPageSize => pageSize.clamp(1, 100);
}

class LocalCacheSnapshotProgress {
  const LocalCacheSnapshotProgress({
    required this.fetchedMaps,
    required this.pagesFetched,
    required this.completed,
    required this.paused,
    this.nextBefore,
    this.outputFile,
    this.stateFile,
  });

  final int fetchedMaps;
  final int pagesFetched;
  final bool completed;
  final bool paused;
  final String? nextBefore;
  final File? outputFile;
  final File? stateFile;
}

class LocalCacheSnapshotBuildResult {
  const LocalCacheSnapshotBuildResult({
    required this.outputFile,
    required this.stateFile,
    required this.fetchedMaps,
    required this.pagesFetched,
    required this.completed,
    required this.paused,
  });

  final File outputFile;
  final File stateFile;
  final int fetchedMaps;
  final int pagesFetched;
  final bool completed;
  final bool paused;
}

class LocalCacheSnapshotUpdateResult {
  const LocalCacheSnapshotUpdateResult({
    required this.outputFile,
    required this.stateFile,
    required this.fetchedMaps,
    required this.pagesFetched,
    required this.completed,
    required this.paused,
    required this.addedMaps,
    required this.updatedMaps,
    required this.totalMaps,
    this.since,
  });

  final File outputFile;
  final File stateFile;
  final int fetchedMaps;
  final int pagesFetched;
  final bool completed;
  final bool paused;
  final int addedMaps;
  final int updatedMaps;
  final int totalMaps;
  final String? since;
}

class LocalCacheDeletedMap {
  const LocalCacheDeletedMap({
    required this.id,
    this.deletedAt,
  });

  final String id;
  final DateTime? deletedAt;
}

class LocalCacheDeletedCandidate {
  const LocalCacheDeletedCandidate({
    required this.id,
    required this.deletedAt,
    required this.inLocalCache,
  });

  final String id;
  final DateTime? deletedAt;
  final bool inLocalCache;
}

class LocalCacheDeletedAuditResult {
  const LocalCacheDeletedAuditResult({
    required this.deletedMaps,
    required this.candidates,
    required this.pagesFetched,
    required this.completed,
    required this.paused,
    this.nextBefore,
  });

  final List<LocalCacheDeletedMap> deletedMaps;
  final List<LocalCacheDeletedCandidate> candidates;
  final int pagesFetched;
  final bool completed;
  final bool paused;
  final String? nextBefore;
}

Future<bool> shouldRefreshLocalCacheSnapshot(
  File localCacheSaver, {
  Duration refreshAfter = const Duration(days: 15),
  DateTime? now,
}) async {
  if (!await localCacheSaver.exists()) {
    return true;
  }
  final stat = await localCacheSaver.stat();
  final current = now ?? DateTime.now();
  return current.difference(stat.modified) >= refreshAfter;
}

Future<LocalCacheDeletedAuditResult> auditLocalCacheDeletedCandidates({
  required File outputFile,
  BeatSaverClient? client,
  DeletedMapsPageFetcher? fetchPage,
  String? after,
  LocalCacheSnapshotOptions options = const LocalCacheSnapshotOptions(),
  LocalCacheSnapshotPauseCheck? shouldPause,
}) async {
  final existing = await _readLocalCacheSaverJson(outputFile);
  final localIds = _docsFromPage(existing)
      .map((doc) => doc['id']?.toString().trim().toLowerCase() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
  final effectiveClient = client ?? BeatSaverClient();
  final effectiveFetchPage = fetchPage ??
      ({
        String? before,
        String? after,
        required int pageSize,
      }) {
        return effectiveClient.getDeletedMapsPageRaw(
          before: before,
          after: after,
          pageSize: pageSize,
        );
      };

  final deletedMaps = <LocalCacheDeletedMap>[];
  final candidates = <LocalCacheDeletedCandidate>[];
  var pagesFetched = 0;
  var nextBefore = <String?>[null].single;
  var completed = false;
  var paused = false;

  while (true) {
    if (await _pauseRequested(shouldPause)) {
      paused = true;
      break;
    }
    final maxPages = options.maxPages;
    if (maxPages != null && pagesFetched >= maxPages) {
      paused = true;
      break;
    }

    final page = await effectiveFetchPage(
      before: nextBefore,
      after: after,
      pageSize: options.normalizedPageSize,
    );
    final docs = _deletedDocsFromPage(page);
    if (docs.isEmpty) {
      completed = true;
      break;
    }

    for (final doc in docs) {
      final deleted = _deletedMapFromJson(doc);
      if (deleted == null) {
        continue;
      }
      deletedMaps.add(deleted);
      candidates.add(
        LocalCacheDeletedCandidate(
          id: deleted.id,
          deletedAt: deleted.deletedAt,
          inLocalCache: localIds.contains(deleted.id.toLowerCase()),
        ),
      );
    }

    pagesFetched += 1;
    nextBefore = _deletedBeforeCursor(docs.last);
    if (nextBefore == null) {
      completed = true;
      break;
    }
    if (options.delayBetweenRequests > Duration.zero) {
      await Future<void>.delayed(options.delayBetweenRequests);
    }
  }

  return LocalCacheDeletedAuditResult(
    deletedMaps: List.unmodifiable(deletedMaps),
    candidates: List.unmodifiable(candidates),
    pagesFetched: pagesFetched,
    completed: completed,
    paused: paused,
    nextBefore: nextBefore,
  );
}

Future<LocalCacheSnapshotUpdateResult> updateLocalCacheSnapshot({
  required File outputFile,
  BeatSaverClient? client,
  LatestMapsPageFetcher? fetchPage,
  LocalCacheSnapshotOptions options = const LocalCacheSnapshotOptions(),
  LocalCacheSnapshotPauseCheck? shouldPause,
  LocalCacheSnapshotProgressCallback? onProgress,
  bool reset = false,
}) async {
  if (!await outputFile.exists()) {
    final rebuilt = await buildLocalCacheSnapshot(
      outputFile: outputFile,
      client: client,
      fetchPage: fetchPage,
      options: options,
      shouldPause: shouldPause,
      onProgress: onProgress,
      reset: reset,
    );
    return LocalCacheSnapshotUpdateResult(
      outputFile: rebuilt.outputFile,
      stateFile: rebuilt.stateFile,
      fetchedMaps: rebuilt.fetchedMaps,
      pagesFetched: rebuilt.pagesFetched,
      completed: rebuilt.completed,
      paused: rebuilt.paused,
      addedMaps: rebuilt.completed ? rebuilt.fetchedMaps : 0,
      updatedMaps: 0,
      totalMaps: rebuilt.completed ? rebuilt.fetchedMaps : 0,
    );
  }

  final stateFile = File('${outputFile.path}.incremental_state.json');
  final partialFile = File('${outputFile.path}.incremental.partial.ndjson');
  final effectiveClient = client ?? BeatSaverClient();
  final effectiveFetchPage = fetchPage ??
      ({
        String? before,
        String? after,
        required int pageSize,
        required String sort,
        bool? automapper,
      }) {
        return effectiveClient.getLatestMapsPageRaw(
          before: before,
          after: after,
          pageSize: pageSize,
          sort: sort,
          automapper: automapper,
        );
      };

  if (reset) {
    await _deleteIfExists(stateFile);
    await _deleteIfExists(partialFile);
  }

  var existing = await _readLocalCacheSaverJson(outputFile);
  var state = await _LocalCacheSnapshotIncrementalState.read(stateFile);
  if (state == null || reset) {
    state = _LocalCacheSnapshotIncrementalState(
      since: _latestCursorFromDocs(_docsFromPage(existing)),
      fetchedMaps: 0,
      pagesFetched: 0,
      seenIds: <String>{},
    );
    await state.write(stateFile);
  }

  if (state.since == null || state.since!.isEmpty) {
    final rebuilt = await buildLocalCacheSnapshot(
      outputFile: outputFile,
      client: client,
      fetchPage: fetchPage,
      options: options,
      shouldPause: shouldPause,
      onProgress: onProgress,
      reset: true,
    );
    return LocalCacheSnapshotUpdateResult(
      outputFile: rebuilt.outputFile,
      stateFile: rebuilt.stateFile,
      fetchedMaps: rebuilt.fetchedMaps,
      pagesFetched: rebuilt.pagesFetched,
      completed: rebuilt.completed,
      paused: rebuilt.paused,
      addedMaps: rebuilt.completed ? rebuilt.fetchedMaps : 0,
      updatedMaps: 0,
      totalMaps: rebuilt.completed ? rebuilt.fetchedMaps : 0,
    );
  }

  var completed = false;
  var paused = false;

  while (true) {
    if (await _pauseRequested(shouldPause)) {
      paused = true;
      break;
    }
    final maxPages = options.maxPages;
    if (maxPages != null && state.pagesFetched >= maxPages) {
      paused = true;
      break;
    }

    final page = await effectiveFetchPage(
      before: state.nextBefore,
      after: state.since,
      pageSize: options.normalizedPageSize,
      sort: options.sort,
      automapper: options.automapper,
    );
    final docs = _docsFromPage(page);
    if (docs.isEmpty) {
      completed = true;
      break;
    }

    final sink = partialFile.openWrite(mode: FileMode.append);
    try {
      for (final doc in docs) {
        final id = doc['id']?.toString().trim().toLowerCase() ?? '';
        if (id.isEmpty || state.seenIds.contains(id)) {
          continue;
        }
        sink.writeln(jsonEncode(doc));
        state.seenIds.add(id);
        state.fetchedMaps += 1;
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    state.pagesFetched += 1;
    state.nextBefore = _nextBeforeCursor(docs.last);
    await state.write(stateFile);
    onProgress?.call(
      LocalCacheSnapshotProgress(
        fetchedMaps: state.fetchedMaps,
        pagesFetched: state.pagesFetched,
        completed: false,
        paused: false,
        nextBefore: state.nextBefore,
        outputFile: outputFile,
        stateFile: stateFile,
      ),
    );

    if (state.nextBefore == null) {
      completed = true;
      break;
    }
    if (options.delayBetweenRequests > Duration.zero) {
      await Future<void>.delayed(options.delayBetweenRequests);
    }
  }

  var addedMaps = 0;
  var updatedMaps = 0;
  var totalMaps = _docsFromPage(existing).length;
  if (completed) {
    existing = await _readLocalCacheSaverJson(outputFile);
    final merge = await _mergeIncrementalPartial(
      existing: existing,
      partialFile: partialFile,
      generatedAt: DateTime.now(),
    );
    await _writeLocalCacheSaverJson(outputFile, merge.json);
    addedMaps = merge.addedMaps;
    updatedMaps = merge.updatedMaps;
    totalMaps = merge.totalMaps;
    await _deleteIfExists(partialFile);
    await _deleteIfExists(stateFile);
  }

  final progress = LocalCacheSnapshotProgress(
    fetchedMaps: state.fetchedMaps,
    pagesFetched: state.pagesFetched,
    completed: completed,
    paused: paused,
    nextBefore: state.nextBefore,
    outputFile: outputFile,
    stateFile: stateFile,
  );
  onProgress?.call(progress);

  return LocalCacheSnapshotUpdateResult(
    outputFile: outputFile,
    stateFile: stateFile,
    fetchedMaps: state.fetchedMaps,
    pagesFetched: state.pagesFetched,
    completed: completed,
    paused: paused,
    addedMaps: addedMaps,
    updatedMaps: updatedMaps,
    totalMaps: totalMaps,
    since: state.since,
  );
}

Future<LocalCacheSnapshotBuildResult> buildLocalCacheSnapshot({
  required File outputFile,
  BeatSaverClient? client,
  LatestMapsPageFetcher? fetchPage,
  LocalCacheSnapshotOptions options = const LocalCacheSnapshotOptions(),
  LocalCacheSnapshotPauseCheck? shouldPause,
  LocalCacheSnapshotProgressCallback? onProgress,
  bool reset = false,
}) async {
  final stateFile = File('${outputFile.path}.snapshot_state.json');
  final partialFile = File('${outputFile.path}.partial.ndjson');
  final effectiveClient = client ?? BeatSaverClient();
  final effectiveFetchPage = fetchPage ??
      ({
        String? before,
        String? after,
        required int pageSize,
        required String sort,
        bool? automapper,
      }) {
        return effectiveClient.getLatestMapsPageRaw(
          before: before,
          after: after,
          pageSize: pageSize,
          sort: sort,
          automapper: automapper,
        );
      };

  if (reset) {
    await _deleteIfExists(stateFile);
    await _deleteIfExists(partialFile);
  }
  await outputFile.parent.create(recursive: true);

  var state = await _LocalCacheSnapshotState.read(stateFile);
  if (state == null || reset) {
    state = _LocalCacheSnapshotState(
      fetchedMaps: 0,
      pagesFetched: 0,
      seenIds: <String>{},
    );
    await state.write(stateFile);
  }

  var completed = false;
  var paused = false;

  while (true) {
    if (await _pauseRequested(shouldPause)) {
      paused = true;
      break;
    }
    final maxPages = options.maxPages;
    if (maxPages != null && state.pagesFetched >= maxPages) {
      paused = true;
      break;
    }

    final page = await effectiveFetchPage(
      before: state.nextBefore,
      pageSize: options.normalizedPageSize,
      sort: options.sort,
      automapper: options.automapper,
    );
    final docs = _docsFromPage(page);
    if (docs.isEmpty) {
      completed = true;
      break;
    }

    final sink = partialFile.openWrite(mode: FileMode.append);
    try {
      for (final doc in docs) {
        final id = doc['id']?.toString().trim().toLowerCase() ?? '';
        if (id.isEmpty || state.seenIds.contains(id)) {
          continue;
        }
        sink.writeln(jsonEncode(doc));
        state.seenIds.add(id);
        state.fetchedMaps += 1;
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    state.pagesFetched += 1;
    state.nextBefore = _nextBeforeCursor(docs.last);
    await state.write(stateFile);
    onProgress?.call(
      LocalCacheSnapshotProgress(
        fetchedMaps: state.fetchedMaps,
        pagesFetched: state.pagesFetched,
        completed: false,
        paused: false,
        nextBefore: state.nextBefore,
        outputFile: outputFile,
        stateFile: stateFile,
      ),
    );

    if (state.nextBefore == null) {
      completed = true;
      break;
    }
    if (options.delayBetweenRequests > Duration.zero) {
      await Future<void>.delayed(options.delayBetweenRequests);
    }
  }

  if (completed) {
    await _writeLocalCacheSaverFromPartial(
      partialFile: partialFile,
      outputFile: outputFile,
      generatedAt: DateTime.now(),
    );
    await _deleteIfExists(partialFile);
    await _deleteIfExists(stateFile);
  }

  final progress = LocalCacheSnapshotProgress(
    fetchedMaps: state.fetchedMaps,
    pagesFetched: state.pagesFetched,
    completed: completed,
    paused: paused,
    nextBefore: state.nextBefore,
    outputFile: outputFile,
    stateFile: stateFile,
  );
  onProgress?.call(progress);

  return LocalCacheSnapshotBuildResult(
    outputFile: outputFile,
    stateFile: stateFile,
    fetchedMaps: state.fetchedMaps,
    pagesFetched: state.pagesFetched,
    completed: completed,
    paused: paused,
  );
}

List<Map<String, dynamic>> _docsFromPage(Map<String, dynamic> page) {
  final docs = page['docs'];
  if (docs is! List) {
    return const [];
  }
  return docs.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<Map<String, dynamic>> _deletedDocsFromPage(Map<String, dynamic> page) {
  final docs = page['docs'];
  if (docs is! List) {
    return const [];
  }
  return docs.whereType<Map<String, dynamic>>().toList(growable: false);
}

LocalCacheDeletedMap? _deletedMapFromJson(Map<String, dynamic> json) {
  final id = json['id']?.toString().trim().toLowerCase() ?? '';
  if (id.isEmpty) {
    return null;
  }
  return LocalCacheDeletedMap(
    id: id,
    deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? ''),
  );
}

String? _deletedBeforeCursor(Map<String, dynamic> doc) {
  final value = doc['deletedAt']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String? _nextBeforeCursor(Map<String, dynamic> doc) {
  for (final key in const ['updatedAt', 'uploaded', 'createdAt']) {
    final value = doc[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  final versions = doc['versions'];
  if (versions is List && versions.isNotEmpty) {
    final first = versions.first;
    if (first is Map<String, dynamic>) {
      final createdAt = first['createdAt']?.toString().trim();
      if (createdAt != null && createdAt.isNotEmpty) {
        return createdAt;
      }
    }
  }
  return null;
}

Future<bool> _pauseRequested(LocalCacheSnapshotPauseCheck? check) async {
  if (check == null) {
    return false;
  }
  return await check();
}

Future<void> _writeLocalCacheSaverFromPartial({
  required File partialFile,
  required File outputFile,
  required DateTime generatedAt,
}) async {
  final tempOutput = File('${outputFile.path}.writing');
  final sink = tempOutput.openWrite();
  var first = true;
  var total = 0;
  sink.write('{"docs":[');
  if (await partialFile.exists()) {
    await for (final line in partialFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (!first) {
        sink.write(',');
      }
      first = false;
      total += 1;
      sink.write(trimmed);
    }
  }
  sink.write(
    '],"info":{"total":$total,"page":0,"itemsPerPage":$total,'
    '"generatedAt":"${generatedAt.toUtc().toIso8601String()}"}}',
  );
  await sink.flush();
  await sink.close();
  if (await outputFile.exists()) {
    await outputFile.delete();
  }
  await tempOutput.rename(outputFile.path);
}

Future<Map<String, dynamic>> _readLocalCacheSaverJson(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('LocalCache.saver must be a JSON object.');
  }
  return decoded;
}

Future<void> _writeLocalCacheSaverJson(
  File outputFile,
  Map<String, dynamic> json,
) async {
  final tempOutput = File('${outputFile.path}.writing');
  await tempOutput.writeAsString(jsonEncode(json), flush: true);
  if (await outputFile.exists()) {
    await outputFile.delete();
  }
  await tempOutput.rename(outputFile.path);
}

Future<_IncrementalMergeResult> _mergeIncrementalPartial({
  required Map<String, dynamic> existing,
  required File partialFile,
  required DateTime generatedAt,
}) async {
  final docs = _docsFromPage(existing).toList(growable: true);
  final indexesById = <String, int>{};
  for (var index = 0; index < docs.length; index += 1) {
    final id = docs[index]['id']?.toString().trim().toLowerCase() ?? '';
    if (id.isNotEmpty) {
      indexesById[id] = index;
    }
  }

  var addedMaps = 0;
  var updatedMaps = 0;
  if (await partialFile.exists()) {
    await for (final line in partialFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      final id = decoded['id']?.toString().trim().toLowerCase() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final existingIndex = indexesById[id];
      if (existingIndex == null) {
        indexesById[id] = docs.length;
        docs.add(decoded);
        addedMaps += 1;
      } else {
        docs[existingIndex] = decoded;
        updatedMaps += 1;
      }
    }
  }

  docs.sort((a, b) {
    final left = _sortCursor(a);
    final right = _sortCursor(b);
    return right.compareTo(left);
  });

  final merged = Map<String, dynamic>.from(existing);
  merged['docs'] = docs;
  final info = merged['info'] is Map<String, dynamic>
      ? Map<String, dynamic>.from(merged['info'] as Map<String, dynamic>)
      : <String, dynamic>{};
  info['total'] = docs.length;
  info['page'] = 0;
  info['itemsPerPage'] = docs.length;
  info['generatedAt'] = generatedAt.toUtc().toIso8601String();
  info['incrementalUpdatedAt'] = generatedAt.toUtc().toIso8601String();
  info['incrementalAdded'] = addedMaps;
  info['incrementalUpdated'] = updatedMaps;
  merged['info'] = info;

  return _IncrementalMergeResult(
    json: merged,
    addedMaps: addedMaps,
    updatedMaps: updatedMaps,
    totalMaps: docs.length,
  );
}

String? _latestCursorFromDocs(List<Map<String, dynamic>> docs) {
  String? latest;
  for (final doc in docs) {
    final cursor = _nextBeforeCursor(doc);
    if (cursor == null || cursor.isEmpty) {
      continue;
    }
    if (latest == null || cursor.compareTo(latest) > 0) {
      latest = cursor;
    }
  }
  return latest;
}

String _sortCursor(Map<String, dynamic> doc) {
  return _nextBeforeCursor(doc) ?? '';
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}

class _IncrementalMergeResult {
  const _IncrementalMergeResult({
    required this.json,
    required this.addedMaps,
    required this.updatedMaps,
    required this.totalMaps,
  });

  final Map<String, dynamic> json;
  final int addedMaps;
  final int updatedMaps;
  final int totalMaps;
}

class _LocalCacheSnapshotState {
  _LocalCacheSnapshotState({
    required this.fetchedMaps,
    required this.pagesFetched,
    required this.seenIds,
    this.nextBefore,
  });

  factory _LocalCacheSnapshotState.fromJson(Map<String, dynamic> json) {
    final seen = json['seenIds'];
    return _LocalCacheSnapshotState(
      fetchedMaps: _intValue(json['fetchedMaps']),
      pagesFetched: _intValue(json['pagesFetched']),
      nextBefore: json['nextBefore']?.toString(),
      seenIds: seen is List
          ? seen
              .map((value) => value.toString().trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet()
          : <String>{},
    );
  }

  final Set<String> seenIds;
  int fetchedMaps;
  int pagesFetched;
  String? nextBefore;

  Map<String, Object?> toJson() {
    return {
      'fetchedMaps': fetchedMaps,
      'pagesFetched': pagesFetched,
      'nextBefore': nextBefore,
      'seenIds': seenIds.toList(growable: false)..sort(),
    };
  }

  static Future<_LocalCacheSnapshotState?> read(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('LocalCache snapshot state must be JSON.');
    }
    return _LocalCacheSnapshotState.fromJson(decoded);
  }

  Future<void> write(File file) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
      flush: true,
    );
  }
}

class _LocalCacheSnapshotIncrementalState {
  _LocalCacheSnapshotIncrementalState({
    required this.since,
    required this.fetchedMaps,
    required this.pagesFetched,
    required this.seenIds,
    this.nextBefore,
  });

  factory _LocalCacheSnapshotIncrementalState.fromJson(
    Map<String, dynamic> json,
  ) {
    final seen = json['seenIds'];
    return _LocalCacheSnapshotIncrementalState(
      since: json['since']?.toString(),
      fetchedMaps: _intValue(json['fetchedMaps']),
      pagesFetched: _intValue(json['pagesFetched']),
      nextBefore: json['nextBefore']?.toString(),
      seenIds: seen is List
          ? seen
              .map((value) => value.toString().trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet()
          : <String>{},
    );
  }

  final String? since;
  final Set<String> seenIds;
  int fetchedMaps;
  int pagesFetched;
  String? nextBefore;

  Map<String, Object?> toJson() {
    return {
      'since': since,
      'fetchedMaps': fetchedMaps,
      'pagesFetched': pagesFetched,
      'nextBefore': nextBefore,
      'seenIds': seenIds.toList(growable: false)..sort(),
    };
  }

  static Future<_LocalCacheSnapshotIncrementalState?> read(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'LocalCache incremental snapshot state must be JSON.',
      );
    }
    return _LocalCacheSnapshotIncrementalState.fromJson(decoded);
  }

  Future<void> write(File file) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
      flush: true,
    );
  }
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
