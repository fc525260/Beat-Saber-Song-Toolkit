import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final keepTemp = args.contains('--keep-temp');
  final sampleRoot = Directory(
    _option(args, '--sample-root=') ?? p.join('test', 'Beat Saber  songs'),
  );
  final packKeyword = _option(args, '--pack=') ?? '中文';
  if (!await sampleRoot.exists()) {
    stderr.writeln('Sample root not found: ${sampleRoot.path}');
    exitCode = 2;
    return;
  }

  final packDir = await _findPackDirectory(sampleRoot, packKeyword);
  if (packDir == null) {
    stderr.writeln(
      'Pack directory not found under ${sampleRoot.path}: $packKeyword',
    );
    exitCode = 2;
    return;
  }

  final tempRoot = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_real_sample_library_export_',
  );
  try {
    final entries = await scanInstalledLibrary(packDir);
    final exportable = entries
        .where((entry) => entry.mapId != null && entry.hasInfoDat)
        .toList(growable: false);
    if (exportable.isEmpty) {
      throw StateError('Expected exportable songs in ${packDir.path}.');
    }

    final outputFile = File(p.join(tempRoot.path, 'real_sample_export.bplist'));
    await exportBplistFromInstalledEntries(
      entries: entries,
      outputFile: outputFile,
      playlistTitle: '真实样本导出检查',
      playlistAuthor: 'Beat Saber Song Toolkit Smoke',
      playlistDescription: 'Read-only real sample export smoke.',
    );

    final decoded = await _readJsonObject(outputFile);
    final songs = _songs(decoded);
    final keys = songs
        .map((song) => song['key']?.toString().trim() ?? '')
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
    final uniqueKeys = keys.toSet();
    final duplicateKeyCount = keys.length - uniqueKeys.length;
    if (decoded['playlistTitle'] != '真实样本导出检查' ||
        decoded['playlistAuthor'] != 'Beat Saber Song Toolkit Smoke' ||
        songs.length != exportable.length ||
        keys.length != songs.length) {
      throw StateError(
        'Real sample export mismatch: songs=${songs.length}, '
        'exportable=${exportable.length}, keys=${keys.length}, '
        'uniqueKeys=${uniqueKeys.length}, duplicateKeys=$duplicateKeyCount.',
      );
    }

    final missingSongNames = songs
        .where((song) => (song['songName']?.toString().trim() ?? '').isEmpty)
        .length;
    if (missingSongNames != 0) {
      throw StateError('Exported songs should all include songName.');
    }
    final image = decoded['image']?.toString() ?? '';
    if (!image.startsWith('data:image/')) {
      throw StateError(
          'Expected exported bplist to include an image data URL.');
    }
    final imageType = image.split(';').first;

    print('sampleRoot=${sampleRoot.path}');
    print('pack=${p.basename(packDir.path)}');
    print('tempRoot=${tempRoot.path}');
    print('outputFile=${outputFile.path}');
    print('scannedEntries=${entries.length}');
    print('exportableEntries=${exportable.length}');
    print('exportedSongs=${songs.length}');
    print('uniqueKeys=${uniqueKeys.length}');
    print('duplicateKeys=$duplicateKeyCount');
    print('image=$imageType');
  } finally {
    if (keepTemp) {
      print('keptTemp=${tempRoot.path}');
    } else if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  }
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

Future<Directory?> _findPackDirectory(
  Directory sampleRoot,
  String keyword,
) async {
  final normalizedKeyword = keyword.toLowerCase();
  final directories = await sampleRoot
      .list(followLinks: false)
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  directories.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  for (final directory in directories) {
    if (p.basename(directory.path).toLowerCase().contains(normalizedKeyword)) {
      return directory;
    }
  }
  return directories.isEmpty ? null : directories.first;
}

Future<Map<String, dynamic>> _readJsonObject(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Expected JSON object in ${file.path}.');
  }
  return decoded;
}

List<Map<String, dynamic>> _songs(Map<String, dynamic> json) {
  final songs = json['songs'];
  if (songs is! List) {
    throw StateError('Expected songs array.');
  }
  return songs.whereType<Map<String, dynamic>>().toList(growable: false);
}

const _usage = r'''
Usage:
  dart run tool\real_sample_library_export_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --pack=KEYWORD     Pick a pack directory by name keyword. Defaults to 中文.
  --keep-temp        Keep the temporary exported bplist.
  --help, -h         Show this help.

The script scans one real sample pack read-only, exports exportable installed
songs to a bplist in a system temp directory, and verifies the exported JSON,
including the automatic cover image data URL. It never writes into the real
sample directory.
''';
