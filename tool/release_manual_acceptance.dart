import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final mode = _option(args, '--mode') ?? 'library';
  if (!{'search', 'library', 'playlistSync', 'fastlog'}.contains(mode)) {
    stderr.writeln('Unsupported --mode=$mode');
    _printUsage();
    exitCode = 64;
    return;
  }

  final releaseDir = Directory(
    _option(args, '--release-dir') ??
        p.join(
          'apps',
          'beat_saber_song_toolkit_app',
          'build',
          'windows',
          'x64',
          'runner',
          'Release',
        ),
  );
  final exe = File(p.join(releaseDir.path, 'Beat Saber Song Toolkit.exe'));
  if (!exe.existsSync()) {
    stderr.writeln('Release exe not found: ${exe.path}');
    stderr.writeln('Build it first with:');
    stderr.writeln(
      r'  cd apps\beat_saber_song_toolkit_app && D:\Software\flutter\bin\flutter.bat build windows --release',
    );
    exitCode = 66;
    return;
  }

  final sampleRoot = Directory(
    _option(args, '--sample-root') ?? p.join('test', 'Beat Saber  songs'),
  );
  final techInstallDir = Directory(
    _option(args, '--library-dir') ??
        p.join(
          sampleRoot.path,
          '【Tech新手包】最新100首技巧类型的5方块每秒以下高评分歌曲 更新至[2023-07-01]@WGzeyu',
        ),
  );
  final techPlaylistFile = File(
    _option(args, '--playlist') ??
        p.join(
          sampleRoot.path,
          '【Tech新手包】最新100首技巧类型的5方块每秒以下高评分歌曲 更新至[2023-07-19]@WGzeyu.bplist',
        ),
  );
  final localCache = File(_option(args, '--local-cache') ?? 'LocalCache.saver');

  final tempRoot = await Directory.systemTemp.createTemp(
    'beat_saber_song_toolkit_release_manual_',
  );
  final appData = Directory(p.join(tempRoot.path, 'APPDATA'));
  final configDir = Directory(p.join(appData.path, 'BeatSaberSongToolkit'));
  await configDir.create(recursive: true);
  final tempZipDir = Directory(p.join(tempRoot.path, 'ZipDownloads'));
  await tempZipDir.create(recursive: true);
  final tempLibrary = await _createTempLibrary(tempRoot);

  final workspace = mode == 'fastlog' ? 'search' : mode;
  final settings = <String, Object?>{
    'workspace': workspace,
    'readLocalDataOnStartup': mode == 'library' || mode == 'playlistSync',
    'libraryDirectory': mode == 'library'
        ? tempLibrary.path
        : techInstallDir.path,
    'downloadDirectory': tempZipDir.path,
    'playlistPath': techPlaylistFile.path,
    'localCacheSaverPath': localCache.path,
  };
  await File(
    p.join(configDir.path, 'settings.json'),
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(settings));

  final arguments = <String>[
    if (mode == 'fastlog') '-fastlog',
    if (mode == 'library' || mode == 'playlistSync') '-local',
  ];
  final environment = Map<String, String>.of(Platform.environment)
    ..['APPDATA'] = appData.path;

  final process = await Process.start(
    exe.path,
    arguments,
    workingDirectory: releaseDir.path,
    environment: environment,
    mode: ProcessStartMode.detached,
  );

  stdout.writeln('releaseManualAcceptance=started');
  stdout.writeln('pid=${process.pid}');
  stdout.writeln('mode=$mode');
  stdout.writeln('tempRoot=${tempRoot.path}');
  stdout.writeln('tempAppData=${appData.path}');
  stdout.writeln('tempLibrary=${tempLibrary.path}');
  stdout.writeln('releaseExe=${exe.path}');
  stdout.writeln('');
  stdout.writeln('Manual checks:');
  stdout.writeln('- Use only this temp library for destructive dialog checks.');
  stdout.writeln('- Open destructive dialogs and cancel them; do not confirm unless you intend to delete temp files.');
  stdout.writeln('- File picker checks may be opened/cancelled from the visible release window.');
  stdout.writeln('- Close the release window when finished. The temp directory is left for inspection.');
  stdout.writeln('');
  stdout.writeln('No BeatSaver network access is requested by this launcher.');
}

String? _option(List<String> args, String name) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == name && index + 1 < args.length) {
      return args[index + 1];
    }
    if (arg.startsWith('$name=')) {
      return arg.substring(name.length + 1);
    }
  }
  return null;
}

Future<Directory> _createTempLibrary(Directory tempRoot) async {
  final library = Directory(p.join(tempRoot.path, 'CustomLevels'));
  final song = Directory(p.join(library.path, 'abc123 - Delete Confirm Smoke'));
  await song.create(recursive: true);
  await File(p.join(song.path, 'Info.dat')).writeAsString('''
{
  "_songName": "Delete Confirm Smoke",
  "_songSubName": "",
  "_songAuthorName": "Tester",
  "_levelAuthorName": "Codex",
  "_beatsPerMinute": 120,
  "_difficultyBeatmapSets": []
}
''');
  await File(p.join(song.path, 'song.egg')).writeAsString('placeholder');
  return library;
}

void _printUsage() {
  stdout.writeln('''
Usage: dart run tool\\release_manual_acceptance.dart [options]

Starts the Windows release with temporary APPDATA for manual GUI acceptance.
It does not contact BeatSaver and does not write user settings.

Options:
  --mode=library|playlistSync|fastlog|search
      library starts on a temp CustomLevels folder for destructive-dialog checks.
      playlistSync starts with the real Tech sample paths.
      fastlog starts with the project LocalCache.saver.
      search opens the default workspace with temporary settings.
  --release-dir=PATH
      Override the release directory containing Beat Saber Song Toolkit.exe.
  --sample-root=PATH
      Override the real sample root used by playlistSync mode.
  --library-dir=PATH
      Override the library directory used by playlistSync/search settings.
  --playlist=PATH
      Override the .bplist path used by playlistSync mode.
  --local-cache=PATH
      Override LocalCache.saver path used by fastlog mode.
  --help
      Print this help and exit without launching the release.
''');
}
