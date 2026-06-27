import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final sampleRoot = Directory(
    _option(args, '--sample-root=') ?? p.join('test', 'Beat Saber  songs'),
  );
  final allowNetwork = args.contains('--allow-network');
  final packName = _option(args, '--pack=') ?? 'Fitness';
  final limit = _intOption(args, '--limit=', fallback: 3);
  if (!allowNetwork) {
    stderr.writeln(
      'This smoke contacts BeatSaver. Re-run with --allow-network only when '
      'a live API check was explicitly requested.',
    );
    exitCode = 2;
    return;
  }
  if (limit <= 0) {
    stderr.writeln('--limit must be greater than 0.');
    exitCode = 2;
    return;
  }
  if (!await sampleRoot.exists()) {
    stderr.writeln('Sample root not found: ${sampleRoot.path}');
    exitCode = 2;
    return;
  }

  final packDir = await _packDirectory(sampleRoot, packName);
  if (packDir == null) {
    stderr.writeln('Pack directory not found: $packName');
    exitCode = 2;
    return;
  }

  final playlistFile = await _playlistForPack(sampleRoot, packName);
  if (playlistFile == null) {
    stderr.writeln('Playlist for pack not found: $packName');
    exitCode = 2;
    return;
  }

  final tempDir = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_missing_resolve_',
  );
  final cacheFile = File(p.join(tempDir.path, 'beatsaver_hash_cache.json'));
  final client = BeatSaverClient();
  try {
    final playlist = await readBplist(playlistFile);
    var hashCache = await readBeatSaverHashCache(cacheFile);
    final compared = await comparePlaylistWithInstalledLibrary(
      playlist: playlist,
      libraryDirectory: packDir,
      hashDetails: hashCache.data,
    );
    final missing = compared
        .where((entry) => !entry.isInstalled)
        .take(limit)
        .toList(growable: false);

    print('sampleRoot=${sampleRoot.path}');
    print('pack=$packName');
    print('playlist=${playlistFile.path}');
    print(
        'missingTotal=${compared.where((entry) => !entry.isInstalled).length}');
    print('resolveLimit=$limit');
    print('resolveCandidates=${missing.length}');

    var resolved = 0;
    var failed = 0;
    for (final entry in missing) {
      try {
        final map = await _resolveMissingEntry(
          client: client,
          entry: entry,
          hashCache: hashCache,
        );
        resolved += 1;
        if (entry.hash.isNotEmpty) {
          hashCache =
              hashCache.put(entry.hash, BeatSaverHashDetail.fromMap(map));
        }
        print(
          'resolved id=${map.id} hash=${entry.hash.isEmpty ? '-' : entry.hash} name=${map.name}',
        );
      } catch (error) {
        failed += 1;
        print(
          'failed id=${entry.mapId.isEmpty ? '-' : entry.mapId} hash=${entry.hash.isEmpty ? '-' : entry.hash} error=$error',
        );
      }
    }

    await writeBeatSaverHashCache(cacheFile, hashCache);
    final writtenCache = await readBeatSaverHashCache(cacheFile);
    print('cacheFile=${cacheFile.path}');
    print('cacheEntries=${writtenCache.data.length}');
    print('resolved=$resolved failed=$failed');
    if (missing.isEmpty) {
      stderr.writeln('No missing playlist entries found for pack: $packName');
      exitCode = 1;
      return;
    }
    if (resolved == 0) {
      stderr.writeln('No missing playlist entries resolved.');
      exitCode = 1;
      return;
    }
    print('playlistSyncMissingResolveSmoke=passed');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<BeatSaverMap> _resolveMissingEntry({
  required BeatSaverClient client,
  required PlaylistSyncEntry entry,
  required BeatSaverHashCache hashCache,
}) async {
  if (entry.mapId.isNotEmpty) {
    return client.getMapById(entry.mapId);
  }
  if (entry.hash.isEmpty) {
    throw const FormatException('Missing entry has no key or hash.');
  }
  final cached = hashCache.get(entry.hash);
  if (cached != null && cached.id.isNotEmpty) {
    return client.getMapById(cached.id);
  }
  return client.getMapByHash(entry.hash);
}

Future<File?> _playlistForPack(Directory sampleRoot, String packName) async {
  final expectedTitle = _packTitle(packName);
  final expectedContains = packName.trim().toLowerCase();
  await for (final entity in sampleRoot.list(followLinks: false)) {
    if (entity is! File ||
        p.extension(entity.path).toLowerCase() != '.bplist') {
      continue;
    }
    final name = p.basenameWithoutExtension(entity.path);
    if (_packTitle(name) == expectedTitle ||
        name.toLowerCase().contains(expectedContains)) {
      return entity;
    }
  }
  return null;
}

Future<Directory?> _packDirectory(Directory sampleRoot, String packName) async {
  final exact = Directory(p.join(sampleRoot.path, packName));
  if (await exact.exists()) {
    return exact;
  }
  final expectedTitle = _packTitle(packName);
  final expectedContains = packName.trim().toLowerCase();
  await for (final entity in sampleRoot.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final name = p.basename(entity.path);
    if (_packTitle(name) == expectedTitle ||
        name.toLowerCase().contains(expectedContains)) {
      return entity;
    }
  }
  return null;
}

String _packTitle(String value) {
  return value
      .replaceAll(RegExp(r'^\d+\s*'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();
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

int _intOption(
  List<String> args,
  String prefix, {
  required int fallback,
}) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return int.tryParse(arg.substring(prefix.length)) ?? fallback;
    }
  }
  return fallback;
}

const _usage = r'''
Usage:
  dart run tool\playlist_sync_missing_resolve_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --pack=NAME         Pack directory/title to audit. Defaults to Fitness.
  --limit=N           Number of missing entries to resolve. Defaults to 3.
  --allow-network     Required. Confirms this run may contact BeatSaver.
  --help, -h          Show this help.

Reads a real sample pack, finds playlist entries missing from the local folder,
and resolves a small number through BeatSaver ID/hash lookups. The real sample
is read-only; the temporary hash cache is written under the system temp folder.
This is a live BeatSaver smoke and refuses to run without --allow-network.
''';
