import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'beatsaver_models.dart';

Future<BeatSaverSearchResponse> readLocalCacheSaver(File file) async {
  return Isolate.run(() => readLocalCacheSaverString(file.readAsStringSync()));
}

Future<LocalCacheSaverInfo> readLocalCacheSaverInfo(File file) async {
  return Isolate.run(
      () => readLocalCacheSaverInfoString(file.readAsStringSync()));
}

BeatSaverSearchResponse readLocalCacheSaverString(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('LocalCache.saver must be a JSON object.');
  }
  return BeatSaverSearchResponse.fromJson(decoded);
}

LocalCacheSaverInfo readLocalCacheSaverInfoString(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('LocalCache.saver must be a JSON object.');
  }
  final info = decoded['info'];
  if (info is! Map<String, dynamic>) {
    return const LocalCacheSaverInfo();
  }
  return LocalCacheSaverInfo.fromJson(info);
}

class LocalCacheSaverInfo {
  const LocalCacheSaverInfo({
    this.generatedAt,
    this.incrementalUpdatedAt,
    this.incrementalAdded = 0,
    this.incrementalUpdated = 0,
  });

  factory LocalCacheSaverInfo.fromJson(Map<String, dynamic> json) {
    return LocalCacheSaverInfo(
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      incrementalUpdatedAt: DateTime.tryParse(
        json['incrementalUpdatedAt']?.toString() ?? '',
      ),
      incrementalAdded: _intValue(json['incrementalAdded']),
      incrementalUpdated: _intValue(json['incrementalUpdated']),
    );
  }

  final DateTime? generatedAt;
  final DateTime? incrementalUpdatedAt;
  final int incrementalAdded;
  final int incrementalUpdated;
}

Future<DateTime?> readLocalCacheTime(File file) async {
  if (!await file.exists()) {
    return null;
  }
  return parseLocalCacheTime(await file.readAsString());
}

DateTime? parseLocalCacheTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final numeric = int.tryParse(trimmed);
  if (numeric != null) {
    final milliseconds = trimmed.length >= 13 ? numeric : numeric * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  return DateTime.tryParse(trimmed);
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
