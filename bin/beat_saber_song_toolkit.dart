import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage(stdout);
    return;
  }

  final installDirectory = _readOption(args, '--install-out') ?? 'installed';
  final importBplistPath = _readOption(args, '--import-bplist');
  if (importBplistPath != null && importBplistPath.trim().isNotEmpty) {
    if (!_requireAllowNetwork(args, '--import-bplist')) {
      return;
    }
    await _importBplist(
      File(importBplistPath.trim()),
      Directory(installDirectory),
    );
    return;
  }

  final exportBplistPath = _readOption(args, '--export-bplist');
  if (exportBplistPath != null && exportBplistPath.trim().isNotEmpty) {
    await _exportBplist(
      Directory(installDirectory),
      File(exportBplistPath.trim()),
      _readOption(args, '--playlist-title') ?? 'Beat Saber Song Toolkit',
      _readOption(args, '--playlist-author') ?? 'Beat Saber Song Toolkit',
    );
    return;
  }

  final deleteId = _readOption(args, '--delete-id');
  if (deleteId != null && deleteId.trim().isNotEmpty) {
    if (!_requireDeleteConfirmation(args, '--delete-id')) {
      return;
    }
    await _deleteInstalledMap(Directory(installDirectory), deleteId.trim());
    return;
  }

  if (args.contains('--list-installed')) {
    await _listInstalledMaps(Directory(installDirectory));
    return;
  }

  final batchInstallQuery = _readOption(args, '--batch-install');
  if (batchInstallQuery != null && batchInstallQuery.trim().isNotEmpty) {
    if (!_requireAllowNetwork(args, '--batch-install')) {
      return;
    }
    await _batchInstallMaps(
      args,
      batchInstallQuery.trim(),
      Directory(installDirectory),
    );
    return;
  }

  final installId = _readOption(args, '--install-id');
  if (installId != null && installId.trim().isNotEmpty) {
    if (!_requireAllowNetwork(args, '--install-id')) {
      return;
    }
    await _installMap(installId.trim(), Directory(installDirectory));
    return;
  }

  final downloadId = _readOption(args, '--download-id');
  final outputDirectory = _readOption(args, '--out') ?? 'downloads';
  if (downloadId != null && downloadId.trim().isNotEmpty) {
    if (!_requireAllowNetwork(args, '--download-id')) {
      return;
    }
    await _downloadMap(downloadId.trim(), Directory(outputDirectory));
    return;
  }

  final query = _readOption(args, '--query') ?? _readOption(args, '-q');
  if (query == null || query.trim().isEmpty) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  if (!_requireAllowNetwork(args, '--query')) {
    return;
  }

  final client = BeatSaverClient();
  final response = await client.searchText(_searchOptions(args, query.trim()));

  for (final map in response.maps) {
    final metadata = map.metadata;
    final uploader = map.uploaderName ?? 'unknown uploader';
    stdout.writeln(
      '${map.id} | ${metadata.songName} | ${metadata.songAuthorName} | '
      '${metadata.levelAuthorName} | $uploader | '
      'score=${map.stats.score.toStringAsFixed(3)}',
    );
  }
}

void _printUsage(IOSink sink) {
  sink.writeln('Usage:');
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --query "song name" --allow-network',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --download-id 1520 --out downloads --allow-network',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --install-id 1520 --install-out songs --allow-network',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --batch-install camellia --limit 3 --install-out songs --allow-network',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --list-installed --install-out songs',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --delete-id 1520 --install-out songs --yes-delete',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --export-bplist playlists\\songs.bplist --install-out songs',
  );
  sink.writeln(
    '  dart run bin/beat_saber_song_toolkit.dart --import-bplist playlists\\songs.bplist --install-out songs --allow-network',
  );
  sink.writeln('');
  sink.writeln('Safety: network operations require --allow-network.');
  sink.writeln('Safety: deleting installed songs requires --yes-delete.');
}

Future<void> _downloadMap(String id, Directory outputDirectory) async {
  final client = BeatSaverClient();
  final map = await client.getMapById(id);
  final file = await client.downloadLatestVersion(map, outputDirectory);
  stdout.writeln('Downloaded ${map.id} ${map.metadata.songName}');
  stdout.writeln(file.path);
}

Future<void> _installMap(String id, Directory outputDirectory) async {
  final client = BeatSaverClient();
  final map = await client.getMapById(id);
  final installed = await findInstalledMapDirectory(map, outputDirectory);
  if (installed != null) {
    stdout.writeln('Skipped ${map.id} ${map.metadata.songName}');
    stdout.writeln(installed.path);
    return;
  }

  final songDirectory = await client.installLatestVersion(map, outputDirectory);
  stdout.writeln('Installed ${map.id} ${map.metadata.songName}');
  stdout.writeln(songDirectory.path);
}

Future<void> _batchInstallMaps(
  List<String> args,
  String query,
  Directory outputDirectory,
) async {
  final client = BeatSaverClient();
  final options = _searchOptions(args, query);
  final response = await client.searchText(options);
  final maps = response.maps.take(options.pageSize).toList(growable: false);

  var installed = 0;
  var skipped = 0;
  var failed = 0;
  for (final map in maps) {
    try {
      final existingDirectory = await findInstalledMapDirectory(
        map,
        outputDirectory,
      );
      if (existingDirectory != null) {
        skipped += 1;
        stdout.writeln('Skipped ${map.id} ${map.metadata.songName}');
        stdout.writeln(existingDirectory.path);
        continue;
      }

      final directory = await client.installLatestVersion(map, outputDirectory);
      installed += 1;
      stdout.writeln('Installed ${map.id} ${map.metadata.songName}');
      stdout.writeln(directory.path);
    } catch (error) {
      failed += 1;
      stderr.writeln('Failed ${map.id} ${map.metadata.songName}: $error');
    }
  }

  stdout.writeln(
    'Batch complete: installed=$installed skipped=$skipped failed=$failed',
  );
}

Future<void> _listInstalledMaps(Directory libraryDirectory) async {
  final entries = await scanInstalledLibrary(libraryDirectory);
  for (final entry in entries) {
    final id = entry.mapId ?? '-';
    final title = entry.title ?? entry.directoryName;
    final artist = entry.info?.songAuthorName ?? '-';
    final mapper = entry.info?.levelAuthorName ?? '-';
    final bpm = entry.info == null
        ? '-'
        : entry.info!.beatsPerMinute.toStringAsFixed(0);
    final status = entry.hasInfoDat ? 'ok' : 'missing-info';
    stdout.writeln(
      '$id | $title | $artist | $mapper | bpm=$bpm | $status | '
      '${entry.directory.path}',
    );
  }
  stdout.writeln('Installed library entries: ${entries.length}');
}

Future<void> _deleteInstalledMap(Directory libraryDirectory, String id) async {
  final deleted = await deleteInstalledMapById(libraryDirectory, id);
  if (deleted == null) {
    stderr.writeln('No installed map found for id $id');
    exitCode = 1;
    return;
  }

  stdout.writeln(
      'Deleted ${deleted.mapId} ${deleted.title ?? deleted.directoryName}');
  stdout.writeln(deleted.directory.path);
}

Future<void> _exportBplist(
  Directory libraryDirectory,
  File outputFile,
  String playlistTitle,
  String playlistAuthor,
) async {
  final file = await exportBplist(
    libraryDirectory: libraryDirectory,
    outputFile: outputFile,
    playlistTitle: playlistTitle,
    playlistAuthor: playlistAuthor,
  );
  stdout.writeln('Exported bplist');
  stdout.writeln(file.path);
}

Future<void> _importBplist(
  File inputFile,
  Directory outputDirectory,
) async {
  final playlist = await readBplist(inputFile);
  final client = BeatSaverClient();

  var installed = 0;
  var skipped = 0;
  var failed = 0;
  for (final id in playlist.mapIds) {
    try {
      final map = await client.getMapById(id);
      final existingDirectory = await findInstalledMapDirectory(
        map,
        outputDirectory,
      );
      if (existingDirectory != null) {
        skipped += 1;
        stdout.writeln('Skipped ${map.id} ${map.metadata.songName}');
        stdout.writeln(existingDirectory.path);
        continue;
      }

      final directory = await client.installLatestVersion(map, outputDirectory);
      installed += 1;
      stdout.writeln('Installed ${map.id} ${map.metadata.songName}');
      stdout.writeln(directory.path);
    } catch (error) {
      failed += 1;
      stderr.writeln('Failed $id: $error');
    }
  }

  stdout.writeln(
    'Import complete: title="${playlist.title}" '
    'installed=$installed skipped=$skipped failed=$failed',
  );
}

BeatSaverSearchOptions _searchOptions(List<String> args, String query) {
  final limit = _readIntOption(args, '--limit') ?? 20;
  return BeatSaverSearchOptions(
    query: query,
    pageSize: limit.clamp(1, 100),
    order:
        parseBeatSaverSearchOrder(_readOption(args, '--order') ?? 'relevance'),
    minRating: _readDoubleOption(args, '--min-rating'),
    maxDurationSeconds: _readIntOption(args, '--max-duration'),
    noodle: _readBoolOption(args, '--noodle'),
    chroma: _readBoolOption(args, '--chroma'),
    cinema: _readBoolOption(args, '--cinema'),
    curated: _readBoolOption(args, '--curated'),
  );
}

String? _readOption(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

int? _readIntOption(List<String> args, String name) {
  final value = _readOption(args, name);
  if (value == null) {
    return null;
  }
  return int.tryParse(value);
}

double? _readDoubleOption(List<String> args, String name) {
  final value = _readOption(args, name);
  if (value == null) {
    return null;
  }
  return double.tryParse(value);
}

bool? _readBoolOption(List<String> args, String name) {
  final value = _readOption(args, name);
  if (value == null) {
    return null;
  }
  return switch (value.trim().toLowerCase()) {
    'true' || 'yes' || '1' => true,
    'false' || 'no' || '0' => false,
    _ => null,
  };
}

bool _requireAllowNetwork(List<String> args, String operation) {
  if (args.contains('--allow-network')) {
    return true;
  }

  stderr.writeln(
    '$operation contacts BeatSaver. Re-run with --allow-network only when '
    'a live query, download, or install is intended.',
  );
  exitCode = 64;
  return false;
}

bool _requireDeleteConfirmation(List<String> args, String operation) {
  if (args.contains('--yes-delete')) {
    return true;
  }

  stderr.writeln(
    '$operation deletes an installed song directory. Re-run with --yes-delete '
    'only after confirming the target --install-out path is disposable.',
  );
  exitCode = 64;
  return false;
}
