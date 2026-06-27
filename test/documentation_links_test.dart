import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('documented project entrypoints still exist after rename cleanup', () {
    for (final path in _documentedFiles) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Documented file should exist: $path',
      );
    }

    for (final path in _documentedDirectories) {
      expect(
        Directory(path).existsSync(),
        isTrue,
        reason: 'Documented directory should exist: $path',
      );
    }

    final toolScripts = Directory('tool')
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .map((file) => p.toUri(p.relative(file.path)).path)
        .toSet();

    for (final script in _documentedToolScripts) {
      expect(
        toolScripts,
        contains(script),
        reason: 'Documented tool script should exist: $script',
      );
    }
  });

  test('README and final checklist mention the current product identity', () {
    final readme = File('README.md').readAsStringSync();
    final checklist =
        File('docs/FINAL_ACCEPTANCE_CHECKLIST_CN.md').readAsStringSync();
    final appPubspec = File('apps/beat_saber_song_toolkit_app/pubspec.yaml')
        .readAsStringSync();
    final runnerCmake =
        File('apps/beat_saber_song_toolkit_app/windows/runner/CMakeLists.txt')
            .readAsStringSync();
    final runnerResources =
        File('apps/beat_saber_song_toolkit_app/windows/runner/Runner.rc')
            .readAsStringSync();

    expect(readme, contains('Beat Saber Song Toolkit'));
    expect(readme, contains('当前版本为 `0.1.0`'));
    expect(readme, contains('apps/beat_saber_song_toolkit_app'));
    expect(readme, contains('bin/beat_saber_song_toolkit.dart'));
    expect(
      readme,
      contains(
        'apps/beat_saber_song_toolkit_app/build/windows/x64/runner/Release/Beat Saber Song Toolkit.exe',
      ),
    );
    expect(checklist, contains('Beat Saber Song Toolkit v0.1.0'));
    expect(appPubspec, contains('version: 0.1.0+1'));
    expect(runnerCmake, contains('OUTPUT_NAME "Beat Saber Song Toolkit"'));
    expect(
      runnerResources,
      contains('"OriginalFilename", "Beat Saber Song Toolkit.exe"'),
    );
    expect(
        runnerResources, contains('"ProductName", "Beat Saber Song Toolkit"'));
    expect(
      runnerResources,
      contains('"FileDescription", "Beat Saber Song Toolkit"'),
    );
    expect(
      File('apps/beat_saber_song_toolkit_app/lib/main.dart').readAsStringSync(),
      isNot(contains("hintText: 'BeatSpider'")),
    );
    expect(
      File('apps/beat_saber_song_toolkit_app/lib/main.dart').readAsStringSync(),
      isNot(contains("XTypeGroup(label: 'BeatSpider 本地数据缓存'")),
    );
  });

  test('tool README documents every tool script', () {
    final toolReadme = File('tool/README.md').readAsStringSync();
    final toolScripts = Directory('tool')
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart')
        .map((file) => p.join('tool', p.basename(file.path)))
        .toList()
      ..sort();

    expect(toolScripts, isNotEmpty);
    for (final script in toolScripts) {
      expect(
        toolReadme,
        contains(script),
        reason: 'tool/README.md should document $script.',
      );
    }
  });

  test('app buttons keep tooltip coverage for final GUI pass', () {
    final mainLines = File('apps/beat_saber_song_toolkit_app/lib/main.dart')
        .readAsLinesSync();

    final uncovered = <String>[];
    for (var index = 0; index < mainLines.length; index += 1) {
      final line = mainLines[index];
      if (!_buttonConstructionPatterns
          .any((pattern) => pattern.hasMatch(line))) {
        continue;
      }

      final start = index - 6 < 0 ? 0 : index - 6;
      final end =
          index + 10 >= mainLines.length ? mainLines.length - 1 : index + 10;
      final window = mainLines.sublist(start, end + 1).join('\n');
      final hasTooltip = window.contains('tooltip:') ||
          window.contains('Tooltip(') ||
          window.contains('_withOptionalTooltip(');
      final isDialogAction = window.contains('AlertDialog(') ||
          window.contains('Navigator.of(context).pop(');
      if (!hasTooltip) {
        if (!isDialogAction) {
          uncovered.add('${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      uncovered,
      isEmpty,
      reason: 'Every visible button should carry a tooltip or tooltip wrapper.',
    );
  });

  test('final checklist references automated safety and offline coverage', () {
    final checklist =
        File('docs/FINAL_ACCEPTANCE_CHECKLIST_CN.md').readAsStringSync();
    final widgetTests = File(
      'apps/beat_saber_song_toolkit_app/test/widget_test.dart',
    ).readAsStringSync();

    for (final testPath in _checklistTestReferences) {
      expect(
        checklist,
        contains(testPath),
        reason: 'Final checklist should reference $testPath.',
      );
    }
    for (final testName in _finalChecklistWidgetTests) {
      expect(
        widgetTests,
        contains(testName),
        reason:
            'App widget tests should contain final checklist test: $testName',
      );
    }
    for (final phrase in _finalChecklistCoveragePhrases) {
      expect(
        checklist,
        contains(phrase),
        reason: 'Final checklist should keep coverage phrase: $phrase',
      );
    }
    for (final phrase in _manualReleaseAcceptanceRecordPhrases) {
      expect(
        checklist,
        contains(phrase),
        reason: 'Final checklist should keep manual acceptance phrase: $phrase',
      );
    }
    expect(checklist, contains('本地私有资料'));
    expect(checklist,
        isNot(contains('docs\\MANUAL_RELEASE_ACCEPTANCE_RECORD_CN.md')));
    expect(checklist, contains('apiChecked=0'));
    expect(checklist, contains('Windows release 实机行为仍在最终验收中确认'));
  });

  test('external dependency boundaries stay explicit in docs', () {
    final readme = File('README.md').readAsStringSync();
    final checklist =
        File('docs/FINAL_ACCEPTANCE_CHECKLIST_CN.md').readAsStringSync();

    for (final phrase in _externalDependencyChecklistPhrases) {
      expect(
        checklist,
        contains(phrase),
        reason: 'Final checklist should keep external dependency note: $phrase',
      );
    }
    expect(readme, contains('release update API URL'));
    expect(readme, contains('GCP Vision API key'));
    expect(readme, contains('原版 BeatSpider default playlist cover sample'));
    expect(readme, contains('泽宇缓存(兼容)'));
    expect(readme, contains('不应视为当前默认可靠数据源'));
  });

  test('CLI help keeps renamed entrypoint and safety gates visible', () async {
    final result = await Process.run(
      _dartExecutable,
      ['run', 'bin/beat_saber_song_toolkit.dart', '--help'],
    );

    expect(result.exitCode, 0);
    expect(result.stdout, contains('bin/beat_saber_song_toolkit.dart'));
    expect(result.stdout, contains('--allow-network'));
    expect(result.stdout, contains('--yes-delete'));
    expect(result.stdout, isNot(contains('beat_spider')));
    expect(result.stdout, isNot(contains('BeatSpider Reborn')));
  });
}

const _documentedFiles = [
  'README.md',
  'bin/beat_saber_song_toolkit.dart',
  'docs/FINAL_ACCEPTANCE_CHECKLIST_CN.md',
  'tool/README.md',
  'apps/beat_saber_song_toolkit_app/pubspec.yaml',
  'apps/beat_saber_song_toolkit_app/test/widget_test.dart',
];

const _documentedDirectories = [
  'apps/beat_saber_song_toolkit_app',
];

const _documentedToolScripts = [
  'tool/toolbox_smoke.dart',
  'tool/songcore_smoke.dart',
  'tool/playlist_sync_smoke.dart',
  'tool/real_sample_library_smoke.dart',
  'tool/local_cache_inspect.dart',
  'tool/local_cache_validate.dart',
  'tool/local_cache_update.dart',
  'tool/local_cache_snapshot_smoke.dart',
  'tool/playlist_sync_missing_download_smoke.dart',
  'tool/playlist_sync_missing_install_smoke.dart',
  'tool/final_acceptance_preflight.dart',
  'tool/release_manual_acceptance_smoke.dart',
];

const _checklistTestReferences = [
  'test\\local_cache_tool_test.dart',
  'test\\cli_safety_test.dart',
  'test\\tool_network_gate_test.dart',
  'test\\tool_help_test.dart',
  'test\\tool_real_sample_safety_test.dart',
  'test\\documentation_links_test.dart',
];

final _buttonConstructionPatterns = [
  RegExp(r'\bIconButton\('),
  RegExp(r'\bElevatedButton\.icon\('),
  RegExp(r'\bOutlinedButton\.icon\('),
  RegExp(r'\bFilledButton\.icon\('),
  RegExp(r'\bFilledButton\.tonalIcon\('),
  RegExp(r'\bTextButton\.icon\('),
];

const _finalChecklistWidgetTests = [
  'covers final destructive confirmation checklist text',
  'covers final file picker and export status checklist text',
  'covers final startup argument checklist semantics',
  'covers final queue and ZIP cache checklist semantics',
  'covers final LocalCache workspace checklist semantics',
  'covers final workspace first-screen checklist',
  'keeps playlist sync table header fixed while scrolling',
  'covers final local library workspace checklist semantics',
  'shows workspace help from the title bar',
  'shows update dialog from configured release API',
];

const _finalChecklistCoveragePhrases = [
  '三主线离线总控',
  'SongCore 核心',
  '本地曲库核心',
  '歌单同步核心',
  'LocalCache 核心',
  'CLI：`--help`',
  'GUI helper / widget',
  '启动参数 helper',
  '安全门禁',
  '文档入口',
  '人工验收记录',
];

const _manualReleaseAcceptanceRecordPhrases = [
  '本地私有记录',
  '文件/目录选择器',
  '破坏性确认弹窗',
  '队列/ZIP 手感',
  '真实样本扫描后的长表手感',
  'LocalCache 离线工作区',
];

const _externalDependencyChecklistPhrases = [
  '项目自己的 release API 地址：当前默认留空',
  'GCP Vision API key：用户提供 key 后',
  '泽宇缓存域名 `beatsaver.wgzeyu.vip`：当前仅保留兼容入口',
  '原版默认 bplist 封面 `https://s.wgzeyu.com/BeatSpider/cover.jpg`',
  '当前域名不可解析',
];

String get _dartExecutable {
  final executable = Platform.resolvedExecutable;
  if (p.basenameWithoutExtension(executable).toLowerCase() == 'dart') {
    return executable;
  }
  return r'D:\Software\flutter\bin\dart.bat';
}
