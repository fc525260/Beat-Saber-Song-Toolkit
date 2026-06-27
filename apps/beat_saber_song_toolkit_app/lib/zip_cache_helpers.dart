import 'dart:io';

import 'output_helpers.dart';

class ZipCacheEntryForTest {
  const ZipCacheEntryForTest({
    required this.name,
    required this.path,
    required this.bytes,
    required this.modified,
  });

  final String name;
  final String path;
  final int bytes;
  final DateTime modified;

  String? get mapId => zipCacheMapIdForTest(name);
}

String? zipCacheMapIdForTest(String fileName) {
  final match = RegExp(
    r'^([0-9a-fA-F]{1,8})-[0-9a-fA-F]+\.zip$',
    caseSensitive: false,
  ).firstMatch(fileName);
  return match?.group(1)?.toLowerCase();
}

class ZipCacheSummaryForTest {
  const ZipCacheSummaryForTest({
    required this.files,
    required this.recognized,
    required this.bytes,
  });

  final int files;
  final int recognized;
  final int bytes;

  String get filesLabel => '文件 $files';

  String get recognizedLabel => '可识别 $recognized';

  String get sizeLabel => '大小 ${formatBytesForTest(bytes)}';
}

Future<List<ZipCacheEntryForTest>> scanZipCacheForTest(
  Directory directory,
) async {
  if (!await directory.exists()) {
    return const [];
  }

  final entries = <ZipCacheEntryForTest>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.zip')) {
      continue;
    }
    final stat = await entity.stat();
    entries.add(
      ZipCacheEntryForTest(
        name: entity.uri.pathSegments.last,
        path: entity.path,
        bytes: stat.size,
        modified: stat.modified,
      ),
    );
  }
  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

List<String> zipCacheMapIdsForTest(Iterable<ZipCacheEntryForTest> entries) {
  return entries
      .map((entry) => entry.mapId?.trim().toLowerCase())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

ZipCacheSummaryForTest zipCacheSummaryForTest(
  Iterable<ZipCacheEntryForTest> entries,
) {
  var files = 0;
  var recognized = 0;
  var bytes = 0;
  for (final entry in entries) {
    files += 1;
    bytes += entry.bytes;
    if (entry.mapId != null) {
      recognized += 1;
    }
  }
  return ZipCacheSummaryForTest(
    files: files,
    recognized: recognized,
    bytes: bytes,
  );
}

String zipCacheExportListForTest(Iterable<ZipCacheEntryForTest> entries) {
  return entries.map(zipCacheExportLineForTest).join('\n');
}

String zipCacheExportLineForTest(ZipCacheEntryForTest entry) {
  final fields = [
    entry.name,
    entry.bytes.toString(),
    exportDateForTest(entry.modified),
    entry.path,
  ].map((value) => value.replaceAll(RegExp(r'[\r\n\t]+'), ' '));
  return fields.join('\t');
}
