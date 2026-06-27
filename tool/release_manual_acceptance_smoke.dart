import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }
  if (!Platform.isWindows) {
    print('releaseManualAcceptanceSmoke=skipped nonWindows=true');
    return;
  }

  final modes = _option(args, '--modes=')
          ?.split(',')
          .map((mode) => mode.trim())
          .where((mode) => mode.isNotEmpty)
          .toList(growable: false) ??
      const ['library', 'playlistSync', 'fastlog', 'search'];
  final unsupported = modes.where((mode) => !_supportedModes.contains(mode));
  if (unsupported.isNotEmpty) {
    stderr.writeln('Unsupported mode(s): ${unsupported.join(', ')}');
    stderr.writeln('Supported modes: ${_supportedModes.join(', ')}');
    exitCode = 64;
    return;
  }

  for (final mode in modes) {
    await _smokeMode(mode);
  }
  print('releaseManualAcceptanceSmoke=passed modes=${modes.join(',')}');
}

Future<void> _smokeMode(String mode) async {
  final launch = await Process.run(
    Platform.resolvedExecutable,
    ['run', r'tool\release_manual_acceptance.dart', '--mode=$mode'],
    workingDirectory: Directory.current.path,
  );
  final stdoutText = launch.stdout.toString();
  final stderrText = launch.stderr.toString();
  if (launch.exitCode != 0) {
    stderr.writeln(stdoutText);
    stderr.writeln(stderrText);
    throw StateError('release_manual_acceptance failed for mode=$mode.');
  }

  final pid = _lineValue(stdoutText, 'pid=');
  final tempRoot = _lineValue(stdoutText, 'tempRoot=');
  if (pid == null || int.tryParse(pid) == null) {
    throw StateError('Launcher did not print a valid pid for mode=$mode.');
  }

  final processId = int.parse(pid);
  try {
    final status = await _waitForReleaseWindow(processId);
    if (status.processName != 'Beat Saber Song Toolkit') {
      throw StateError(
        'Unexpected process for mode=$mode: ${status.processName}.',
      );
    }
    if (!status.responding) {
      throw StateError('Release process is not responding for mode=$mode.');
    }
    if (status.mainWindowTitle != 'Beat Saber Song Toolkit v0.1.0') {
      throw StateError(
        'Unexpected title for mode=$mode: ${status.mainWindowTitle}.',
      );
    }
    print(
      'mode=$mode pid=$processId responding=${status.responding} '
      'title="${status.mainWindowTitle}"',
    );
  } finally {
    await _stopProcess(processId);
    if (tempRoot != null) {
      await _deleteTempRoot(tempRoot);
    }
  }
}

Future<_ReleaseStatus> _waitForReleaseWindow(int processId) async {
  Object? lastError;
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      final status = await _readReleaseStatus(processId);
      if (status.mainWindowTitle.isNotEmpty) {
        return status;
      }
      lastError = StateError('window title is still empty');
    } catch (error) {
      lastError = error;
    }
  }
  throw StateError('Timed out waiting for release window: $lastError');
}

Future<_ReleaseStatus> _readReleaseStatus(int processId) async {
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    '''
\$ErrorActionPreference = 'Stop'
\$p = Get-Process -Id $processId -ErrorAction SilentlyContinue
if (-not \$p) { exit 3 }
[pscustomobject]@{
  ProcessName = \$p.ProcessName
  Responding = \$p.Responding
  MainWindowTitle = \$p.MainWindowTitle
} | ConvertTo-Json -Compress
''',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Get-Process failed for pid=$processId: ${result.stderr}',
    );
  }
  final json = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
  return _ReleaseStatus(
    processName: json['ProcessName']?.toString() ?? '',
    responding: json['Responding'] == true,
    mainWindowTitle: json['MainWindowTitle']?.toString() ?? '',
  );
}

Future<void> _stopProcess(int processId) async {
  await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    'Stop-Process -Id $processId -ErrorAction SilentlyContinue',
  ]);
}

Future<void> _deleteTempRoot(String tempRoot) async {
  final directory = Directory(tempRoot);
  if (!await directory.exists()) {
    return;
  }
  try {
    await directory.delete(recursive: true);
  } catch (error) {
    stderr.writeln('warning: failed to delete tempRoot=$tempRoot: $error');
  }
}

String? _lineValue(String text, String prefix) {
  for (final line in const LineSplitter().convert(text)) {
    if (line.startsWith(prefix)) {
      final value = line.substring(prefix.length).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
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

class _ReleaseStatus {
  const _ReleaseStatus({
    required this.processName,
    required this.responding,
    required this.mainWindowTitle,
  });

  final String processName;
  final bool responding;
  final String mainWindowTitle;
}

const _supportedModes = ['library', 'playlistSync', 'fastlog', 'search'];

const _usage = r'''
Usage:
  dart run tool\release_manual_acceptance_smoke.dart [options]

Options:
  --modes=library,playlistSync,fastlog,search
      Comma-separated launcher modes to verify. Defaults to all four modes.
  --help, -h
      Show this help.

This Windows-only smoke launches the release through
tool\release_manual_acceptance.dart, waits for the window title
"Beat Saber Song Toolkit v0.1.0", confirms the process is responding, then
closes it and removes the temporary launcher directory. It does not contact
BeatSaver and does not write user settings.
''';
