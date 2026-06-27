import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('all tool scripts expose a non-mutating help exit', () async {
    final toolDir = Directory('tool');
    final scripts = toolDir
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .map((file) => p.relative(file.path))
        .toList()
      ..sort();

    expect(scripts, isNotEmpty);

    for (final script in scripts) {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', script, '--help'],
        workingDirectory: Directory.current.path,
      );
      final stdoutText = result.stdout.toString();
      final stderrText = result.stderr.toString();

      expect(
        result.exitCode,
        0,
        reason: '$script --help should exit without running smoke work.\n'
            'stdout:\n$stdoutText\nstderr:\n$stderrText',
      );
      expect(
        stdoutText.toLowerCase(),
        contains('usage:'),
        reason: '$script --help should print usage to stdout.',
      );
      expect(
        stderrText.trim(),
        isEmpty,
        reason: '$script --help should not report errors.',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
