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
  final packKeyword = _option(args, '--pack=') ?? 'Tech';
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

  final installed = await scanInstalledLibrary(packDir);
  final corrections = suggestInstalledPathCorrections(installed);
  if (corrections.isEmpty) {
    throw StateError('Expected path corrections in ${packDir.path}.');
  }

  final correction = corrections.firstWhere(
    (correction) => correction.entry.hasInfoDat,
    orElse: () => corrections.first,
  );
  final sourceDir = correction.entry.directory;
  final sourceExpectedDir = Directory(
    p.join(sourceDir.parent.path, correction.expectedDirectoryName),
  );
  final tempRoot = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_real_sample_path_correction_',
  );
  try {
    final tempLibrary = await Directory(
      p.join(tempRoot.path, 'CustomLevels'),
    ).create(recursive: true);
    final tempSource = Directory(
      p.join(tempLibrary.path, p.basename(sourceDir.path)),
    );
    await copyDirectoryRecursive(sourceDir, tempSource);
    final tempEntries = await scanInstalledLibrary(tempLibrary);
    final tempCorrections = suggestInstalledPathCorrections(tempEntries);
    if (tempCorrections.isEmpty) {
      throw StateError('Expected temp path corrections.');
    }

    final tempCorrection = tempCorrections.first;
    final renamedDir = await applyInstalledPathCorrection(tempCorrection);
    if (!await renamedDir.exists() ||
        await tempSource.exists() ||
        p.basename(renamedDir.path) != tempCorrection.expectedDirectoryName) {
      throw StateError('Temp path correction did not rename as expected.');
    }

    final rescanned = await scanInstalledLibrary(tempLibrary);
    final remainingCorrections = suggestInstalledPathCorrections(rescanned);
    final sourceStillExists = await sourceDir.exists();
    final sourceExpectedExists = await sourceExpectedDir.exists();
    if (remainingCorrections.isNotEmpty ||
        !sourceStillExists ||
        sourceExpectedExists) {
      throw StateError('Real sample path correction smoke failed.');
    }

    print('sampleRoot=${sampleRoot.path}');
    print('pack=${p.basename(packDir.path)}');
    print('tempRoot=${tempRoot.path}');
    print('sourceDirectory=${sourceDir.path}');
    print('sourceExpected=${correction.expectedDirectoryName}');
    print('sourceStillExists=$sourceStillExists');
    print('sourceExpectedExists=$sourceExpectedExists');
    print('tempSource=${tempSource.path}');
    print('tempExpected=${tempCorrection.expectedDirectoryName}');
    print('renamedDirectory=${renamedDir.path}');
    print('tempCorrections=${tempCorrections.length}');
    print('remainingCorrections=${remainingCorrections.length}');
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

const _usage = r'''
Usage:
  dart run tool\real_sample_path_correction_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --pack=KEYWORD     Pick a pack directory by name keyword. Defaults to Tech.
  --keep-temp        Keep the temporary path-correction test directory.
  --help, -h         Show this help.

The script scans one real sample pack read-only, copies one song
directory into a system temp library, applies the suggested rename there, and
verifies the real sample source stays unchanged.
''';
