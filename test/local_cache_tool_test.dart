import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('project LocalCache.saver inspect and validate stay offline', () async {
    final inspect = await _runTool([
      'tool/local_cache_inspect.dart',
      'LocalCache.saver',
    ]);

    expect(inspect.exitCode, 0);
    expect(inspect.stderr, isEmpty);
    expect(inspect.stdout, contains('cache=LocalCache.saver'));
    expect(inspect.stdout, contains('maps=81962'));
    expect(inspect.stdout, contains('incrementalAdded=81'));
    expect(inspect.stdout, contains('incrementalUpdated=19'));

    final validate = await _runTool([
      'tool/local_cache_validate.dart',
      '--cache=LocalCache.saver',
    ]);

    expect(validate.exitCode, 0);
    expect(validate.stderr, isEmpty);
    expect(validate.stdout, contains('maps=81962'));
    expect(validate.stdout, contains('duplicateIds=0'));
    expect(validate.stdout, contains('duplicateHashes=0'));
    expect(validate.stdout, contains('errors=0'));
    expect(validate.stdout, contains('apiChecked=0'));
    expect(validate.stdout, contains('localCacheValidate=passed'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<ProcessResult> _runTool(List<String> args) {
  return Process.run(
    Platform.resolvedExecutable,
    ['run', ...args],
    workingDirectory: Directory.current.path,
  );
}
