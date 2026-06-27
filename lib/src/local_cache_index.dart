import 'dart:convert';
import 'dart:io';

import 'beatsaver_models.dart';

const int localCacheIndexFormatVersion = 1;

class LocalCacheIndex {
  LocalCacheIndex({
    required this.version,
    required this.sourcePath,
    required this.sourceBytes,
    required this.sourceModifiedMilliseconds,
    required this.entries,
  });

  factory LocalCacheIndex.fromMaps({
    required File sourceFile,
    required FileStat sourceStat,
    required Iterable<BeatSaverMap> maps,
  }) {
    return LocalCacheIndex(
      version: localCacheIndexFormatVersion,
      sourcePath: sourceFile.path,
      sourceBytes: sourceStat.size,
      sourceModifiedMilliseconds: sourceStat.modified.millisecondsSinceEpoch,
      entries: maps
          .map(LocalCacheIndexEntry.fromMap)
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: false),
    );
  }

  factory LocalCacheIndex.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return LocalCacheIndex(
      version: _intValue(json['version']),
      sourcePath: json['sourcePath']?.toString() ?? '',
      sourceBytes: _intValue(json['sourceBytes']),
      sourceModifiedMilliseconds: _intValue(
        json['sourceModifiedMilliseconds'],
      ),
      entries: rawEntries is List
          ? rawEntries
              .whereType<Map<String, dynamic>>()
              .map(LocalCacheIndexEntry.fromJson)
              .where((entry) => entry.id.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }

  final int version;
  final String sourcePath;
  final int sourceBytes;
  final int sourceModifiedMilliseconds;
  final List<LocalCacheIndexEntry> entries;
  Map<String, LocalCacheIndexEntry>? _hashEntries;

  bool matchesSource(File sourceFile, FileStat sourceStat) {
    return version == localCacheIndexFormatVersion &&
        sourcePath == sourceFile.path &&
        sourceBytes == sourceStat.size &&
        sourceModifiedMilliseconds ==
            sourceStat.modified.millisecondsSinceEpoch;
  }

  LocalCacheIndexEntry? getByHash(String hash) {
    final normalized = hash.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return _hashIndex[normalized];
  }

  Map<String, LocalCacheIndexEntry> get _hashIndex {
    final cached = _hashEntries;
    if (cached != null) {
      return cached;
    }
    final index = <String, LocalCacheIndexEntry>{};
    for (final entry in entries) {
      if (entry.hash.isNotEmpty && !index.containsKey(entry.hash)) {
        index[entry.hash] = entry;
      }
    }
    _hashEntries = index;
    return index;
  }

  List<LocalCacheIndexEntry> search(String query) {
    final tokens = query
        .split(RegExp(r'[\s,，;；]+'))
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return entries;
    }
    return entries
        .where(
          (entry) => tokens.every((token) => entry.searchText.contains(token)),
        )
        .toList(growable: false);
  }

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'sourcePath': sourcePath,
      'sourceBytes': sourceBytes,
      'sourceModifiedMilliseconds': sourceModifiedMilliseconds,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}

class LocalCacheIndexEntry {
  const LocalCacheIndexEntry({
    required this.id,
    required this.hash,
    required this.name,
    required this.songName,
    required this.songAuthorName,
    required this.levelAuthorName,
    required this.uploaderName,
    required this.searchText,
  });

  factory LocalCacheIndexEntry.fromMap(BeatSaverMap map) {
    final metadata = map.metadata;
    final hash = (map.latestVersion?.hash ?? '').trim().toLowerCase();
    final fields = [
      map.id,
      hash,
      map.name,
      metadata.songName,
      metadata.songSubName,
      metadata.songAuthorName,
      metadata.levelAuthorName,
      map.uploaderName ?? '',
      ...map.tags,
    ];
    return LocalCacheIndexEntry(
      id: map.id.trim().toLowerCase(),
      hash: hash,
      name: map.name,
      songName: metadata.songName,
      songAuthorName: metadata.songAuthorName,
      levelAuthorName: metadata.levelAuthorName,
      uploaderName: map.uploaderName ?? '',
      searchText: fields
          .map((field) => field.trim().toLowerCase())
          .where((field) => field.isNotEmpty)
          .join('\n'),
    );
  }

  factory LocalCacheIndexEntry.fromJson(Map<String, dynamic> json) {
    return LocalCacheIndexEntry(
      id: json['id']?.toString() ?? '',
      hash: json['hash']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      songName: json['songName']?.toString() ?? '',
      songAuthorName: json['songAuthorName']?.toString() ?? '',
      levelAuthorName: json['levelAuthorName']?.toString() ?? '',
      uploaderName: json['uploaderName']?.toString() ?? '',
      searchText: json['searchText']?.toString() ?? '',
    );
  }

  final String id;
  final String hash;
  final String name;
  final String songName;
  final String songAuthorName;
  final String levelAuthorName;
  final String uploaderName;
  final String searchText;

  Map<String, String> toJson() {
    return {
      'id': id,
      'hash': hash,
      'name': name,
      'songName': songName,
      'songAuthorName': songAuthorName,
      'levelAuthorName': levelAuthorName,
      'uploaderName': uploaderName,
      'searchText': searchText,
    };
  }
}

Future<LocalCacheIndex?> readLocalCacheIndex(File indexFile) async {
  if (!await indexFile.exists()) {
    return null;
  }
  final decoded = jsonDecode(await indexFile.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('LocalCache index must be a JSON object.');
  }
  return LocalCacheIndex.fromJson(decoded);
}

Future<void> writeLocalCacheIndex(
  File indexFile,
  LocalCacheIndex index,
) async {
  await indexFile.parent.create(recursive: true);
  await indexFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(index.toJson()),
    flush: true,
  );
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
