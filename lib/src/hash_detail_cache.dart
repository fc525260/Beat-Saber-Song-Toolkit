import 'dart:convert';
import 'dart:io';

import 'beatsaver_models.dart';

class BeatSaverHashDetail {
  const BeatSaverHashDetail({
    required this.id,
    required this.name,
    required this.description,
  });

  factory BeatSaverHashDetail.fromJson(Map<String, dynamic> json) {
    return BeatSaverHashDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  factory BeatSaverHashDetail.fromMap(BeatSaverMap map) {
    return BeatSaverHashDetail(
      id: map.id,
      name: map.name,
      description: map.description,
    );
  }

  final String id;
  final String name;
  final String description;

  Map<String, String> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}

class BeatSaverHashCache {
  const BeatSaverHashCache({
    required this.cacheDate,
    required this.data,
  });

  factory BeatSaverHashCache.empty({DateTime? now}) {
    return BeatSaverHashCache(
      cacheDate: _cacheDate(now ?? DateTime.now()),
      data: const {},
    );
  }

  factory BeatSaverHashCache.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return BeatSaverHashCache(
      cacheDate: json['_cache_date']?.toString() ?? '',
      data: rawData is Map
          ? rawData.map((key, value) {
              return MapEntry(
                key.toString().trim().toLowerCase(),
                value is Map<String, dynamic>
                    ? BeatSaverHashDetail.fromJson(value)
                    : const BeatSaverHashDetail(
                        id: '',
                        name: '',
                        description: '',
                      ),
              );
            })
          : const {},
    );
  }

  final String cacheDate;
  final Map<String, BeatSaverHashDetail> data;

  BeatSaverHashDetail? get(String hash) {
    return data[hash.trim().toLowerCase()];
  }

  BeatSaverHashCache put(String hash, BeatSaverHashDetail detail) {
    final normalized = hash.trim().toLowerCase();
    if (normalized.isEmpty) {
      return this;
    }
    return BeatSaverHashCache(
      cacheDate: cacheDate,
      data: {...data, normalized: detail},
    );
  }

  Map<String, Object?> toJson() {
    return {
      '_cache_date': cacheDate,
      'data': data.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

Future<BeatSaverHashCache> readBeatSaverHashCache(File file) async {
  if (!await file.exists()) {
    return BeatSaverHashCache.empty();
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected hash cache JSON object.');
  }
  return BeatSaverHashCache.fromJson(decoded);
}

Future<void> writeBeatSaverHashCache(
  File file,
  BeatSaverHashCache cache,
) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(cache.toJson()),
    flush: true,
  );
}

String _cacheDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
