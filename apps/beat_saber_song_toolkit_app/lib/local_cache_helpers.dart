import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

import 'output_helpers.dart';

class LocalCacheSummaryForTest {
  const LocalCacheSummaryForTest({
    required this.totalMaps,
    required this.filteredMaps,
    required this.uploaders,
    required this.withHash,
  });

  final int totalMaps;
  final int filteredMaps;
  final int uploaders;
  final int withHash;
}

int localCacheTotalPagesForTest({
  required int itemCount,
  required int pageSize,
}) {
  if (pageSize <= 0) {
    return 0;
  }
  return (itemCount / pageSize).ceil();
}

List<T> pagedLocalCacheItemsForTest<T>(
  List<T> items, {
  required int page,
  required int pageSize,
}) {
  if (pageSize <= 0) {
    return items;
  }
  final start = page * pageSize;
  if (start < 0 || start >= items.length) {
    return const [];
  }
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

List<String> localCacheSkipIdsForTest({
  required Iterable<String> existingIds,
  required Iterable<String> filteredIds,
}) {
  return mergedSkipIdsForTest(existingIds: existingIds, newIds: filteredIds);
}

List<String> mergedSkipIdsForTest({
  required Iterable<String> existingIds,
  required Iterable<String> newIds,
}) {
  return <String>{
    ...existingIds
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty),
    ...newIds.map((id) => id.trim().toLowerCase()).where((id) => id.isNotEmpty),
  }.toList()..sort();
}

LocalCacheSummaryForTest localCacheSummaryForTest({
  required int totalMaps,
  required Iterable<BeatSaverMap> filteredMaps,
}) {
  final maps = filteredMaps.toList(growable: false);
  final uploaders = maps
      .map((map) => map.uploaderName ?? '')
      .where((name) => name.isNotEmpty)
      .toSet();
  final withHash = maps
      .where((map) => (map.latestVersion?.hash ?? '').isNotEmpty)
      .length;
  return LocalCacheSummaryForTest(
    totalMaps: totalMaps,
    filteredMaps: maps.length,
    uploaders: uploaders.length,
    withHash: withHash,
  );
}

Map<String, BeatSaverMap> localCacheHashIndexForTest(
  Iterable<BeatSaverMap> maps,
) {
  final index = <String, BeatSaverMap>{};
  for (final map in maps) {
    final hash = (map.latestVersion?.hash ?? '').trim().toLowerCase();
    if (hash.isEmpty || index.containsKey(hash)) {
      continue;
    }
    index[hash] = map;
  }
  return index;
}

bool localCacheFilterCacheHitForTest({
  required Object source,
  required Object cachedSource,
  required String signature,
  required String cachedSignature,
}) {
  return identical(source, cachedSource) && signature == cachedSignature;
}

bool canUseLocalCacheIndexSearchForTest({
  required String query,
  required bool regexSearchMode,
  required String uploader,
  required String filterText,
  required bool filterRegexMode,
  required String includeTags,
  required String excludeTags,
  required String requiredComponents,
  required String excludedComponents,
  required String difficultyFilter,
  required String characteristicFilter,
  required bool hasNumericOrDateFilters,
  required bool hasSwitchFilters,
}) {
  return query.trim().isNotEmpty &&
      !regexSearchMode &&
      uploader.trim().isEmpty &&
      filterText.trim().isEmpty &&
      !filterRegexMode &&
      includeTags.trim().isEmpty &&
      excludeTags.trim().isEmpty &&
      requiredComponents.trim().isEmpty &&
      excludedComponents.trim().isEmpty &&
      difficultyFilter.trim().isEmpty &&
      characteristicFilter.trim().isEmpty &&
      !hasNumericOrDateFilters &&
      !hasSwitchFilters;
}

String localCacheReadStatusForTest({
  required int mapCount,
  required int filteredCount,
  required int pageNumber,
  required int totalPages,
}) {
  return '本地数据缓存：读取 $mapCount 张，筛选后 $filteredCount 张，'
      '第 $pageNumber/${totalPages == 0 ? 1 : totalPages} 页';
}

String localCacheReadLogForTest({
  required int mapCount,
  required int filteredCount,
  required int visibleCount,
  required int bytes,
  required DateTime modified,
  DateTime? generatedAt,
}) {
  final timeLabel = generatedAt == null
      ? '文件修改时间 ${formatDateTimeForTest(modified)}'
      : '生成时间 ${formatDateTimeForTest(generatedAt)}，'
            '文件修改时间 ${formatDateTimeForTest(modified)}';
  return 'LocalCache.saver 读取完成：$mapCount 张，'
      '筛选后 $filteredCount 张，显示 $visibleCount 张，'
      '文件 ${formatBytesForTest(bytes)}，$timeLabel';
}

String playlistHashLookupSourceForTest({
  required String hash,
  required BeatSaverHashCache hashCache,
  required Map<String, BeatSaverMap> localCacheHashIndex,
  required LocalCacheIndex? localCacheIndex,
}) {
  final normalized = hash.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'none';
  }
  final cached = hashCache.get(normalized);
  if (cached != null && cached.id.isNotEmpty) {
    return 'hash-cache';
  }
  if (localCacheHashIndex.containsKey(normalized)) {
    return 'local-cache-memory';
  }
  if (localCacheIndex?.getByHash(normalized) != null) {
    return 'local-cache-index';
  }
  return 'beatsaver-api';
}

String mapExportListForTest(Iterable<BeatSaverMap> maps) {
  return maps.map(mapExportLineForTest).join('\n');
}

String mapExportLineForTest(BeatSaverMap map) {
  final title = _mapTitleForExport(map).replaceAll(RegExp(r'[\r\n]+'), ' ');
  return '${map.id}\t$title\thttps://beatsaver.com/maps/${map.id}';
}

String localCacheExportLineForTest(BeatSaverMap map) {
  return mapExportLineForTest(map);
}

String targetExportListForTest(Iterable<BeatSaverMap> maps) {
  return maps.map(targetExportLineForTest).join('\n');
}

String targetExportLineForTest(BeatSaverMap map) {
  final title = _mapTitleForExport(map).replaceAll(RegExp(r'[\r\n\t]+'), ' ');
  return '${map.id}\t$title';
}

Future<String?> fastLogStartupProblemForTest(String localCacheSaverPath) async {
  final path = localCacheSaverPath.trim();
  if (path.isEmpty) {
    return '快速输出需要先配置 LocalCache.saver 路径';
  }
  final type = await FileSystemEntity.type(path);
  if (type != FileSystemEntityType.file) {
    return 'LocalCache.saver 不存在或不是文件：$path';
  }
  return null;
}

String localCacheAgeLabelForTest({
  required DateTime? generatedAt,
  required DateTime modified,
  required DateTime now,
}) {
  final base = generatedAt ?? modified;
  final age = now.difference(base);
  if (age.inDays >= 1) {
    return '快照 ${age.inDays} 天前';
  }
  if (age.inHours >= 1) {
    return '快照 ${age.inHours} 小时前';
  }
  if (age.inMinutes >= 1) {
    return '快照 ${age.inMinutes} 分钟前';
  }
  return '快照刚更新';
}

String localCacheIncrementalLabelForTest({
  required DateTime updatedAt,
  required int added,
  required int updated,
}) {
  return '增量 ${exportDateForTest(updatedAt)} +$added / 更新 $updated';
}

List<String> localCacheDeletedAuditExportRowsForTest(
  LocalCacheDeletedAuditResult audit,
) {
  return [
    'id\tdeletedAt\tinLocalCache',
    ...audit.candidates.map((candidate) {
      return [
        candidate.id,
        candidate.deletedAt?.toUtc().toIso8601String() ?? '',
        candidate.inLocalCache ? 'yes' : 'no',
      ].join('\t');
    }),
  ];
}

String formatDateTimeForTest(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${exportDateForTest(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
}

String _mapTitleForExport(BeatSaverMap map) {
  return map.metadata.songName.isEmpty ? map.name : map.metadata.songName;
}
