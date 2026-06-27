import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('real-sample tools document and enforce temp-copy safety', () async {
    for (final expectation in _realSampleToolExpectations) {
      final source = await File(expectation.path).readAsString();

      for (final token in expectation.requiredTokens) {
        expect(
          source,
          contains(token),
          reason: '${expectation.path} should contain "$token"',
        );
      }
    }
  });
}

const _realSampleToolExpectations = [
  _ToolSafetyExpectation(
    'tool/real_sample_audit.dart',
    [
      'read-only for the sample root',
      'does not delete, rename',
      'download, install, or modify playlists',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/real_sample_library_export_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'never writes into the real',
      'sample directory',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/real_sample_duplicate_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'sourceDirsStillExist',
      'real sample directory remains untouched',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/real_sample_path_correction_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'sourceStillExists',
      'sourceExpectedExists',
      'real sample source stays unchanged',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/playlist_sync_operation_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'sourceUnchanged',
      'sourceDirsStillExist',
      'The script never writes to the sample root',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/playlist_sync_missing_resolve_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'The real sample',
      'is read-only',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/playlist_sync_missing_download_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'real sample is read-only',
      'no .bplist or song directory is modified',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/playlist_sync_missing_install_smoke.dart',
    [
      'Directory.systemTemp.createTemp',
      'The real sample is read-only',
      'no .bplist or real song directory is modified',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/real_sample_library_smoke.dart',
    [
      'real sample root read-only',
      'write into the real sample directory',
    ],
  ),
  _ToolSafetyExpectation(
    'tool/playlist_sync_smoke.dart',
    [
      'read-only real sample audit',
      'never writes into the real',
      'sample directory',
    ],
  ),
];

class _ToolSafetyExpectation {
  const _ToolSafetyExpectation(this.path, this.requiredTokens);

  final String path;
  final List<String> requiredTokens;
}
