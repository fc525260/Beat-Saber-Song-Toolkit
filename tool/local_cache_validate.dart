import 'dart:math';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final cachePath = _option(args, '--cache=') ?? 'LocalCache.saver';
  final sampleSize =
      _intOption(args, '--api-sample=', fallback: 0).clamp(0, 50);
  final seed = _intOption(args, '--seed=', fallback: 20260618);
  final cacheFile = File(cachePath);
  if (!await cacheFile.exists()) {
    stderr.writeln('LocalCache.saver not found: ${cacheFile.path}');
    exitCode = 66;
    return;
  }

  final response = await readLocalCacheSaver(cacheFile);
  final maps = response.maps;
  final ids = <String>{};
  final duplicateIds = <String>{};
  final hashes = <String>{};
  final duplicateHashes = <String>{};
  final errors = <String>[];
  final warnings = <String>[];

  for (final map in maps) {
    final id = map.id.trim().toLowerCase();
    if (id.isEmpty) {
      errors.add('empty id: ${map.name}');
    } else if (!ids.add(id)) {
      duplicateIds.add(id);
    }
    if (map.name.trim().isEmpty) {
      warnings.add('empty name: $id');
    }
    if (map.metadata.songName.trim().isEmpty) {
      warnings.add('empty metadata.songName: $id');
    }
    if (map.versions.isEmpty) {
      errors.add('empty versions: $id');
    }
    for (final version in map.versions) {
      final hash = version.hash.trim().toUpperCase();
      if (hash.isEmpty) {
        errors.add('empty hash: $id');
      } else if (!hashes.add(hash)) {
        duplicateHashes.add(hash);
      }
      if (version.downloadUrl.trim().isEmpty) {
        errors.add('empty downloadURL: $id');
      }
    }
  }

  print('cache=${cacheFile.path}');
  print('maps=${maps.length}');
  print('uniqueIds=${ids.length}');
  print('duplicateIds=${duplicateIds.length}');
  print('uniqueHashes=${hashes.length}');
  print('duplicateHashes=${duplicateHashes.length}');
  print('errors=${errors.length}');
  for (final entry in errors.take(10)) {
    print('errorSample=$entry');
  }
  print('warnings=${warnings.length}');
  for (final entry in warnings.take(10)) {
    print('warningSample=$entry');
  }

  final sample = _sampleMaps(maps, sampleSize, seed);
  var apiChecked = 0;
  var apiMismatches = 0;
  var apiMissing = 0;
  if (sample.isNotEmpty) {
    final client = BeatSaverClient(
      requestTimeout: const Duration(seconds: 30),
      requestRetryCount: 1,
    );
    for (final local in sample) {
      BeatSaverMap remote;
      try {
        remote = await client.getMapById(local.id);
      } on HttpException catch (error) {
        apiMissing += 1;
        print('apiMissing id=${local.id} error=${error.message}');
        continue;
      }
      apiChecked += 1;
      final localHash = local.latestVersion?.hash.toUpperCase();
      final remoteHash = remote.latestVersion?.hash.toUpperCase();
      final nameMatches = local.name == remote.name;
      final hashMatches = localHash == remoteHash;
      if (!nameMatches || !hashMatches) {
        apiMismatches += 1;
        print(
          'apiMismatch id=${local.id} '
          'nameLocal="${local.name}" nameRemote="${remote.name}" '
          'hashLocal=$localHash hashRemote=$remoteHash',
        );
      }
    }
  }
  print('apiChecked=$apiChecked');
  print('apiMissing=$apiMissing');
  print('apiMismatches=$apiMismatches');

  if (duplicateIds.isNotEmpty || errors.isNotEmpty || apiMismatches > 0) {
    exitCode = 1;
    return;
  }
  print('localCacheValidate=passed');
}

List<BeatSaverMap> _sampleMaps(List<BeatSaverMap> maps, int count, int seed) {
  if (count <= 0 || maps.isEmpty) {
    return const [];
  }
  final random = Random(seed);
  final indexes = <int>{};
  while (indexes.length < count && indexes.length < maps.length) {
    indexes.add(random.nextInt(maps.length));
  }
  return indexes.map((index) => maps[index]).toList(growable: false);
}

String? _option(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

int _intOption(List<String> args, String prefix, {required int fallback}) {
  final value = _option(args, prefix);
  return value == null ? fallback : int.tryParse(value) ?? fallback;
}

const _usage = r'''
Usage:
  dart run tool\local_cache_validate.dart --cache=PATH [options]

Options:
  --cache=PATH  LocalCache.saver path. Defaults to project LocalCache.saver.
  --api-sample=N
                Number of random maps to compare against BeatSaver API.
                Defaults to 0 to keep validation offline. Maximum 50.
  --seed=N      Deterministic random seed. Defaults to 20260618.
  --help, -h    Show this help.

Validation checks local structure, duplicate ids, and required version fields.
It does not contact BeatSaver unless --api-sample is explicitly provided.
''';
