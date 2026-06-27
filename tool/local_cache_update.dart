import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final cachePath = _option(args, '--cache=');
  if (cachePath == null) {
    stderr.writeln('Missing --cache=PATH.');
    print(_usage);
    exitCode = 64;
    return;
  }
  if (!args.contains('--allow-network')) {
    stderr.writeln(
      'This tool contacts BeatSaver and updates LocalCache.saver. '
      'Re-run with --allow-network only when a cache maintenance update was '
      'explicitly requested.',
    );
    exitCode = 64;
    return;
  }

  final cacheFile = File(cachePath);
  if (!await cacheFile.exists()) {
    stderr.writeln('LocalCache.saver not found: ${cacheFile.path}');
    exitCode = 66;
    return;
  }

  final pageSize =
      _intOption(args, '--page-size=', fallback: 100).clamp(1, 100);
  final delayMs = _intOption(args, '--delay-ms=', fallback: 750);
  final maxPages = _optionalIntOption(args, '--max-pages=');
  final backupDir = Directory(
    _option(args, '--backup-dir=') ?? p.join(cacheFile.parent.path, 'backups'),
  );

  final beforeStat = await cacheFile.stat();
  final beforeMaps = await readLocalCacheSaver(cacheFile);
  final beforeInfo = await readLocalCacheSaverInfo(cacheFile);
  final backupFile = await backupFileToDirectory(cacheFile, backupDir);

  print('cache=${cacheFile.path}');
  print('backup=${backupFile.path}');
  print('beforeBytes=${beforeStat.size}');
  print('beforeMaps=${beforeMaps.maps.length}');
  print('beforeGeneratedAt=${beforeInfo.generatedAt?.toIso8601String()}');
  print(
    'beforeIncrementalAt=${beforeInfo.incrementalUpdatedAt?.toIso8601String()}',
  );

  final result = await updateLocalCacheSnapshot(
    outputFile: cacheFile,
    options: LocalCacheSnapshotOptions(
      pageSize: pageSize,
      maxPages: maxPages,
      delayBetweenRequests: Duration(milliseconds: delayMs < 0 ? 0 : delayMs),
    ),
    onProgress: (progress) {
      print(
        'progress pages=${progress.pagesFetched} maps=${progress.fetchedMaps} '
        'completed=${progress.completed} paused=${progress.paused}',
      );
    },
  );

  if (result.completed) {
    final timeFile = File(p.join(cacheFile.parent.path, 'LocalCache.time'));
    await timeFile.writeAsString(
      DateTime.now().toUtc().toIso8601String(),
      flush: true,
    );
  }

  final afterStat = await cacheFile.stat();
  final afterMaps = await readLocalCacheSaver(cacheFile);
  print('completed=${result.completed}');
  print('paused=${result.paused}');
  print('pages=${result.pagesFetched}');
  print('fetched=${result.fetchedMaps}');
  print('added=${result.addedMaps}');
  print('updated=${result.updatedMaps}');
  print('total=${result.totalMaps}');
  print('afterBytes=${afterStat.size}');
  print('afterMaps=${afterMaps.maps.length}');
  print('localCacheUpdate=passed');
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
  return _optionalIntOption(args, prefix) ?? fallback;
}

int? _optionalIntOption(List<String> args, String prefix) {
  final value = _option(args, prefix);
  return value == null ? null : int.tryParse(value);
}

const _usage = r'''
Usage:
  dart run tool\local_cache_update.dart --cache=PATH [options]

Options:
  --cache=PATH       Existing LocalCache.saver to update.
  --backup-dir=DIR   Backup directory. Defaults to sibling backups\.
  --page-size=N      BeatSaver page size, clamped to 1..100. Defaults to 100.
  --delay-ms=N       Delay between requests. Defaults to 750.
  --max-pages=N      Optional safety limit. Omit for full incremental update.
  --allow-network    Required. Confirms this run may contact BeatSaver and
                     update the selected LocalCache.saver.
  --help, -h         Show this help.

The tool always copies a timestamped backup before updating. It performs an
incremental /maps/latest update and does not apply deleted-map cleanup.
It refuses to run without --allow-network.
''';
