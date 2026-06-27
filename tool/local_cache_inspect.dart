import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  for (final path in args) {
    final file = File(path);
    if (!await file.exists()) {
      stderr.writeln('missing=$path');
      exitCode = 66;
      continue;
    }
    final stat = await file.stat();
    final maps = await readLocalCacheSaver(file);
    final info = await readLocalCacheSaverInfo(file);
    final time = await readLocalCacheTime(
      File('${file.parent.path}${Platform.pathSeparator}LocalCache.time'),
    );
    print('cache=${file.path}');
    print('bytes=${stat.size}');
    print('modified=${stat.modified.toIso8601String()}');
    print('maps=${maps.maps.length}');
    print('generatedAt=${info.generatedAt?.toIso8601String()}');
    print('incrementalAt=${info.incrementalUpdatedAt?.toIso8601String()}');
    print('incrementalAdded=${info.incrementalAdded}');
    print('incrementalUpdated=${info.incrementalUpdated}');
    print('localCacheTime=${time?.toIso8601String()}');
  }
}

const _usage = r'''
Usage:
  dart run tool\local_cache_inspect.dart PATH [PATH...]

Prints LocalCache.saver size, map count, info metadata, and sibling
LocalCache.time if present.
''';
