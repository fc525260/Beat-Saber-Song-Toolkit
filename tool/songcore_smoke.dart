import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final dartExecutable = Platform.resolvedExecutable;
  final root = Directory.current.path;
  final steps = const [
    _SmokeStep(
      name: 'SongCore 游戏目录与 Mod 检测',
      script: 'songcore_detection_smoke.dart',
    ),
    _SmokeStep(
      name: 'SongCore 保存读取移除生命周期',
      script: 'songcore_operation_smoke.dart',
    ),
    _SmokeStep(
      name: 'SongCore XML 边界',
      script: 'songcore_xml_boundary_smoke.dart',
    ),
  ];

  print('dart=$dartExecutable');
  print('steps=${steps.length}');

  for (final step in steps) {
    final scriptPath = p.join('tool', step.script);
    print('');
    print('step=${step.name}');
    final result = await Process.run(
      dartExecutable,
      ['run', scriptPath],
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
  print('songCoreSmoke=passed');
}

class _SmokeStep {
  const _SmokeStep({required this.name, required this.script});

  final String name;
  final String script;
}

const _usage = r'''
Usage:
  dart run tool\songcore_smoke.dart [options]

Options:
  --help, -h    Show this help.

Runs the SongCore smoke chain:
  1. game directory and Mod detection against temporary directory shapes
  2. save/read/remove lifecycle against a temporary Beat Saber directory
  3. folders.xml boundary behavior against a temporary Beat Saber directory

The script delegates to focused smoke scripts and never touches a real Beat
Saber installation.
''';
