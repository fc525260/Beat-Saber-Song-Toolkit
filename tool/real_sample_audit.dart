import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final showMissing = args.contains('--missing');
  final showAnomalies = args.contains('--anomalies');
  final showPathCorrections = args.contains('--path-corrections');
  final missingLimit = _intOption(args, '--missing-limit=', fallback: 10);
  final pathCorrectionLimit =
      _intOption(args, '--path-correction-limit=', fallback: 5);
  final pathArg = args.where((arg) => !arg.startsWith('--')).firstOrNull;
  final sampleRoot = Directory(
    pathArg ?? p.join('test', 'Beat Saber  songs'),
  );
  if (!await sampleRoot.exists()) {
    stderr.writeln('Sample root not found: ${sampleRoot.path}');
    exitCode = 2;
    return;
  }

  final packDirs = await sampleRoot
      .list(followLinks: false)
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  packDirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final playlists = await sampleRoot
      .list(followLinks: false)
      .where((entity) =>
          entity is File && p.extension(entity.path).toLowerCase() == '.bplist')
      .cast<File>()
      .toList();
  playlists.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final playlistByPackTitle = <String, File>{};
  for (final playlist in playlists) {
    playlistByPackTitle[_packTitle(p.basenameWithoutExtension(playlist.path))] =
        playlist;
  }

  print('sampleRoot=${sampleRoot.path}');
  print('packDirs=${packDirs.length}');
  print('bplistFiles=${playlists.length}');

  var totalSongDirs = 0;
  var totalInfo = 0;
  var totalEgg = 0;
  var totalPlaylistEntries = 0;
  var totalInstalled = 0;
  var totalMissing = 0;
  var totalMissingEgg = 0;
  var totalDuplicateGroups = 0;
  var totalPathCorrections = 0;
  var totalPathCorrectionsWithInfo = 0;
  var totalPathCorrectionsWithoutInfo = 0;
  var totalPathCorrectionsWithoutId = 0;

  for (final packDir in packDirs) {
    final packName = p.basename(packDir.path);
    final installed = await scanInstalledLibrary(packDir);
    final infoCount = installed.where((entry) => entry.hasInfoDat).length;
    final noInfoCount = installed.length - infoCount;
    final eggCount = await _countFiles(packDir, '.egg');
    final duplicates = findInstalledDuplicateGroups(installed);
    final corrections = suggestInstalledPathCorrections(installed);
    final pathCorrectionsWithInfo = corrections.where((correction) {
      return correction.entry.hasInfoDat;
    }).length;
    final pathCorrectionsWithoutInfo =
        corrections.length - pathCorrectionsWithInfo;
    final pathCorrectionsWithoutId = corrections.where((correction) {
      return (correction.entry.mapId ?? '').trim().isEmpty;
    }).length;
    final playlistFile = playlistByPackTitle[_packTitle(packName)];
    final noInfoEntries =
        installed.where((entry) => !entry.hasInfoDat).toList(growable: false);

    totalSongDirs += installed.length;
    totalInfo += infoCount;
    totalEgg += eggCount;
    totalDuplicateGroups += duplicates.length;
    totalPathCorrections += corrections.length;
    totalPathCorrectionsWithInfo += pathCorrectionsWithInfo;
    totalPathCorrectionsWithoutInfo += pathCorrectionsWithoutInfo;
    totalPathCorrectionsWithoutId += pathCorrectionsWithoutId;

    var playlistEntries = 0;
    var keyEntries = 0;
    var hashEntries = 0;
    var installedMatches = 0;
    var missingMatches = 0;
    var missingEgg = 0;
    var localHashCount = 0;
    var localOnlyHashCount = 0;
    List<String> missingHashes = const [];
    if (playlistFile != null) {
      final playlist = await readBplist(playlistFile);
      final compared = await comparePlaylistWithInstalledLibrary(
        playlist: playlist,
        libraryDirectory: packDir,
      );
      playlistEntries = playlist.entries.length;
      keyEntries =
          playlist.entries.where((entry) => entry.key.isNotEmpty).length;
      hashEntries =
          playlist.entries.where((entry) => entry.hash.isNotEmpty).length;
      installedMatches = compared.where((entry) => entry.isInstalled).length;
      missingMatches = compared.where((entry) => !entry.isInstalled).length;
      missingEgg =
          compared.where((entry) => entry.isInstalled && !entry.hasEgg).length;
      missingHashes = compared
          .where((entry) => !entry.isInstalled && entry.hash.isNotEmpty)
          .map((entry) => entry.hash)
          .toList(growable: false);

      if (showMissing) {
        final localHashes = await _localHashes(installed);
        final playlistHashes = playlist.entries
            .map((entry) => entry.hash.trim().toLowerCase())
            .where((hash) => hash.isNotEmpty)
            .toSet();
        localHashCount = localHashes.length;
        localOnlyHashCount =
            localHashes.where((hash) => !playlistHashes.contains(hash)).length;
      }

      totalPlaylistEntries += playlistEntries;
      totalInstalled += installedMatches;
      totalMissing += missingMatches;
      totalMissingEgg += missingEgg;
    }

    print('');
    print('pack=$packName');
    print(
        '  songDirs=${installed.length} info=$infoCount noInfo=$noInfoCount egg=$eggCount');
    print(
        '  duplicates=${duplicates.length} pathCorrections=${corrections.length}');
    if (playlistFile == null) {
      print('  bplist=missing');
    } else {
      print('  bplist=${p.basename(playlistFile.path)}');
      print('  entries=$playlistEntries key=$keyEntries hash=$hashEntries');
      print(
          '  compareInstalled=$installedMatches compareMissing=$missingMatches missingEgg=$missingEgg');
      if (showMissing) {
        print('  localHashes=$localHashCount localOnly=$localOnlyHashCount');
        if (missingHashes.isNotEmpty) {
          final preview = missingHashes.take(missingLimit).join(', ');
          print('  missingHashes=${missingHashes.length}: $preview');
        }
      }
    }
    if (showAnomalies) {
      for (final entry in noInfoEntries) {
        final files = await _fileNames(entry.directory);
        print('  noInfo=${entry.directoryName} files=${files.join('; ')}');
      }
      for (final group in duplicates) {
        print(
          '  duplicate=${group.kind.name}:${group.value} count=${group.entries.length}',
        );
        for (final entry in group.entries) {
          final hash = await computeInstalledSongHash(entry.directory);
          print(
            '    dir=${entry.directoryName} hash=${hash ?? '-'} song=${entry.info?.songName ?? '-'}',
          );
        }
      }
    }
    if (showPathCorrections) {
      print(
        '  pathCorrectionBreakdown=withInfo:$pathCorrectionsWithInfo '
        'noInfo:$pathCorrectionsWithoutInfo '
        'noId:$pathCorrectionsWithoutId',
      );
      for (final correction in corrections.take(pathCorrectionLimit)) {
        final entry = correction.entry;
        final id =
            entry.mapId?.trim().isNotEmpty == true ? entry.mapId!.trim() : '-';
        final song = entry.info?.songName ?? entry.title ?? '-';
        print(
          '  pathCorrection=${entry.directoryName} -> '
          '${correction.expectedDirectoryName} '
          'info=${entry.hasInfoDat} id=$id song=$song',
        );
      }
    }
  }

  print('');
  print('totals');
  print('  songDirs=$totalSongDirs info=$totalInfo egg=$totalEgg');
  print(
      '  bplistEntries=$totalPlaylistEntries installed=$totalInstalled missing=$totalMissing missingEgg=$totalMissingEgg');
  print('  duplicateGroups=$totalDuplicateGroups');
  if (showPathCorrections) {
    print(
      '  pathCorrections=$totalPathCorrections '
      'withInfo=$totalPathCorrectionsWithInfo '
      'noInfo=$totalPathCorrectionsWithoutInfo '
      'noId=$totalPathCorrectionsWithoutId',
    );
  }
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

Future<Set<String>> _localHashes(Iterable<InstalledSongEntry> installed) async {
  final hashes = <String>{};
  for (final entry in installed) {
    if (!entry.hasInfoDat) {
      continue;
    }
    final hash = await computeInstalledSongHash(entry.directory);
    if (hash != null && hash.isNotEmpty) {
      hashes.add(hash);
    }
  }
  return hashes;
}

String _packTitle(String name) {
  return name.replaceFirst(RegExp(r'\s+更新至\[[^\]]+\].*$'), '').trim();
}

Future<int> _countFiles(Directory root, String extension) async {
  var count = 0;
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && p.extension(entity.path).toLowerCase() == extension) {
      count += 1;
    }
  }
  return count;
}

Future<List<String>> _fileNames(Directory directory) async {
  final files = await directory
      .list(followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .map((file) => p.basename(file.path))
      .toList();
  files.sort();
  return files;
}

void _printUsage() {
  print('''
Usage:
  dart run tool\\real_sample_audit.dart [sample-root] [options]

Options:
  --missing                  Print missing hash previews and local-only counts.
  --missing-limit=N          Number of missing hashes to preview. Defaults to 10.
  --anomalies                Print missing-info directories and duplicate groups.
  --path-corrections         Print path correction breakdown and previews.
  --path-correction-limit=N  Number of path corrections to preview. Defaults to 5.
  --help, -h                 Show this help.

This script is read-only for the sample root. It does not delete, rename,
download, install, or modify playlists.
''');
}
