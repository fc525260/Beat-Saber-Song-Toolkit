import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('networked tool scripts refuse to run without allow-network', () async {
    for (final command in _networkedToolCommands) {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', command.script, ...command.args],
        workingDirectory: Directory.current.path,
      );

      expect(
        result.exitCode,
        isIn([2, 64]),
        reason: command.description,
      );
      expect(result.stderr, contains('--allow-network'));
    }
  });

  test('networked tool scripts stay documented as explicit network actions',
      () {
    final toolReadme = File('tool/README.md').readAsStringSync();

    expect(toolReadme, contains('--allow-network'));
    for (final script in _networkedToolCommands.map((c) => c.script).toSet()) {
      expect(
        toolReadme,
        contains(script.replaceAll('/', r'\')),
        reason: 'Networked tool should be documented in tool/README.md.',
      );
    }
  });
}

const _networkedToolCommands = [
  _ToolCommand(
    'tool/local_cache_update.dart',
    ['--cache=LocalCache.saver'],
  ),
  _ToolCommand('tool/local_cache_snapshot_smoke.dart'),
  _ToolCommand('tool/local_cache_snapshot_smoke.dart', ['--incremental']),
  _ToolCommand('tool/local_cache_snapshot_smoke.dart', ['--deleted-audit']),
  _ToolCommand('tool/playlist_sync_smoke.dart', ['--with-missing-download']),
  _ToolCommand('tool/playlist_sync_smoke.dart', ['--with-missing-install']),
  _ToolCommand('tool/playlist_sync_missing_resolve_smoke.dart'),
  _ToolCommand('tool/playlist_sync_missing_download_smoke.dart'),
  _ToolCommand('tool/playlist_sync_missing_install_smoke.dart'),
];

class _ToolCommand {
  const _ToolCommand(this.script, [this.args = const []]);

  final String script;
  final List<String> args;

  String get description => '$script ${args.join(' ')}'.trim();
}
