import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }

  final skipReleaseSmoke = args.contains('--skip-release-smoke');
  final before = await _runningReleaseProcesses();
  if (before.isNotEmpty) {
    stderr.writeln('Release processes are already running:');
    for (final process in before) {
      stderr.writeln(
        '  pid=${process.pid} name=${process.name} title="${process.title}"',
      );
    }
    stderr.writeln('Close them before final acceptance preflight.');
    exitCode = 70;
    return;
  }

  final commands = <_Command>[
    _Command('documentation_links_test', [
      'test',
      r'test\documentation_links_test.dart',
    ]),
    _Command('tool_help_test', ['test', r'test\tool_help_test.dart']),
    _Command('root_analyze', ['analyze']),
    if (!skipReleaseSmoke)
      _Command('release_manual_acceptance_smoke', [
        'run',
        r'tool\release_manual_acceptance_smoke.dart',
      ]),
  ];

  for (final command in commands) {
    await _runDartCommand(command);
  }

  final after = await _runningReleaseProcesses();
  if (after.isNotEmpty) {
    stderr.writeln('Release processes were left running:');
    for (final process in after) {
      stderr.writeln(
        '  pid=${process.pid} name=${process.name} title="${process.title}"',
      );
    }
    exitCode = 70;
    return;
  }

  print(
    'finalAcceptancePreflight=passed '
    'releaseSmoke=${skipReleaseSmoke ? 'skipped' : 'passed'}',
  );
}

Future<void> _runDartCommand(_Command command) async {
  print('preflightStep=${command.name} status=running');
  final result = await Process.run(
    Platform.resolvedExecutable,
    command.args,
    workingDirectory: Directory.current.path,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw StateError(
      'Preflight step failed: ${command.name} exitCode=${result.exitCode}',
    );
  }
  print('preflightStep=${command.name} status=passed');
}

Future<List<_ProjectProcess>> _runningReleaseProcesses() async {
  if (!Platform.isWindows) {
    return const [];
  }
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    r'''
$processes = Get-Process | Where-Object {
  $_.ProcessName -like 'Beat Saber Song Toolkit*'
} | Select-Object Id, ProcessName, MainWindowTitle
$processes | ConvertTo-Json -Compress
''',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Failed to inspect processes: ${result.stderr}');
  }
  final text = result.stdout.toString().trim();
  if (text.isEmpty) {
    return const [];
  }
  final decoded = jsonDecode(text);
  final items = decoded is List ? decoded : [decoded];
  return [
    for (final item in items.cast<Map<String, Object?>>())
      _ProjectProcess(
        pid: item['Id'] as int,
        name: item['ProcessName']?.toString() ?? '',
        title: item['MainWindowTitle']?.toString() ?? '',
      ),
  ];
}

class _Command {
  const _Command(this.name, this.args);

  final String name;
  final List<String> args;
}

class _ProjectProcess {
  const _ProjectProcess({
    required this.pid,
    required this.name,
    required this.title,
  });

  final int pid;
  final String name;
  final String title;
}

const _usage = r'''
Usage:
  dart run tool\final_acceptance_preflight.dart [options]

Options:
  --skip-release-smoke
      Skip tool\release_manual_acceptance_smoke.dart. Use only when a release
      window cannot be launched in the current environment.
  --help, -h
      Show this help.

Runs the offline final-acceptance preflight:
  1. Checks no release process is already running.
  2. Runs documentation_links_test.
  3. Runs tool_help_test.
  4. Runs root dart analyze.
  5. Runs release_manual_acceptance_smoke unless skipped.
  6. Checks no release process remains.

The default path does not contact BeatSaver and does not write user settings.
''';
