import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class InstalledSongEntry {
  const InstalledSongEntry({
    required this.directory,
    required this.directoryName,
    required this.hasInfoDat,
    this.hasAudioFile = false,
    this.info,
    this.mapId,
    this.title,
  });

  final Directory directory;
  final String directoryName;
  final bool hasInfoDat;
  final bool hasAudioFile;
  final InstalledSongInfo? info;
  final String? mapId;
  final String? title;
}

class InstalledSongInfo {
  const InstalledSongInfo({
    required this.songName,
    required this.songSubName,
    required this.songAuthorName,
    required this.levelAuthorName,
    required this.beatsPerMinute,
    this.coverImageFilename = '',
    this.difficulties = const [],
  });

  factory InstalledSongInfo.fromJson(Map<String, dynamic> json) {
    return InstalledSongInfo(
      songName: _stringField(json, '_songName', 'songName'),
      songSubName: _stringField(json, '_songSubName', 'songSubName'),
      songAuthorName: _stringField(json, '_songAuthorName', 'songAuthorName'),
      levelAuthorName:
          _stringField(json, '_levelAuthorName', 'levelAuthorName'),
      beatsPerMinute: _doubleField(json, '_beatsPerMinute', 'beatsPerMinute'),
      coverImageFilename: _stringField(
        json,
        '_coverImageFilename',
        'coverImageFilename',
      ),
      difficulties: _difficultyNames(json),
    );
  }

  final String songName;
  final String songSubName;
  final String songAuthorName;
  final String levelAuthorName;
  final double beatsPerMinute;
  final String coverImageFilename;
  final List<String> difficulties;
}

Future<List<InstalledSongEntry>> scanInstalledLibrary(
  Directory libraryDirectory,
) async {
  if (!await libraryDirectory.exists()) {
    return const [];
  }

  final entries = <InstalledSongEntry>[];
  await for (final entity in libraryDirectory.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }

    final directoryName = p.basename(entity.path);
    final parsed = parseInstalledDirectoryName(directoryName);
    final info = await readInstalledSongInfo(entity);
    final hasAudioFile = await containsAudioFile(entity);
    entries.add(
      InstalledSongEntry(
        directory: entity,
        directoryName: directoryName,
        hasInfoDat: info != null,
        hasAudioFile: hasAudioFile,
        info: info,
        mapId: parsed.mapId,
        title:
            info?.songName.isNotEmpty == true ? info?.songName : parsed.title,
      ),
    );
  }

  entries.sort((a, b) => a.directoryName.compareTo(b.directoryName));
  return entries;
}

Future<InstalledSongEntry?> deleteInstalledMapById(
  Directory libraryDirectory,
  String mapId,
) async {
  final normalizedMapId = mapId.trim().toLowerCase();
  if (normalizedMapId.isEmpty) {
    return null;
  }

  final entries = await scanInstalledLibrary(libraryDirectory);
  for (final entry in entries) {
    if (entry.mapId?.toLowerCase() != normalizedMapId) {
      continue;
    }
    if (!entry.hasInfoDat) {
      continue;
    }

    await entry.directory.delete(recursive: true);
    return entry;
  }

  return null;
}

Future<bool> containsInfoDat(Directory directory) async {
  return await _findInfoDat(directory) != null;
}

Future<bool> containsAudioFile(Directory directory) async {
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File && _isAudioFile(entity.path)) {
      return true;
    }
  }
  return false;
}

Future<InstalledSongInfo?> readInstalledSongInfo(Directory directory) async {
  final infoFile = await _findInfoDat(directory);
  if (infoFile == null) {
    return null;
  }

  try {
    final decoded = jsonDecode(await infoFile.readAsString());
    if (decoded is Map<String, dynamic>) {
      return InstalledSongInfo.fromJson(decoded);
    }
  } on FormatException {
    return null;
  }
  return null;
}

bool _isAudioFile(String path) {
  return switch (p.extension(path).toLowerCase()) {
    '.egg' || '.ogg' || '.wav' => true,
    _ => false,
  };
}

Future<String?> computeInstalledSongHash(Directory directory) async {
  final infoFile = await _findInfoDat(directory);
  if (infoFile == null) {
    return null;
  }

  final Uint8List infoBytes;
  final Object? decoded;
  try {
    infoBytes = await infoFile.readAsBytes();
    decoded = jsonDecode(utf8.decode(infoBytes));
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) {
    return null;
  }

  final beatmapFiles = _beatmapFilenames(decoded);
  if (beatmapFiles.isEmpty) {
    return null;
  }

  final bytes = BytesBuilder(copy: false)..add(infoBytes);
  for (final filename in beatmapFiles) {
    final file = File(p.join(directory.path, filename));
    if (!await file.exists()) {
      return null;
    }
    bytes.add(await file.readAsBytes());
  }
  return sha1.convert(bytes.takeBytes()).toString();
}

Future<File?> _findInfoDat(Directory directory) async {
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File && p.basename(entity.path).toLowerCase() == 'info.dat') {
      return entity;
    }
  }
  return null;
}

List<String> _beatmapFilenames(Map<String, dynamic> json) {
  final sets = json['_difficultyBeatmapSets'] ?? json['difficultyBeatmapSets'];
  if (sets is! List) {
    return const [];
  }
  final filenames = <String>[];
  for (final set in sets) {
    if (set is! Map) {
      continue;
    }
    final beatmaps = set['_difficultyBeatmaps'] ?? set['difficultyBeatmaps'];
    if (beatmaps is! List) {
      continue;
    }
    for (final beatmap in beatmaps) {
      if (beatmap is! Map) {
        continue;
      }
      final filename =
          (beatmap['_beatmapFilename'] ?? beatmap['beatmapFilename'])
              ?.toString()
              .trim();
      if (filename != null && filename.isNotEmpty) {
        filenames.add(filename);
      }
    }
  }
  return filenames;
}

({String? mapId, String? title}) parseInstalledDirectoryName(
  String directoryName,
) {
  final match = RegExp(
    r'^([0-9a-fA-F]+)(?:\s*-\s*|\s+|\(|_|$)(.*)$',
  ).firstMatch(directoryName);
  if (match == null) {
    return (mapId: null, title: directoryName);
  }
  final title = (match.group(2) ?? '').trim();
  return (mapId: match.group(1), title: title.isEmpty ? directoryName : title);
}

String _stringField(Map<String, dynamic> json, String legacyKey, String key) {
  return (json[legacyKey] ?? json[key])?.toString() ?? '';
}

double _doubleField(Map<String, dynamic> json, String legacyKey, String key) {
  final value = json[legacyKey] ?? json[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _difficultyNames(Map<String, dynamic> json) {
  final sets = json['_difficultyBeatmapSets'] ?? json['difficultyBeatmapSets'];
  if (sets is! List) {
    return const [];
  }
  final names = <String>{};
  for (final set in sets) {
    if (set is! Map) {
      continue;
    }
    final beatmaps = set['_difficultyBeatmaps'] ?? set['difficultyBeatmaps'];
    if (beatmaps is! List) {
      continue;
    }
    for (final beatmap in beatmaps) {
      if (beatmap is! Map) {
        continue;
      }
      final value = beatmap['_difficulty'] ?? beatmap['difficulty'];
      final name = value?.toString().trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
  }
  return names.toList(growable: false)..sort();
}
