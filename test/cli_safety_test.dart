import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('prints CLI help without requiring a failing command', () async {
    final result = await _runCli(['--help']);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('Usage:'));
    expect(result.stdout, contains('--allow-network'));
    expect(result.stdout, contains('--yes-delete'));
    expect(result.stderr, isEmpty);
  });

  test('prints usage as an error when no command is provided', () async {
    final result = await _runCli([]);

    expect(result.exitCode, 64);
    expect(result.stderr, contains('Usage:'));
    expect(result.stderr, contains('--allow-network'));
    expect(result.stderr, contains('--yes-delete'));
  });

  test('refuses network CLI operations without allow-network', () async {
    for (final args in [
      ['--query', 'camellia'],
      ['--download-id', '1520'],
      ['--install-id', '1520'],
      ['--batch-install', 'camellia'],
      ['--import-bplist', 'missing.bplist'],
    ]) {
      final result = await _runCli(args);

      expect(result.exitCode, 64, reason: args.join(' '));
      expect(result.stderr, contains('--allow-network'));
    }
  });

  test('refuses delete CLI operation without yes-delete', () async {
    final result = await _runCli(['--delete-id', '1520']);

    expect(result.exitCode, 64);
    expect(result.stderr, contains('--yes-delete'));
  });

  test('runs list-installed offline against an empty library', () async {
    final temp = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_cli_list_',
    );
    try {
      final library = Directory(p.join(temp.path, 'CustomLevels'));
      await library.create();

      final result = await _runCli([
        '--list-installed',
        '--install-out',
        library.path,
      ]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Installed library entries: 0'));
      expect(result.stderr, isEmpty);
    } finally {
      await temp.delete(recursive: true);
    }
  });

  test('exports bplist offline from a temporary installed library', () async {
    final temp = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_cli_export_',
    );
    try {
      final library = Directory(p.join(temp.path, 'CustomLevels'));
      final song = Directory(p.join(library.path, 'abc - Offline Song'));
      await song.create(recursive: true);
      await File(p.join(song.path, 'Info.dat')).writeAsString('''
{
  "_songName": "Offline Song",
  "_songAuthorName": "Offline Artist",
  "_levelAuthorName": "Offline Mapper",
  "_beatsPerMinute": 128
}
''');

      final output = p.join(temp.path, 'playlist.bplist');
      final result = await _runCli([
        '--export-bplist',
        output,
        '--install-out',
        library.path,
      ]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Exported bplist'));
      expect(result.stderr, isEmpty);

      final exported = await File(output).readAsString();
      expect(exported, contains('"playlistTitle": "Beat Saber Song Toolkit"'));
      expect(exported, contains('"playlistAuthor": "Beat Saber Song Toolkit"'));
      expect(exported, contains('"key": "abc"'));
      expect(exported, contains('"songName": "Offline Song"'));
    } finally {
      await temp.delete(recursive: true);
    }
  });
}

Future<ProcessResult> _runCli(List<String> args) {
  return Process.run(
    Platform.resolvedExecutable,
    ['run', 'bin/beat_saber_song_toolkit.dart', ...args],
    workingDirectory: Directory.current.path,
  );
}
