import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final sampleRoot =
      _option(args, '--sample-root=') ?? p.join('test', 'Beat Saber  songs');
  final withMissingDownload = args.contains('--with-missing-download');
  final withMissingInstall = args.contains('--with-missing-install');
  final allowNetwork = args.contains('--allow-network');
  if ((withMissingDownload || withMissingInstall) && !allowNetwork) {
    stderr.writeln(
      '--with-missing-download and --with-missing-install contact BeatSaver. '
      'Re-run with --allow-network only when a live API/download check was '
      'explicitly requested.',
    );
    exitCode = 2;
    return;
  }
  final dartExecutable = Platform.resolvedExecutable;
  final root = Directory.current.path;
  final steps = [
    _SmokeStep(
      name: '真实样本只读审计',
      script: 'real_sample_audit.dart',
      args: [sampleRoot],
    ),
    _SmokeStep(
      name: 'Fitness 临时副本歌单同步操作',
      script: 'playlist_sync_operation_smoke.dart',
      args: [sampleRoot],
    ),
    _SmokeStep(
      name: 'Tech 临时副本歌单同步操作',
      script: 'playlist_sync_operation_smoke.dart',
      args: [
        sampleRoot,
        '--pack=Tech',
        '--copy-count=3',
        '--delete-count=2',
      ],
    ),
    if (withMissingDownload)
      _SmokeStep(
        name: 'Fitness 缺失下载 ZIP',
        script: 'playlist_sync_missing_download_smoke.dart',
        args: [
          '--sample-root=$sampleRoot',
          '--pack=Fitness',
          '--limit=1',
          '--allow-network',
        ],
      ),
    if (withMissingDownload)
      _SmokeStep(
        name: 'Tech 缺失下载 ZIP',
        script: 'playlist_sync_missing_download_smoke.dart',
        args: [
          '--sample-root=$sampleRoot',
          '--pack=Tech',
          '--limit=1',
          '--allow-network',
        ],
      ),
    if (withMissingInstall)
      _SmokeStep(
        name: 'Fitness 缺失安装',
        script: 'playlist_sync_missing_install_smoke.dart',
        args: [
          '--sample-root=$sampleRoot',
          '--pack=Fitness',
          '--limit=1',
          '--allow-network',
        ],
      ),
    if (withMissingInstall)
      _SmokeStep(
        name: 'Tech 缺失安装',
        script: 'playlist_sync_missing_install_smoke.dart',
        args: [
          '--sample-root=$sampleRoot',
          '--pack=Tech',
          '--limit=1',
          '--allow-network',
        ],
      ),
  ];

  print('sampleRoot=$sampleRoot');
  print('withMissingDownload=$withMissingDownload');
  print('withMissingInstall=$withMissingInstall');
  print('allowNetwork=$allowNetwork');
  print('dart=$dartExecutable');
  print('steps=${steps.length}');

  for (final step in steps) {
    final scriptPath = p.join('tool', step.script);
    print('');
    print('step=${step.name}');
    final result = await Process.run(
      dartExecutable,
      ['run', scriptPath, ...step.args],
      workingDirectory: root,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      stderr.writeln(
        'Step failed: ${step.name}, exitCode=${result.exitCode}.',
      );
      exitCode = result.exitCode;
      return;
    }
  }

  print('');
  print('playlistSyncSmoke=passed');
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

class _SmokeStep {
  const _SmokeStep({
    required this.name,
    required this.script,
    required this.args,
  });

  final String name;
  final String script;
  final List<String> args;
}

const _usage = r'''
Usage:
  dart run tool\playlist_sync_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --with-missing-download
                      Also resolve and download one missing ZIP from Fitness
                      and Tech into system temp. This requires network.
  --with-missing-install
                      Also resolve and install one missing song from Fitness
                      and Tech into a temp CustomLevels folder. This requires
                      network and writes only to system temp.
  --allow-network     Required when enabling missing download/install checks.
  --help, -h          Show this help.

Runs the playlist-sync smoke chain:
  1. read-only real sample audit
  2. Fitness temp-copy playlist-only removal and backup-delete
  3. Tech temp-copy playlist-only removal and backup-delete
  4. optional missing-entry ZIP downloads to system temp
  5. optional missing-entry installs to a temp CustomLevels folder

The script delegates to focused smoke scripts and never writes into the real
sample directory. Missing download/install extensions are live BeatSaver checks
and refuse to run unless --allow-network is also provided.
''';
