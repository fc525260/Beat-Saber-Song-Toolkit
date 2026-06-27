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
      name: '临时曲库操作',
      script: 'library_operation_smoke.dart',
      args: const [],
    ),
    _SmokeStep(
      name: '导出中文曲包',
      script: 'real_sample_library_export_smoke.dart',
      args: ['--sample-root=$sampleRoot', '--pack=中文'],
    ),
    _SmokeStep(
      name: '导出 Tech 曲包',
      script: 'real_sample_library_export_smoke.dart',
      args: ['--sample-root=$sampleRoot', '--pack=Tech'],
    ),
    _SmokeStep(
      name: '重复删除临时副本',
      script: 'real_sample_duplicate_smoke.dart',
      args: ['--sample-root=$sampleRoot', '--pack=中文'],
    ),
    _SmokeStep(
      name: '路径重命名临时副本',
      script: 'real_sample_path_correction_smoke.dart',
      args: ['--sample-root=$sampleRoot', '--pack=Tech'],
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
  print('realSampleLibrarySmoke=passed');
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
  dart run tool\real_sample_library_smoke.dart [options]

Options:
  --sample-root=PATH  Real sample root. Defaults to test\Beat Saber  songs.
  --help, -h         Show this help.

Runs the real-sample local-library smoke chain:
  1. temp local-library operation smoke
  2. export 中文 pack to bplist in temp
  3. export Tech pack to bplist in temp
  4. duplicate backup-delete on a temp copy
  5. path correction rename on a temp copy

The script delegates to the focused smoke scripts. The real sample root read-only
rule is preserved: real-sample steps never write into the real sample directory.
''';
