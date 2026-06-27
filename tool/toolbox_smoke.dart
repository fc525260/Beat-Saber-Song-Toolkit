import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final sampleRoot =
      _option(args, '--sample-root=') ?? p.join('test', 'Beat Saber  songs');
  final dartExecutable = Platform.resolvedExecutable;
  final root = Directory.current.path;
  final steps = [
    _SmokeStep(
      name: 'SongCore 总控',
      script: 'songcore_smoke.dart',
      args: const [],
    ),
    _SmokeStep(
      name: '本地曲库真实样本总控',
      script: 'real_sample_library_smoke.dart',
      args: ['--sample-root=$sampleRoot'],
    ),
    _SmokeStep(
      name: '歌单同步总控',
      script: 'playlist_sync_smoke.dart',
      args: ['--sample-root=$sampleRoot'],
    ),
  ];

  print('sampleRoot=$sampleRoot');
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
  print('toolboxSmoke=passed');
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
  dart run tool\toolbox_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --help, -h          Show this help.

Runs the toolbox smoke chain:
  1. SongCore total smoke
  2. real-sample local-library total smoke
  3. playlist-sync total smoke

The script delegates to focused total smoke scripts. Real sample steps are
read-only and write only to system temp directories.
''';
