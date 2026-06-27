import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beat_saber_song_toolkit_app/main.dart';

void main() {
  test('parses original startup arguments', () {
    final options = startupOptionsFromArgs([
      '-config',
      '常用配置',
      '-start',
      '-unzip',
      '-local',
      '-zip',
      '-exit',
      '-minimize',
      '-fastlog',
    ]);

    expect(options.profileName, '常用配置');
    expect(options.autoStart, isTrue);
    expect(options.autoExtract, isTrue);
    expect(options.readLocal, isTrue);
    expect(options.autoPack, isTrue);
    expect(options.autoExit, isTrue);
    expect(options.startMinimized, isTrue);
    expect(options.fastLog, isTrue);
  });

  test('parses inline config startup argument', () {
    final options = startupOptionsFromArgs(['--config=测试配置', '-s']);

    expect(options.profileName, '测试配置');
    expect(options.autoStart, isTrue);
  });

  test('parses alternate profile and config startup argument forms', () {
    expect(startupOptionsFromArgs(['--profile=命令行配置']).profileName, '命令行配置');
    expect(startupOptionsFromArgs(['/config=斜杠配置']).profileName, '斜杠配置');
    expect(startupOptionsFromArgs(['-c', '短参配置']).profileName, '短参配置');
    expect(startupOptionsFromArgs(['位置配置']).profileName, '位置配置');
  });

  test('does not consume startup flags as config names', () {
    final options = startupOptionsFromArgs(['-config', '-start', '-fastlog']);

    expect(options.profileName, isEmpty);
    expect(options.autoStart, isTrue);
    expect(options.fastLog, isTrue);
  });

  test('parses fastlog startup argument', () {
    final options = startupOptionsFromArgs(['-f']);

    expect(options.fastLog, isTrue);
  });

  test('covers final startup argument checklist semantics', () {
    final options = startupOptionsFromArgs([
      '-config',
      'Smoke',
      '-local',
      '-fastlog',
      '-start',
      '-zip',
      '-unzip',
      '-exit',
      '-minimize',
    ]);

    expect(options.profileName, 'Smoke');
    expect(options.readLocal, isTrue);
    expect(options.fastLog, isTrue);
    expect(options.autoStart, isTrue);
    expect(options.autoPack, isTrue);
    expect(options.autoExtract, isTrue);
    expect(options.autoExit, isTrue);
    expect(options.startMinimized, isTrue);
    expect(
      startupAutoStartModeForTest(autoStart: options.autoStart),
      'installSelected',
    );
    expect(
      startupActionsForTest(
        readLocal: options.readLocal,
        fastLog: options.fastLog,
        autoStart: options.autoStart,
        busy: false,
        hasTargetMaps: true,
      ),
      [
        StartupActionForTest.readLocal,
        StartupActionForTest.fastLog,
        StartupActionForTest.installSelected,
      ],
    );
    expect(
      startupActionsForTest(
        readLocal: options.readLocal,
        fastLog: options.fastLog,
        autoStart: options.autoStart,
        busy: true,
        hasTargetMaps: true,
      ),
      [StartupActionForTest.readLocal],
    );
    expect(
      startupActionsForTest(
        readLocal: false,
        fastLog: false,
        autoStart: options.autoStart,
        busy: false,
        hasTargetMaps: false,
      ),
      isEmpty,
    );
    expect(
      selectedStartupProfileForTest(
        profiles: {
          'Smoke': {'query': 'camellia'},
          'Default': {'query': 'ranked'},
        },
        activeProfile: 'Default',
        requestedProfile: options.profileName,
      ),
      'Smoke',
    );
    expect(
      startupMinimizeNeedsRetryForTest(isMinimizedAfterFirstAttempt: false),
      isTrue,
    );
  });

  test('plans startup actions without running busy-only actions', () {
    expect(
      startupActionsForTest(
        readLocal: true,
        fastLog: true,
        autoStart: true,
        busy: false,
        hasTargetMaps: true,
      ),
      [
        StartupActionForTest.readLocal,
        StartupActionForTest.fastLog,
        StartupActionForTest.installSelected,
      ],
    );
    expect(
      startupActionsForTest(
        readLocal: true,
        fastLog: true,
        autoStart: true,
        busy: true,
        hasTargetMaps: true,
      ),
      [StartupActionForTest.readLocal],
    );
    expect(
      startupActionsForTest(
        readLocal: false,
        fastLog: false,
        autoStart: true,
        busy: false,
        hasTargetMaps: false,
      ),
      isEmpty,
    );
  });

  test('routes startup local scan by workspace', () {
    expect(
      startupReadLocalActionForTest(WorkspaceForTest.search),
      StartupReadLocalActionForTest.scanInstalledLibrary,
    );
    expect(
      startupReadLocalActionForTest(WorkspaceForTest.library),
      StartupReadLocalActionForTest.scanInstalledLibrary,
    );
    expect(
      startupReadLocalActionForTest(WorkspaceForTest.playlistSync),
      StartupReadLocalActionForTest.scanPlaylistSync,
    );
  });

  test('formats search order labels', () {
    expect(searchOrderLabelForTest(BeatSaverSearchOrder.latest), '最新');
    expect(searchOrderLabelForTest(BeatSaverSearchOrder.relevance), '相关');
    expect(searchOrderLabelForTest(BeatSaverSearchOrder.rating), '评分');
    expect(searchOrderLabelForTest(BeatSaverSearchOrder.curated), '精选');
    expect(searchOrderLabelForTest(BeatSaverSearchOrder.random), '随机');
    expect(searchOrderLabelForTest(BeatSaverSearchOrder.duration), '时长');
  });

  test('formats duration downloads and byte counts', () {
    expect(formatDurationForTest(0), '未知时长');
    expect(formatDurationForTest(-1), '未知时长');
    expect(formatDurationForTest(65), '1:05');
    expect(formatDurationForTest(3600), '60:00');

    expect(formatDownloadsForTest(0), '下载量未提供');
    expect(formatDownloadsForTest(-10), '下载量未提供');
    expect(formatDownloadsForTest(1234), '下载 1234');

    expect(formatBytesForTest(512), '512 B');
    expect(formatBytesForTest(1536), '1.5 KB');
    expect(formatBytesForTest(2 * 1024 * 1024), '2.0 MB');
    expect(formatBytesForTest(3 * 1024 * 1024 * 1024), '3.0 GB');
  });

  test('compares configured GitHub release versions', () {
    expect(isRemoteVersionNewerForTest('1.0.0', 'v1.0.1'), isTrue);
    expect(isRemoteVersionNewerForTest('1.0.0', 'v1.0.0'), isFalse);
    expect(isRemoteVersionNewerForTest('1.2.0', 'v1.1.9'), isFalse);
  });

  test('parses configured GitHub release asset URL', () {
    final release = releaseInfoFromJsonForTest({
      'tag_name': 'v3.3.4',
      'html_url':
          'https://example.invalid/beat-saber-song-toolkit/releases/v3.3.4',
      'assets': [
        {
          'browser_download_url':
              'https://example.invalid/beat-saber-song-toolkit/downloads/BeatSaberSongToolkit.zip',
        },
      ],
    });

    expect(release.tagName, 'v3.3.4');
    expect(
      release.htmlUrl,
      'https://example.invalid/beat-saber-song-toolkit/releases/v3.3.4',
    );
    expect(
      release.downloadUrl,
      'https://example.invalid/beat-saber-song-toolkit/downloads/BeatSaberSongToolkit.zip',
    );
  });

  test('parses GitHub release without assets', () {
    final release = releaseInfoFromJsonForTest({
      'tag_name': 'v3.3.4',
      'html_url':
          'https://example.invalid/beat-saber-song-toolkit/releases/v3.3.4',
    });

    expect(release.downloadUrl, isEmpty);
  });

  test('formats update check messages', () {
    expect(
      updateAvailableMessageForTest(
        currentVersion: '1.0.0',
        release: const ReleaseInfo(
          tagName: 'v1.0.1',
          htmlUrl: 'https://example.invalid/releases/v1.0.1',
          downloadUrl: 'https://example.invalid/downloads/app.zip',
        ),
      ),
      '发现新版 v1.0.1，当前版本 1.0.0。 '
      '发布页：https://example.invalid/releases/v1.0.1 '
      '下载地址：https://example.invalid/downloads/app.zip',
    );
    expect(updateLatestMessageForTest('1.0.0'), '当前已是最新版本：1.0.0');
  });

  test('uses renamed default export filenames', () {
    expect(defaultLogExportFilenameForTest, 'beat_saber_song_toolkit_logs.txt');
    expect(
      defaultTargetListExportFilenameForTest,
      'beat_saber_song_toolkit_targets.txt',
    );
  });

  test('formats playlist sync scan status', () {
    final entries = [
      PlaylistSyncEntry(
        playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
        beatSaverDetail: const BeatSaverHashDetail(
          id: 'abc',
          name: 'Song',
          description: '',
        ),
        installedEntry: InstalledSongEntry(
          directory: Directory('installed/abc - Song'),
          directoryName: 'abc - Song',
          hasInfoDat: true,
          info: const InstalledSongInfo(
            songName: 'Song',
            songSubName: '',
            songAuthorName: 'Artist',
            levelAuthorName: 'Mapper',
            beatsPerMinute: 180,
          ),
          mapId: 'abc',
          title: 'Song',
        ),
        matchType: PlaylistSyncMatchType.mapId,
        hasEgg: true,
      ),
      PlaylistSyncEntry(
        playlistEntry: const BplistSongEntry(key: '', hash: 'hash2'),
        beatSaverDetail: const BeatSaverHashDetail(
          id: 'def',
          name: 'Other',
          description: '',
        ),
        installedEntry: InstalledSongEntry(
          directory: Directory('installed/noid - Other'),
          directoryName: 'noid - Other',
          hasInfoDat: true,
          info: const InstalledSongInfo(
            songName: 'Other',
            songSubName: '',
            songAuthorName: 'Artist',
            levelAuthorName: 'Mapper',
            beatsPerMinute: 180,
          ),
          title: 'Other',
        ),
        matchType: PlaylistSyncMatchType.normalizedName,
        hasEgg: false,
      ),
      PlaylistSyncEntry(
        playlistEntry: const BplistSongEntry(key: '', hash: 'hash-local'),
        beatSaverDetail: null,
        installedEntry: InstalledSongEntry(
          directory: Directory('installed/local - Hash'),
          directoryName: 'local - Hash',
          hasInfoDat: true,
          info: const InstalledSongInfo(
            songName: 'Hash',
            songSubName: '',
            songAuthorName: 'Artist',
            levelAuthorName: 'Mapper',
            beatsPerMinute: 180,
          ),
          title: 'Hash',
        ),
        matchType: PlaylistSyncMatchType.localHash,
        hasEgg: true,
      ),
      const PlaylistSyncEntry(
        playlistEntry: BplistSongEntry(key: '', hash: 'hash3'),
        beatSaverDetail: null,
        installedEntry: null,
        matchType: PlaylistSyncMatchType.missing,
        hasEgg: false,
      ),
    ];

    expect(
      playlistSyncStatusForTest(entries),
      '歌单同步扫描完成：共 4，本地存在 3，缺失 1，名称辅助匹配 1，'
      'Hash匹配 1，缺少 egg 1',
    );
    expect(
      playlistSyncExportListForTest(entries),
      [
        '状态\t原因\t匹配\t名称一致\tID\tHash\tBeatSaver名称\t本地名称\t作者\t难度\tEgg\t路径',
        '本地存在\t-\tID 匹配\t是\tabc\thash1\tSong\tSong\tArtist\t-\t是\tinstalled/abc - Song',
        '本地存在\t-\t名称辅助匹配\t是\t-\thash2\tOther\tOther\tArtist\t-\t否\tinstalled/noid - Other',
        '本地存在\t-\tHash 匹配\t是\t-\thash-local\t-\tHash\tArtist\t-\t是\tinstalled/local - Hash',
        '缺失\t本地未找到相同 hash\t本地缺失\t是\t-\thash3\t-\t-\t-\t-\t否\t-',
      ].join('\n'),
    );
    expect(playlistSyncMissingReasonForTest(entries.last), '本地未找到相同 hash');
    expect(
      playlistSyncMissingAddProgressStatusForTest(
        current: 1,
        total: 4,
        entry: entries.last,
      ),
      '正在解析缺失歌曲 1/4：ID -，Hash hash3',
    );
    expect(
      playlistSyncMissingAddStatusForTest(
        requested: 4,
        added: 2,
        existing: 1,
        failed: 1,
      ),
      '缺失加入本次完成：请求 4，新增 2，已存在 1，失败 1',
    );
    expect(
      playlistSyncMissingDownloadStatusForTest(
        requested: 4,
        resolved: 3,
        downloaded: 2,
        skipped: 1,
        stopped: 0,
        failed: 1,
      ),
      '缺失下载完成：请求 4，解析 3，下载 2，跳过 1，停止 0，失败 1',
    );
    expect(
      playlistSyncMissingInstallStatusForTest(
        requested: 4,
        resolved: 3,
        installed: 2,
        skipped: 1,
        stopped: 0,
        failed: 1,
      ),
      '缺失安装完成：请求 4，解析 3，安装 2，跳过 1，停止 0，失败 1',
    );
    expect(
      playlistSyncMissingReasonForTest(
        const PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'abc', hash: ''),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ),
      '本地未找到相同 ID',
    );
    expect(
      playlistSyncMissingReasonForTest(
        const PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: ''),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ),
      '歌单条目缺少 ID/hash',
    );
    final report = playlistSyncDifferenceReportForTest(
      entries: entries,
      localOnlyInstalledEntries: [
        InstalledSongEntry(
          directory: Directory('installed/local-only'),
          directoryName: 'local-only',
          hasInfoDat: true,
          info: const InstalledSongInfo(
            songName: 'Local Only',
            songSubName: '',
            songAuthorName: 'Artist',
            levelAuthorName: 'Mapper',
            beatsPerMinute: 120,
          ),
          mapId: 'def',
          title: 'Local Only',
        ),
      ],
    );
    expect(report, contains('歌单同步差异报告'));
    expect(report, contains('缺失\t1'));
    expect(report, contains('本地有，歌单无\t1'));
    expect(report, contains('def\tLocal Only\tArtist\tMapper\t正常\tlocal-only'));
    expect(playlistSyncEntryKeyForTest(entries.first), 'abc|hash1');
    expect(
      playlistSyncEntryKeyForTest(
        const PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: 'ABC', hash: ''),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ),
      'key:abc',
    );
    expect(
      playlistSyncEntryKeyForTest(
        const PlaylistSyncEntry(
          playlistEntry: BplistSongEntry(key: '', hash: 'HASH1'),
          beatSaverDetail: null,
          installedEntry: null,
          matchType: PlaylistSyncMatchType.missing,
          hasEgg: false,
        ),
      ),
      'hash:hash1',
    );
    expect(playlistSyncFilterLabelsForTest(), [
      '全部',
      '本地存在',
      '缺失',
      'Hash匹配',
      '名称辅助匹配',
      '名称不一致',
      '缺 egg',
    ]);
    expect(playlistSyncNameMismatchForTest(entries.first), isFalse);
    expect(
      playlistSyncNameMismatchForTest(
        PlaylistSyncEntry(
          playlistEntry: const BplistSongEntry(key: 'abc', hash: 'hash1'),
          beatSaverDetail: const BeatSaverHashDetail(
            id: 'abc',
            name: 'Remote Song',
            description: '',
          ),
          installedEntry: InstalledSongEntry(
            directory: Directory('installed/abc - Song'),
            directoryName: 'abc - Song',
            hasInfoDat: true,
            info: const InstalledSongInfo(
              songName: 'Local Song',
              songSubName: '',
              songAuthorName: 'Artist',
              levelAuthorName: 'Mapper',
              beatsPerMinute: 180,
            ),
            mapId: 'abc',
            title: 'Local Song',
          ),
          matchType: PlaylistSyncMatchType.mapId,
          hasEgg: true,
        ),
      ),
      isTrue,
    );
    expect(
      playlistSyncDeleteStatusForTest(
        PlaylistSyncDeleteResult(
          requested: 2,
          deleted: 2,
          removedPlaylistEntries: 2,
          playlistBackup: File('backup/songs.bplist'),
          songBackups: [Directory('backup/a'), Directory('backup/b')],
        ),
      ),
      '歌单同步删除完成：请求 2，删除本地目录 2，歌单移除 2，'
      '歌曲备份 2，歌单备份：backup/songs.bplist，歌单备份目录：backup，'
      '歌曲备份目录：backup',
    );
    expect(
      playlistSyncDeleteStatusForTest(
        PlaylistSyncDeleteResult(
          requested: 1,
          deleted: 0,
          removedPlaylistEntries: 1,
          playlistBackup: File('backup/songs.bplist'),
          songBackups: const [],
        ),
      ),
      '歌单同步删除完成：请求 1，删除本地目录 0，歌单移除 1，'
      '歌曲备份 0，歌单备份：backup/songs.bplist，歌单备份目录：backup，'
      '未备份本地歌曲目录',
    );
    expect(
      playlistSyncDeleteStatusForTest(
        PlaylistSyncDeleteResult(
          requested: 1,
          deleted: 0,
          removedPlaylistEntries: 0,
          songBackups: const [],
        ),
      ),
      '歌单同步删除完成：请求 1，删除本地目录 0，歌单移除 0，'
      '歌曲备份 0，无歌单备份，未备份本地歌曲目录',
    );
    expect(
      playlistSyncPlaylistRemoveStatusForTest(
        PlaylistSyncPlaylistRemoveResult(
          requested: 2,
          removedPlaylistEntries: 2,
          playlistBackup: File('backup/songs.bplist'),
        ),
      ),
      '歌单同步移出完成：请求 2，歌单移除 2，未删除本地目录，'
      '歌单备份：backup/songs.bplist，歌单备份目录：backup',
    );
    expect(
      playlistSyncPlaylistRemoveStatusForTest(
        PlaylistSyncPlaylistRemoveResult(
          requested: 1,
          removedPlaylistEntries: 0,
        ),
      ),
      '歌单同步移出完成：请求 1，歌单移除 0，未删除本地目录，无歌单备份',
    );
  });

  test(
    'formats donation note with reference projects and sponsorship text',
    () {
      final message = donateAuthorMessageForTest();

      expect(message, contains('参考项目与原作者信息'));
      expect(message, contains('https://github.com/WGzeyu/BeatSpider'));
      expect(
        message,
        contains('https://github.com/WGzeyu/Beat-Saber-Song-Folder-Manager'),
      );
      expect(
        message,
        contains('https://github.com/fc525260/Beat-Saber-Playlist-File-Sync'),
      );
      expect(message, contains('全程由 GPT-5.5 协助完成'));
      expect(message, contains('用于收回使用大模型的成本'));
    },
  );

  test('expands output path templates', () {
    final path = outputPathFromTemplateForTest(
      'exported/[日期]-[配置]-[配置名称].zip',
      extension: 'zip',
      profileName: '常用:配置',
      now: DateTime(2026, 6, 6),
    );

    expect(path, 'exported/20260606-常用_配置-常用_配置.zip');
  });

  test('builds default output path from profile name', () {
    expect(
      outputPathFromTemplateForTest(
        '',
        extension: 'bplist',
        profileName: '  ...  ',
        now: DateTime(2026, 6, 6),
      ),
      'songs.bplist',
    );
  });

  test('sanitizes output profile names for file paths', () {
    expect(
      safeOutputProfileNameForTest('  常用\t配置\r\nA:B<C>D"E/F\\G|H?I*J  '),
      '常用 配置 A_B_C_D_E_F_G_H_I_J',
    );
    expect(safeOutputProfileNameForTest('...'), 'songs');
    expect(safeOutputProfileNameForTest('  '), 'songs');
  });

  test('selects requested startup profile before active profile', () {
    final selected = selectedStartupProfileForTest(
      profiles: {
        '默认': {'query': 'camellia'},
        '启动': {'query': 'ranked'},
      },
      activeProfile: '默认',
      requestedProfile: '启动',
    );

    expect(selected, '启动');
  });

  test('falls back to active profile when startup profile is missing', () {
    final selected = selectedStartupProfileForTest(
      profiles: {
        '默认': {'query': 'camellia'},
      },
      activeProfile: '默认',
      requestedProfile: '不存在',
    );

    expect(selected, '默认');
  });

  test('parses saved profiles from settings', () {
    final profiles = profilesFromSettingsForTest({
      'profiles': {
        '默认': {'query': 'camellia'},
        '  ': {'query': 'ignored'},
        '空配置': <String, dynamic>{},
        '旧格式': {'pageSize': 20},
        '非法': 'not-a-map',
      },
    });

    expect(profiles.keys, ['默认', '旧格式']);
    expect(profiles['默认']?['query'], 'camellia');
    expect(profiles['旧格式']?['pageSize'], 20);
    expect(profilesFromSettingsForTest({'profiles': 'bad'}), isEmpty);
    expect(profilesFromSettingsForTest({}), isEmpty);
  });

  test('parses scalar settings with fallbacks', () {
    final settings = {
      'text': 'value',
      'textNumber': 42,
      'ids': [' abc ', 'def', '', 'abc', 123],
      'flag': true,
      'flagText': 'true',
      'intValue': 12,
      'numValue': 12.8,
      'intText': '34',
      'badInt': 'x',
      'doubleValue': 1.5,
      'doubleInt': 2,
      'doubleText': '3.25',
      'badDouble': 'x',
    };

    expect(settingStringForTest(settings, 'text', 'fallback'), 'value');
    expect(
      settingStringForTest(settings, 'textNumber', 'fallback'),
      'fallback',
    );
    expect(settingStringListForTest(settings, 'ids'), ['abc', 'def', '123']);
    expect(settingStringListForTest(settings, 'missing'), isEmpty);
    expect(settingBoolForTest(settings, 'flag', false), isTrue);
    expect(settingBoolForTest(settings, 'flagText', false), isFalse);
    expect(settingIntForTest(settings, 'intValue', 1), 12);
    expect(settingIntForTest(settings, 'numValue', 1), 12);
    expect(settingIntForTest(settings, 'intText', 1), 34);
    expect(settingIntForTest(settings, 'badInt', 1), 1);
    expect(settingDoubleForTest(settings, 'doubleValue', 1), 1.5);
    expect(settingDoubleForTest(settings, 'doubleInt', 1), 2);
    expect(settingDoubleForTest(settings, 'doubleText', 1), 3.25);
    expect(settingDoubleForTest(settings, 'badDouble', 1), 1);
  });

  test('parses workspace settings with fallback', () {
    expect(
      workspaceFromSettingForTest('library', fallback: WorkspaceForTest.search),
      WorkspaceForTest.library,
    );
    expect(
      workspaceFromSettingForTest(
        'playlistSync',
        fallback: WorkspaceForTest.search,
      ),
      WorkspaceForTest.playlistSync,
    );
    expect(
      workspaceFromSettingForTest(
        'unknown',
        fallback: WorkspaceForTest.library,
      ),
      WorkspaceForTest.library,
    );
    expect(
      workspaceFromSettingForTest('  ', fallback: WorkspaceForTest.search),
      WorkspaceForTest.search,
    );
  });

  test('validates fastlog LocalCache.saver path', () async {
    final tempDir = await Directory.systemTemp.createTemp('fastlog_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File(
      '${tempDir.path}${Platform.pathSeparator}LocalCache.saver',
    );
    await file.writeAsString('{"docs":[]}');

    expect(
      await fastLogStartupProblemForTest('  '),
      '快速输出需要先配置 LocalCache.saver 路径',
    );
    expect(
      await fastLogStartupProblemForTest(
        '${tempDir.path}${Platform.pathSeparator}missing.saver',
      ),
      startsWith('LocalCache.saver 不存在或不是文件：'),
    );
    expect(await fastLogStartupProblemForTest(file.path), isNull);
  });

  test('plans startup actions in original order', () {
    expect(startupAutoStartModeForTest(autoStart: true), 'installSelected');
    expect(startupAutoStartModeForTest(autoStart: false), 'none');
    expect(
      startupActionsForTest(
        readLocal: true,
        fastLog: true,
        autoStart: true,
        busy: false,
        hasTargetMaps: true,
      ),
      [
        StartupActionForTest.readLocal,
        StartupActionForTest.fastLog,
        StartupActionForTest.installSelected,
      ],
    );
  });

  test('skips startup actions that cannot run yet', () {
    expect(
      startupActionsForTest(
        readLocal: true,
        fastLog: true,
        autoStart: true,
        busy: true,
        hasTargetMaps: false,
      ),
      [StartupActionForTest.readLocal],
    );
    expect(
      startupActionsForTest(
        readLocal: false,
        fastLog: false,
        autoStart: true,
        busy: false,
        hasTargetMaps: false,
      ),
      isEmpty,
    );
  });

  test('retries startup minimize when first attempt is not applied', () {
    expect(
      startupMinimizeNeedsRetryForTest(isMinimizedAfterFirstAttempt: true),
      false,
    );
    expect(
      startupMinimizeNeedsRetryForTest(isMinimizedAfterFirstAttempt: false),
      true,
    );
  });

  test('formats LocalCache.saver fastlog read status', () {
    expect(
      localCacheReadStatusForTest(
        mapCount: 1,
        filteredCount: 1,
        pageNumber: 1,
        totalPages: 0,
      ),
      '本地数据缓存：读取 1 张，筛选后 1 张，第 1/1 页',
    );
    expect(
      localCacheReadLogForTest(
        mapCount: 1,
        filteredCount: 1,
        visibleCount: 1,
        bytes: 1536,
        modified: DateTime(2026, 6, 6, 19, 30, 1),
      ),
      'LocalCache.saver 读取完成：1 张，筛选后 1 张，显示 1 张，'
      '文件 1.5 KB，文件修改时间 2026-06-06 19:30:01',
    );
    expect(
      localCacheReadLogForTest(
        mapCount: 1,
        filteredCount: 1,
        visibleCount: 1,
        bytes: 1536,
        modified: DateTime(2026, 6, 6, 19, 30, 1),
        generatedAt: DateTime(2026, 6, 6, 18, 0, 0),
      ),
      'LocalCache.saver 读取完成：1 张，筛选后 1 张，显示 1 张，'
      '文件 1.5 KB，生成时间 2026-06-06 18:00:00，'
      '文件修改时间 2026-06-06 19:30:01',
    );
    expect(
      localCacheAgeLabelForTest(
        generatedAt: DateTime(2026, 6, 16, 12),
        modified: DateTime(2026, 6, 17, 12),
        now: DateTime(2026, 6, 18, 12),
      ),
      '快照 2 天前',
    );
    expect(
      localCacheIncrementalLabelForTest(
        updatedAt: DateTime(2026, 6, 18, 2),
        added: 3,
        updated: 2,
      ),
      '增量 2026-06-18 +3 / 更新 2',
    );
    expect(
      localCacheDeletedAuditExportRowsForTest(
        LocalCacheDeletedAuditResult(
          deletedMaps: const [LocalCacheDeletedMap(id: 'abc', deletedAt: null)],
          candidates: [
            LocalCacheDeletedCandidate(
              id: 'abc',
              deletedAt: DateTime.parse('2026-06-18T02:00:00Z'),
              inLocalCache: true,
            ),
          ],
          pagesFetched: 1,
          completed: false,
          paused: true,
        ),
      ),
      ['id\tdeletedAt\tinLocalCache', 'abc\t2026-06-18T02:00:00.000Z\tyes'],
    );
  });

  test('covers final LocalCache workspace checklist semantics', () {
    expect(
      localCacheReadStatusForTest(
        mapCount: 81962,
        filteredCount: 120,
        pageNumber: 1,
        totalPages: 6,
      ),
      '本地数据缓存：读取 81962 张，筛选后 120 张，第 1/6 页',
    );
    expect(
      localCacheAgeLabelForTest(
        generatedAt: DateTime(2026, 6, 18, 3),
        modified: DateTime(2026, 6, 18, 4),
        now: DateTime(2026, 6, 20, 3),
      ),
      '快照 2 天前',
    );
    expect(
      localCacheIncrementalLabelForTest(
        updatedAt: DateTime(2026, 6, 18, 3),
        added: 81,
        updated: 19,
      ),
      '增量 2026-06-18 +81 / 更新 19',
    );
    expect(
      localCacheAddStatusForTest(target: '本次', count: 4),
      '已从本地数据缓存加入本次：4 首',
    );
    expect(
      localCacheAddStatusForTest(target: '跳过', count: 3),
      '已从本地数据缓存加入跳过：3 首',
    );
    expect(
      exportFileStatusForTest(
        label: '本地数据缓存列表',
        path: 'C:/out/local_cache.txt',
      ),
      '本地数据缓存列表已导出：C:/out/local_cache.txt',
    );
    expect(
      exportFileStatusForTest(
        label: '本地数据缓存摘要',
        path: 'C:/out/local_cache_summary.txt',
      ),
      '本地数据缓存摘要已导出：C:/out/local_cache_summary.txt',
    );
    expect(
      exportFileStatusForTest(
        label: '删除候选报告',
        path: 'C:/out/local_cache_deleted_candidates.tsv',
      ),
      '删除候选报告已导出：C:/out/local_cache_deleted_candidates.tsv',
    );
    expect(
      localCacheDeletedAuditExportRowsForTest(
        LocalCacheDeletedAuditResult(
          deletedMaps: const [LocalCacheDeletedMap(id: 'abc', deletedAt: null)],
          candidates: [
            LocalCacheDeletedCandidate(
              id: 'abc',
              deletedAt: DateTime.parse('2026-06-18T02:00:00Z'),
              inLocalCache: true,
            ),
            const LocalCacheDeletedCandidate(
              id: 'def',
              deletedAt: null,
              inLocalCache: false,
            ),
          ],
          pagesFetched: 1,
          completed: true,
          paused: false,
        ),
      ),
      [
        'id\tdeletedAt\tinLocalCache',
        'abc\t2026-06-18T02:00:00.000Z\tyes',
        'def\t\tno',
      ],
    );
    expect(localCacheReadTooltip, contains('离线读取 LocalCache.saver'));
    expect(localCacheRebuildTooltip, startsWith('联网维护'));
    expect(localCacheIncrementalTooltip, startsWith('联网维护'));
    expect(localCacheDeletedAuditTooltip, contains('不会修改缓存'));
    expect(localCacheDeletedExportTooltip, contains('不修改 LocalCache.saver'));
    expect(localCacheClearTooltip, contains('不删除 LocalCache.saver'));
  });

  test('formats paged source and playlist import statuses', () {
    expect(
      resultPageStatusForTest(
        pageNumber: 2,
        returnedCount: 20,
        filteredCount: 20,
      ),
      '第 2 页：20 张谱面',
    );
    expect(
      resultPageStatusForTest(
        prefix: '谱师 mapper #123 ',
        pageNumber: 3,
        returnedCount: 20,
        filteredCount: 8,
      ),
      '谱师 mapper #123 第 3 页：返回 20 张，筛选后 8 张',
    );
    expect(
      sourcePageStatusForTest(
        sourceName: 'ScoreSaber',
        pageNumber: 1,
        visibleCount: 12,
        failed: 0,
      ),
      'ScoreSaber 第 1 页：12 张谱面',
    );
    expect(
      sourcePageStatusForTest(
        sourceName: 'BEASTSABER',
        pageNumber: 4,
        visibleCount: 9,
        failed: 2,
      ),
      'BEASTSABER 第 4 页：显示 9 张，失败 2',
    );
    expect(
      playlistImportStatusForTest(
        name: 'Favorites',
        loadedCount: 5,
        filteredCount: 5,
      ),
      '在线歌单 Favorites：已加入 5 首到本次',
    );
    expect(
      playlistImportStatusForTest(
        name: '#123',
        loadedCount: 5,
        filteredCount: 2,
      ),
      '在线歌单 #123：读取 5 首，筛选后加入 2 首',
    );
  });

  test('formats batch install and ZIP completion statuses', () {
    expect(
      batchInstallStatusForTest(
        installed: 3,
        skipped: 1,
        stopped: 2,
        failed: 4,
      ),
      '批量完成：安装 3，跳过 1，停止 2，失败 4',
    );
    expect(
      batchInstallAutoPackStatusForTest(
        installed: 3,
        skipped: 1,
        failed: 4,
        path: 'C:/out/songs.zip',
      ),
      '批量完成并已自动打包：安装 3，跳过 1，失败 4，C:/out/songs.zip',
    );
    expect(
      zipDownloadStatusForTest(
        downloaded: 5,
        skipped: 1,
        stopped: 2,
        failed: 3,
      ),
      '批量 ZIP 下载完成：下载 5，跳过 1，停止 2，失败 3',
    );
    expect(
      zipDownloadAutoExtractStatusForTest(
        downloaded: 5,
        installed: 4,
        skipped: 1,
        failed: 3,
      ),
      '批量 ZIP 下载完成并已自动解压：下载 5，安装 4，跳过 1，失败 3',
    );
  });

  test('formats save-selected action and completion statuses', () {
    expect(
      saveSelectedActionLabelForTest(saveSongList: true, saveSongFiles: true),
      '保存本次歌曲列表并下载 ZIP',
    );
    expect(
      saveSelectedActionLabelForTest(saveSongList: true, saveSongFiles: false),
      '保存本次歌曲列表',
    );
    expect(
      saveSelectedActionLabelForTest(saveSongList: false, saveSongFiles: true),
      '下载 ZIP',
    );

    expect(
      saveSelectedStatusForTest(
        listPath: 'C:/out/targets.txt',
        saveSongFiles: false,
        downloaded: 0,
        skipped: 0,
        stopped: 0,
        failed: 0,
      ),
      '保存完成：列表 C:/out/targets.txt，ZIP 未下载',
    );
    expect(
      saveSelectedStatusForTest(
        listPath: null,
        saveSongFiles: true,
        downloaded: 5,
        skipped: 1,
        stopped: 2,
        failed: 3,
      ),
      '保存完成：列表未保存，ZIP 下载 5，跳过 1，停止 2，失败 3',
    );
    expect(
      saveSelectedAutoExtractStatusForTest(
        listPath: 'C:/out/targets.txt',
        downloaded: 5,
        installed: 4,
        skipped: 1,
        failed: 3,
      ),
      '保存完成并已自动解压：列表 C:/out/targets.txt，ZIP 下载 5，'
      '安装 4，跳过 1，失败 3',
    );
  });

  test('formats success failure and imported playlist statuses', () {
    expect(
      successFailureStatusForTest(label: 'ZIP 缓存加入本次完成', success: 7, failed: 2),
      'ZIP 缓存加入本次完成：成功 7，失败 2',
    );
    expect(
      importedPlaylistInstallStatusForTest(
        title: 'My Playlist',
        installed: 4,
        skipped: 1,
        failed: 2,
      ),
      '导入“My Playlist”完成：安装 4 首，跳过 1 首，失败 2 首',
    );
    expect(
      importedPlaylistReadyStatusForTest(
        title: 'My Playlist',
        maps: 6,
        failed: 1,
      ),
      '歌单“My Playlist”读取完成：可安装 6 首，失败 1 首',
    );
    expect(
      importedPlaylistTargetsStatusForTest(
        title: 'My Playlist',
        added: 5,
        failed: 1,
      ),
      '歌单“My Playlist”已加入本次：5 首，失败 1 首',
    );
  });

  test('validates local bplist import path', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_playlist_import_test_',
    );
    try {
      expect(await playlistImportProblemForTest(' '), '请先选择歌单文件');
      final missing = '${tempDir.path}${Platform.pathSeparator}missing.bplist';
      expect(
        await playlistImportProblemForTest(missing),
        '歌单文件不存在或不是文件：$missing',
      );
      final empty = File(
        '${tempDir.path}${Platform.pathSeparator}empty.bplist',
      );
      await empty.writeAsString('{"playlistTitle":"Empty","songs":[]}');
      expect(
        await playlistImportProblemForTest(empty.path),
        '歌单文件没有可导入歌曲：${empty.path}',
      );
      final valid = File(
        '${tempDir.path}${Platform.pathSeparator}valid.bplist',
      );
      await valid.writeAsString(
        '{"playlistTitle":"Valid","songs":[{"key":"abc"}]}',
      );
      expect(await playlistImportProblemForTest(valid.path), isNull);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('formats restored target and manual input statuses', () {
    expect(restoredTargetsStatusForTest(restored: 3, failed: 0), '已恢复本次歌曲：3 首');
    expect(
      restoredTargetsStatusForTest(restored: 3, failed: 2),
      '已恢复本次歌曲：3 首，失败 2',
    );
    expect(
      manualAddResultsStatusForTest(added: 4, failed: 1),
      '已添加 4 张谱面到结果，失败 1',
    );
    expect(
      manualInstallStatusForTest(
        installed: 2,
        skipped: 1,
        stopped: 3,
        failed: 4,
      ),
      '手动安装完成：安装 2，跳过 1，停止 3，失败 4',
    );
  });

  test('formats path selection statuses', () {
    expect(pathSelectionStatusForTest(label: '安装目录', path: null), '未选择安装目录');
    expect(
      pathSelectionStatusForTest(label: '歌曲 ZIP 路径', path: 'C:/out/songs.zip'),
      '歌曲 ZIP 路径：C:/out/songs.zip',
    );
    expect(
      pathSelectionStatusForTest(label: '歌单文件', path: 'C:/in/list.bplist'),
      '歌单文件：C:/in/list.bplist',
    );
    expect(
      pathSelectionStatusForTest(label: '本地歌曲目录', path: 'D:/Beat Saber Songs'),
      '本地歌曲目录：D:/Beat Saber Songs',
    );
    expect(
      pathSelectionStatusForTest(label: '跳过已有目录', path: 'D:/Skip Songs'),
      '跳过已有目录：D:/Skip Songs',
    );
    expect(
      pathSelectionStatusForTest(label: 'ZIP 下载目录', path: 'D:/Zip Cache'),
      'ZIP 下载目录：D:/Zip Cache',
    );
    expect(
      pathSelectionStatusForTest(label: '歌单保存位置', path: null),
      '未选择歌单保存位置',
    );
    expect(
      pathSelectionStatusForTest(label: '歌单封面', path: 'C:/covers/cover.png'),
      '歌单封面：C:/covers/cover.png',
    );
    expect(
      pathSelectionStatusForTest(label: 'ZIP 保存位置', path: 'C:/out/pack.zip'),
      'ZIP 保存位置：C:/out/pack.zip',
    );
    expect(
      pathSelectionStatusForTest(label: '歌曲列表文件', path: null),
      '未选择歌曲列表文件',
    );
    expect(
      pathSelectionStatusForTest(label: '本次歌曲列表', path: null),
      '未选择本次歌曲列表',
    );
    expect(
      pathSelectionStatusForTest(label: 'LocalCache.saver', path: null),
      '未选择LocalCache.saver',
    );
    expect(
      pathSelectionStatusForTest(
        label: 'LocalCache.saver',
        path: 'C:/cache/LocalCache.saver',
      ),
      'LocalCache.saver：C:/cache/LocalCache.saver',
    );
    expect(
      pathSelectionStatusForTest(label: 'SongCore XML 路径', path: null),
      '未选择SongCore XML 路径',
    );
  });

  test('formats export file statuses', () {
    expect(exportFileStatusForTest(label: '结果列表', path: null), '未选择结果列表保存位置');
    expect(
      exportFileStatusForTest(label: 'ZIP 缓存列表', path: 'C:/out/cache.txt'),
      'ZIP 缓存列表已导出：C:/out/cache.txt',
    );
    expect(
      exportFileStatusForTest(label: '日志', path: 'C:/out/logs.txt'),
      '日志已导出：C:/out/logs.txt',
    );
    expect(
      exportFileStatusForTest(label: '本次歌曲列表', path: 'C:/out/targets.txt'),
      '本次歌曲列表已导出：C:/out/targets.txt',
    );
    expect(
      exportFileStatusForTest(label: '已安装列表', path: 'C:/out/installed.txt'),
      '已安装列表已导出：C:/out/installed.txt',
    );
    expect(
      exportFileStatusForTest(label: '封面缓存', path: 'C:/out/cover_labels.json'),
      '封面缓存已导出：C:/out/cover_labels.json',
    );
    expect(
      exportFileStatusForTest(label: 'Hash 缓存', path: 'C:/out/hash_cache.json'),
      'Hash 缓存已导出：C:/out/hash_cache.json',
    );
    expect(
      exportFileStatusForTest(
        label: '删除候选报告',
        path: 'C:/out/local_cache_deleted_candidates.tsv',
      ),
      '删除候选报告已导出：C:/out/local_cache_deleted_candidates.tsv',
    );
    expect(
      exportFileStatusForTest(label: 'LocalCache 摘要', path: null),
      '未选择LocalCache 摘要保存位置',
    );
    expect(
      favoritePlaylistExportStatusForTest(
        count: 3,
        path: 'C:/out/favorites.bplist',
      ),
      '收藏歌单已导出：C:/out/favorites.bplist，收藏歌曲 3 首',
    );
    expect(
      installedPlaylistExportStatusForTest(
        count: 12,
        skipped: 0,
        path: 'C:/out/installed.bplist',
      ),
      '已安装歌单已导出：C:/out/installed.bplist，歌曲 12 首',
    );
    expect(
      installedPlaylistExportStatusForTest(
        count: 12,
        skipped: 3,
        path: 'C:/out/installed.bplist',
      ),
      '已安装歌单已导出：C:/out/installed.bplist，歌曲 12 首，'
      '跳过 3 首无 ID 或缺 info.dat',
    );
  });

  test('covers final file picker and export status checklist text', () {
    final pickerStatuses = <String>[
      pathSelectionStatusForTest(label: '安装目录', path: null),
      pathSelectionStatusForTest(
        label: '安装目录',
        path: 'C:/Beat Saber/CustomLevels',
      ),
      pathSelectionStatusForTest(label: '本地歌曲目录', path: null),
      pathSelectionStatusForTest(label: '本地歌曲目录', path: 'D:/Beat Saber Songs'),
      pathSelectionStatusForTest(label: '游戏目录', path: null),
      pathSelectionStatusForTest(label: '游戏目录', path: 'D:/Steam/Beat Saber'),
      pathSelectionStatusForTest(label: '跳过已有目录', path: null),
      pathSelectionStatusForTest(label: '跳过已有目录', path: 'D:/Skip Songs'),
      pathSelectionStatusForTest(label: 'ZIP 下载目录', path: null),
      pathSelectionStatusForTest(label: 'ZIP 下载目录', path: 'D:/Zip Cache'),
      pathSelectionStatusForTest(label: '歌单文件', path: null),
      pathSelectionStatusForTest(label: '歌单文件', path: 'C:/in/list.bplist'),
      pathSelectionStatusForTest(label: '歌单保存位置', path: null),
      pathSelectionStatusForTest(label: '歌单保存位置', path: 'C:/out/list.bplist'),
      pathSelectionStatusForTest(label: '歌单封面', path: null),
      pathSelectionStatusForTest(label: '歌单封面', path: 'C:/covers/cover.png'),
      pathSelectionStatusForTest(label: 'ZIP 保存位置', path: null),
      pathSelectionStatusForTest(label: 'ZIP 保存位置', path: 'C:/out/pack.zip'),
      pathSelectionStatusForTest(label: '歌曲列表文件', path: null),
      pathSelectionStatusForTest(label: '歌曲列表文件', path: 'C:/in/targets.txt'),
      pathSelectionStatusForTest(label: '本次歌曲列表', path: null),
      pathSelectionStatusForTest(label: '本次歌曲列表', path: 'C:/in/current.txt'),
      pathSelectionStatusForTest(label: 'LocalCache.saver', path: null),
      pathSelectionStatusForTest(
        label: 'LocalCache.saver',
        path: 'C:/cache/LocalCache.saver',
      ),
    ];

    expect(pickerStatuses, hasLength(24));
    expect(pickerStatuses[0], '未选择安装目录');
    expect(pickerStatuses[1], '安装目录：C:/Beat Saber/CustomLevels');
    expect(pickerStatuses[2], '未选择本地歌曲目录');
    expect(pickerStatuses[3], '本地歌曲目录：D:/Beat Saber Songs');
    expect(pickerStatuses[4], '未选择游戏目录');
    expect(pickerStatuses[5], '游戏目录：D:/Steam/Beat Saber');
    expect(pickerStatuses[6], '未选择跳过已有目录');
    expect(pickerStatuses[7], '跳过已有目录：D:/Skip Songs');
    expect(pickerStatuses[8], '未选择ZIP 下载目录');
    expect(pickerStatuses[9], 'ZIP 下载目录：D:/Zip Cache');
    expect(pickerStatuses[10], '未选择歌单文件');
    expect(pickerStatuses[11], '歌单文件：C:/in/list.bplist');
    expect(pickerStatuses[12], '未选择歌单保存位置');
    expect(pickerStatuses[13], '歌单保存位置：C:/out/list.bplist');
    expect(pickerStatuses[14], '未选择歌单封面');
    expect(pickerStatuses[15], '歌单封面：C:/covers/cover.png');
    expect(pickerStatuses[16], '未选择ZIP 保存位置');
    expect(pickerStatuses[17], 'ZIP 保存位置：C:/out/pack.zip');
    expect(pickerStatuses[18], '未选择歌曲列表文件');
    expect(pickerStatuses[19], '歌曲列表文件：C:/in/targets.txt');
    expect(pickerStatuses[20], '未选择本次歌曲列表');
    expect(pickerStatuses[21], '本次歌曲列表：C:/in/current.txt');
    expect(pickerStatuses[22], '未选择LocalCache.saver');
    expect(pickerStatuses[23], 'LocalCache.saver：C:/cache/LocalCache.saver');
    expect(androidDirectoryStatusForTest(null), '未选择 Android 目录');
    expect(
      androidDirectoryStatusForTest('content://tree/primary%3AMods'),
      'Android 目录 URI：content://tree/primary%3AMods',
    );

    final exportStatuses = <String>[
      exportFileStatusForTest(label: '日志', path: 'C:/out/logs.txt'),
      exportFileStatusForTest(label: '结果列表', path: 'C:/out/results.txt'),
      exportFileStatusForTest(label: '本次歌曲列表', path: 'C:/out/targets.txt'),
      exportFileStatusForTest(label: '已安装列表', path: 'C:/out/installed.txt'),
      exportFileStatusForTest(label: 'ZIP 缓存列表', path: 'C:/out/cache.txt'),
      exportFileStatusForTest(label: '本地数据缓存列表', path: 'C:/out/cache_maps.txt'),
      exportFileStatusForTest(
        label: '本地数据缓存摘要',
        path: 'C:/out/cache_summary.txt',
      ),
      exportFileStatusForTest(label: '删除候选报告', path: null),
      favoritePlaylistExportStatusForTest(
        count: 3,
        path: 'C:/out/favorites.bplist',
      ),
      installedPlaylistExportStatusForTest(
        count: 99,
        skipped: 3,
        path: 'C:/out/installed.bplist',
      ),
      copiedPathStatusForTest(
        label: 'SongCore folders.xml 路径',
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
      ),
      copiedPathStatusForTest(
        label: 'SongCore 备份目录',
        path: 'C:/Beat Saber/UserData/SongCore/backups',
      ),
    ];

    expect(exportStatuses, hasLength(12));
    expect(exportStatuses[0], '日志已导出：C:/out/logs.txt');
    expect(exportStatuses[1], '结果列表已导出：C:/out/results.txt');
    expect(exportStatuses[2], '本次歌曲列表已导出：C:/out/targets.txt');
    expect(exportStatuses[3], '已安装列表已导出：C:/out/installed.txt');
    expect(exportStatuses[4], 'ZIP 缓存列表已导出：C:/out/cache.txt');
    expect(exportStatuses[5], '本地数据缓存列表已导出：C:/out/cache_maps.txt');
    expect(exportStatuses[6], '本地数据缓存摘要已导出：C:/out/cache_summary.txt');
    expect(exportStatuses[7], '未选择删除候选报告保存位置');
    expect(exportStatuses[8], '收藏歌单已导出：C:/out/favorites.bplist，收藏歌曲 3 首');
    expect(
      exportStatuses[9],
      '已安装歌单已导出：C:/out/installed.bplist，歌曲 99 首，'
      '跳过 3 首无 ID 或缺 info.dat',
    );
    expect(
      exportStatuses[10],
      'SongCore folders.xml 路径已复制：C:/Beat Saber/UserData/SongCore/folders.xml',
    );
    expect(
      exportStatuses[11],
      'SongCore 备份目录已复制：C:/Beat Saber/UserData/SongCore/backups',
    );
  });

  test('formats count and file read statuses', () {
    expect(songCountStatusForTest(label: '已加入跳过歌曲', count: 3), '已加入跳过歌曲：3 首');
    expect(androidDirectoryStatusForTest(null), '未选择 Android 目录');
    expect(
      androidDirectoryStatusForTest('content://tree/primary%3AMods'),
      'Android 目录 URI：content://tree/primary%3AMods',
    );
    expect(
      readFileStatusForTest(label: '歌曲列表', path: 'C:/in/maps.txt'),
      '已读取歌曲列表：C:/in/maps.txt',
    );
  });

  test('formats saved file profile and preset statuses', () {
    expect(
      savedFileStatusForTest(label: '配置', path: 'C:/cfg/settings.json'),
      '配置已保存：C:/cfg/settings.json',
    );
    expect(
      profileDeleteStatusForTest(removed: true, profileName: 'Smoke'),
      '配置已删除：Smoke',
    );
    expect(
      profileDeleteStatusForTest(removed: false, profileName: 'Smoke'),
      '未找到配置：Smoke',
    );
    expect(
      profileDeleteConfirmTextForTest('Smoke'),
      allOf(
        contains('将删除已保存配置：Smoke'),
        contains('不会删除歌曲、ZIP、歌单或 LocalCache.saver'),
      ),
    );
    expect(
      cacheFileClearConfirmTextForTest(
        label: 'BeatSaver hash',
        path: 'C:/cfg/beatsaver_hash_cache.json',
        preserved: 'LocalCache.saver、歌曲、ZIP 或歌单',
      ),
      allOf(
        contains('将清空本地BeatSaver hash缓存'),
        contains('C:/cfg/beatsaver_hash_cache.json'),
        contains('不会删除LocalCache.saver、歌曲、ZIP 或歌单'),
      ),
    );
    expect(presetAppliedStatusForTest('ACG 白名单预设'), '已应用 ACG 白名单预设');
  });

  test('formats completed file and local scan statuses', () {
    expect(
      completedFileStatusForTest(
        label: 'ZIP',
        separator: ' ',
        path: 'C:/out/a.zip',
      ),
      'ZIP 已下载：C:/out/a.zip',
    );
    expect(
      completedFileStatusForTest(
        label: '歌单',
        action: '已导出',
        path: 'C:/out/list.bplist',
      ),
      '歌单已导出：C:/out/list.bplist',
    );
    expect(
      completedFileStatusForTest(
        label: '歌曲 ZIP',
        action: '已打包',
        separator: ' ',
        path: 'C:/out/songs.zip',
      ),
      '歌曲 ZIP 已打包：C:/out/songs.zip',
    );
    expect(
      localScanStatusForTest(installedCount: 12, zipCacheCount: 3),
      '已安装歌曲：12 首，ZIP 缓存 3 个',
    );
    expect(
      localScanLogForTest(installedCount: 12, zipCacheCount: 3),
      '扫描完成：12 首，ZIP 缓存 3 个',
    );
    expect(
      deleteInstalledStatusForTest(id: 'abc', deletedTitle: null),
      '未找到 id 为 abc 的已安装歌曲',
    );
    expect(
      deleteInstalledStatusForTest(id: 'abc', deletedTitle: 'Song Name'),
      '已删除 Song Name',
    );
    expect(
      installedPathCorrectionStatusForTest(
        oldName: 'Wrong',
        newName: 'abc - Song',
        path: 'C:/Beat Saber/CustomLevels/abc - Song',
      ),
      '路径纠错完成：Wrong -> abc - Song，C:/Beat Saber/CustomLevels/abc - Song',
    );
    expect(
      installedPathCorrectionBatchStatusForTest(
        requested: 3,
        renamed: 2,
        failed: 1,
      ),
      '批量路径纠错完成：请求 3，重命名 2，失败 1',
    );
    expect(
      installedPathCorrectionBatchStatusForTest(
        requested: 3,
        renamed: 2,
        failed: 1,
        failureSourcePath: 'C:/Beat Saber/CustomLevels/Wrong',
        failureExpectedDirectoryName: 'abc - Song',
        failureReason: 'Target directory already exists',
      ),
      '批量路径纠错完成：请求 3，重命名 2，失败 1，'
      '失败示例：C:/Beat Saber/CustomLevels/Wrong -> abc - Song'
      '（Target directory already exists）',
    );
    expect(
      installedDuplicateDeleteStatusForTest(
        requested: 3,
        deleted: 2,
        backups: 2,
      ),
      '重复歌曲备份删除完成：请求 3，删除 2，备份 2',
    );
    expect(
      installedDuplicateDeleteStatusForTest(
        requested: 3,
        deleted: 2,
        backups: 2,
        backupDirectory: 'C:/Beat Saber/CustomLevels_backup/duplicates',
      ),
      '重复歌曲备份删除完成：请求 3，删除 2，备份 2，'
      '备份目录：C:/Beat Saber/CustomLevels_backup/duplicates',
    );
    expect(
      installedDuplicateDeleteStatusForTest(
        requested: 3,
        deleted: 2,
        backups: 2,
        skippedMissing: 1,
      ),
      '重复歌曲备份删除完成：请求 3，删除 2，备份 2，'
      '跳过 1 个已不存在目录',
    );
    expect(
      installedDuplicateDeleteStatusForTest(
        requested: 3,
        deleted: 2,
        backups: 2,
        skippedMissing: 1,
        backupDirectory: 'C:/Beat Saber/CustomLevels_backup/duplicates',
      ),
      '重复歌曲备份删除完成：请求 3，删除 2，备份 2，'
      '跳过 1 个已不存在目录，'
      '备份目录：C:/Beat Saber/CustomLevels_backup/duplicates',
    );
    expect(addedTargetStatusForTest('Song Name'), '已加入本次：Song Name');
  });

  test('formats destructive local management confirmation text', () {
    expect(
      installedPathCorrectionConfirmTextForTest(
        oldName: 'Wrong',
        newName: 'abc - Song',
      ),
      contains('如果目标目录已存在，会自动停止'),
    );
    expect(
      installedPathCorrectionBatchConfirmTextForTest(
        count: 7,
        preview: 'A -> B\nC -> D',
        hiddenCount: 2,
      ),
      allOf(contains('将批量重命名 7 个本地歌曲目录'), contains('还有 2 条未显示')),
    );
    expect(
      installedPathCorrectionBatchConfirmTextForTest(
        count: 2,
        preview: 'A -> B',
        hiddenCount: 0,
        templateDifferenceOnly: true,
      ),
      allOf(contains('当前命名模板与现有目录名不同'), contains('不代表目录损坏')),
    );
    expect(
      installedDuplicateDeleteConfirmTextForTest(
        count: 6,
        preview: 'dup\nC:/songs/dup',
        hiddenCount: 1,
      ),
      allOf(
        contains('将备份并删除 6 个本地歌曲目录'),
        contains('*_backup\\duplicates'),
        contains('删除前不会改写歌单'),
      ),
    );
    expect(
      installedSingleDeleteConfirmTextForTest(
        title: 'Song Name',
        path: 'C:/Beat Saber/CustomLevels/abc - Song',
      ),
      allOf(
        contains('将直接删除这个本地歌曲目录'),
        contains('不会创建备份'),
        contains('不会修改任何歌单文件'),
      ),
    );
    expect(
      playlistSyncDeleteConfirmTextForTest(count: 3),
      allOf(
        contains('backup 文件夹'),
        contains('备份当前歌单文件和 3 个本地歌曲目录'),
        contains('也会删除本地歌曲目录'),
        contains('此操作会修改歌单文件'),
      ),
    );
    expect(
      playlistSyncPlaylistRemoveConfirmTextForTest(count: 3),
      allOf(
        contains('backup 文件夹'),
        contains('仅从歌单 songs 中移除 3 个条目'),
        contains('不会删除或移动任何本地歌曲目录'),
        contains('此操作会修改歌单文件'),
      ),
    );
    expect(
      songCoreFolderRemoveConfirmTextForTest(
        name: 'Pack A',
        path: 'C:/Songs/Pack A',
      ),
      allOf(contains('从 SongCore 保存列表移除'), contains('不会删除本地歌曲目录')),
    );
  });

  test('covers final destructive confirmation checklist text', () {
    final checklistConfirmations = <String>[
      installedSingleDeleteConfirmTextForTest(
        title: 'Song Name',
        path: 'C:/Beat Saber/CustomLevels/abc - Song',
      ),
      installedDuplicateDeleteConfirmTextForTest(
        count: 2,
        preview: 'C:/songs/dup-a\nC:/songs/dup-b',
        hiddenCount: 0,
      ),
      installedPathCorrectionConfirmTextForTest(
        oldName: 'Wrong',
        newName: 'abc - Song',
      ),
      installedPathCorrectionBatchConfirmTextForTest(
        count: 2,
        preview: 'Wrong -> abc - Song\nOld -> def - Song',
        hiddenCount: 0,
      ),
      playlistSyncPlaylistRemoveConfirmTextForTest(count: 2),
      playlistSyncDeleteConfirmTextForTest(count: 2),
      songCoreFolderRemoveConfirmTextForTest(
        name: 'Pack A',
        path: 'C:/Songs/Pack A',
      ),
      profileDeleteConfirmTextForTest('Smoke'),
      cacheFileClearConfirmTextForTest(
        label: '封面标签',
        path: 'C:/cfg/cover_label_cache.json',
        preserved: '歌曲、ZIP、歌单或 LocalCache.saver',
      ),
      cacheFileClearConfirmTextForTest(
        label: 'BeatSaver hash',
        path: 'C:/cfg/beatsaver_hash_cache.json',
        preserved: 'LocalCache.saver、歌曲、ZIP 或歌单',
      ),
    ];

    expect(checklistConfirmations, hasLength(10));
    expect(checklistConfirmations[0], contains('将直接删除这个本地歌曲目录'));
    expect(checklistConfirmations[0], contains('不会创建备份'));
    expect(checklistConfirmations[1], contains('将备份并删除 2 个本地歌曲目录'));
    expect(checklistConfirmations[1], contains('*_backup\\duplicates'));
    expect(checklistConfirmations[2], contains('如果目标目录已存在，会自动停止'));
    expect(checklistConfirmations[3], contains('将批量重命名 2 个本地歌曲目录'));
    expect(checklistConfirmations[4], contains('仅从歌单 songs 中移除 2 个条目'));
    expect(checklistConfirmations[4], contains('不会删除或移动任何本地歌曲目录'));
    expect(checklistConfirmations[5], contains('备份当前歌单文件和 2 个本地歌曲目录'));
    expect(checklistConfirmations[5], contains('也会删除本地歌曲目录'));
    expect(checklistConfirmations[6], contains('从 SongCore 保存列表移除'));
    expect(checklistConfirmations[6], contains('只会修改 folders.xml'));
    expect(checklistConfirmations[7], contains('将删除已保存配置：Smoke'));
    expect(
      checklistConfirmations[7],
      contains('不会删除歌曲、ZIP、歌单或 LocalCache.saver'),
    );
    expect(checklistConfirmations[8], contains('将清空本地封面标签缓存'));
    expect(
      checklistConfirmations[8],
      contains('不会删除歌曲、ZIP、歌单或 LocalCache.saver'),
    );
    expect(checklistConfirmations[9], contains('将清空本地BeatSaver hash缓存'));
    expect(
      checklistConfirmations[9],
      contains('不会删除LocalCache.saver、歌曲、ZIP 或歌单'),
    );
  });

  test('formats empty cleared and local cache statuses', () {
    expect(logOutputStatusForTest(paused: true), '日志输出已暂停');
    expect(logOutputStatusForTest(paused: false), '日志输出已恢复');
    expect(errorStatusForTest('network failed'), '错误：network failed');
    expect(clearedStatusForTest('队列'), '队列已清空');
    expect(clearedStatusForTest('完成/跳过的队列项', prefix: true), '已清空完成/跳过的队列项');
    expect(clearedStatusForTest('已读本地数据缓存'), '已读本地数据缓存已清空');
    expect(emptyExportStatusForTest('日志'), '当前没有日志可导出');
    expect(
      requireActionStatusForTest('读取 LocalCache.saver'),
      '请先读取 LocalCache.saver',
    );
    expect(emptyFilteredLocalCacheStatusForTest(), '当前本地数据缓存筛选结果为空');
    expect(
      missingLocalCacheForIncrementalUpdateStatusForTest(),
      '请先选择、读取或重建 LocalCache.saver 后再执行增量更新',
    );
    expect(
      localCacheAddStatusForTest(target: '本次', count: 4),
      '已从本地数据缓存加入本次：4 首',
    );
    expect(
      localCacheAddStatusForTest(target: '跳过', count: 3),
      '已从本地数据缓存加入跳过：3 首',
    );
    expect(zipCacheCountStatusForTest(12), 'ZIP 缓存：12 个');
  });

  test('formats remaining validation and config statuses', () {
    expect(
      configFileProblemStatusForTest(ConfigFileProblemForTest.missing),
      '配置文件不存在',
    );
    expect(
      configFileProblemStatusForTest(ConfigFileProblemForTest.invalid),
      '配置文件格式无效',
    );
    expect(emptyActionStatusForTest('可删除的配置'), '当前没有可删除的配置');
    expect(outputModeDisabledStatusForTest(), '保存方式未启用歌曲列表或下载歌曲');
    expect(autoExitReadyStatusForTest(), '任务完成，准备自动退出...');
    expect(configLoadedStatusForTest(), '配置已读取');
    expect(
      missingBeatSaverIdStatusForTest(action: '删除'),
      '无法删除：缺少 BeatSaver id',
    );
    expect(noRetryFailedStatusForTest(), '没有失败项可重试');
    expect(
      requireActionStatusForTest('输入 BeatSaver ID 或链接'),
      '请先输入 BeatSaver ID 或链接',
    );
  });

  test('auto-inspects configured SongCore game directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_songcore_auto_test_',
    );
    try {
      final gameDirectory = Directory('${root.path}/Beat Saber')
        ..createSync(recursive: true);
      File('${gameDirectory.path}/Beat Saber.exe').createSync();
      Directory('${gameDirectory.path}/Beat Saber_Data').createSync();
      Directory('${gameDirectory.path}/Plugins').createSync();
      File('${gameDirectory.path}/Plugins/SongCore.dll').createSync();
      File('${gameDirectory.path}/Plugins/PlaylistManager.dll').createSync();
      Directory(
        '${gameDirectory.path}/UserData/SongCore',
      ).createSync(recursive: true);
      File(
        '${gameDirectory.path}/UserData/SongCore/folders.xml',
      ).writeAsStringSync(
        '<folders><folder><Name>External</Name>'
        '<Path>${root.path}/External</Path><Pack>2</Pack></folder></folders>',
      );

      final emptyResult = await autoInspectConfiguredGameDirectoryForTest(' ');
      expect(emptyResult, isNull);

      final result = await autoInspectConfiguredGameDirectoryForTest(
        gameDirectory.path,
      );

      expect(result, isNotNull);
      expect(result!.status.isBeatSaberDirectory, isTrue);
      expect(result.status.isSongCoreInstalled, isTrue);
      expect(result.status.isPlaylistManagerInstalled, isTrue);
      expect(result.entries, hasLength(1));
      expect(result.entries.single.name, 'External');
      expect(result.statusText, contains('游戏目录有效'));
      expect(result.statusText, contains('SongCore 已安装'));
      expect(result.statusText, contains('PlaylistManager 已安装'));
      expect(result.backupDirectory, contains('backups'));
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });

  test('formats selected target title and primary action state', () {
    expect(selectedTargetsTitleForTest(0), '本次歌曲：未选择');
    expect(selectedTargetsTitleForTest(-1), '本次歌曲：未选择');
    expect(selectedTargetsTitleForTest(3), '本次歌曲：3 首');

    expect(
      selectedTargetsPrimaryButtonLabelForTest(
        busy: false,
        stopRequested: false,
      ),
      '开始',
    );
    expect(
      selectedTargetsPrimaryButtonLabelForTest(
        busy: true,
        stopRequested: false,
      ),
      '停止',
    );
    expect(
      selectedTargetsPrimaryButtonLabelForTest(busy: true, stopRequested: true),
      '停止已请求',
    );
    expect(
      selectedTargetsStartEnabledForTest(
        selectedCount: 1,
        busy: false,
        stopRequested: false,
      ),
      isTrue,
    );
    expect(
      selectedTargetsStartEnabledForTest(
        selectedCount: 0,
        busy: false,
        stopRequested: false,
      ),
      isFalse,
    );
    expect(
      selectedTargetsStopEnabledForTest(busy: true, stopRequested: false),
      isTrue,
    );
    expect(
      selectedTargetsStopEnabledForTest(busy: true, stopRequested: true),
      isFalse,
    );
    expect(
      selectedResultsActionEnabledForTest(selectedCount: 2, busy: false),
      isTrue,
    );
    expect(
      selectedResultsActionEnabledForTest(selectedCount: 0, busy: false),
      isFalse,
    );
    expect(
      selectedResultsActionEnabledForTest(selectedCount: 2, busy: true),
      isFalse,
    );
  });

  test('enables ZIP cache bulk actions only when inputs are available', () {
    expect(zipCacheExportEnabledForTest(entryCount: 2, busy: false), isTrue);
    expect(zipCacheExportEnabledForTest(entryCount: 0, busy: false), isFalse);
    expect(zipCacheExportEnabledForTest(entryCount: 2, busy: true), isFalse);

    expect(
      zipCacheRecognizedActionEnabledForTest(recognizedCount: 2, busy: false),
      isTrue,
    );
    expect(
      zipCacheRecognizedActionEnabledForTest(recognizedCount: 0, busy: false),
      isFalse,
    );
    expect(
      zipCacheRecognizedActionEnabledForTest(recognizedCount: 2, busy: true),
      isFalse,
    );
  });

  test('enables cover label cache actions only when cache is available', () {
    expect(
      coverLabelCacheActionEnabledForTest(entries: 1, busy: false),
      isTrue,
    );
    expect(
      coverLabelCacheActionEnabledForTest(entries: 0, busy: false),
      isFalse,
    );
    expect(
      coverLabelCacheActionEnabledForTest(entries: 1, busy: true),
      isFalse,
    );
  });

  test('enables installed library actions only for valid local state', () {
    expect(
      installedFilteredIdActionEnabledForTest(entryCount: 1, busy: false),
      isTrue,
    );
    expect(
      installedFilteredIdActionEnabledForTest(entryCount: 0, busy: false),
      isFalse,
    );
    expect(
      installedFilteredIdActionEnabledForTest(entryCount: 1, busy: true),
      isFalse,
    );
    expect(
      installedExportCurrentEnabledForTest(filteredCount: 1, busy: false),
      isTrue,
    );
    expect(
      installedExportCurrentEnabledForTest(filteredCount: 0, busy: false),
      isFalse,
    );
    expect(
      installedExportPlaylistEnabledForTest(exportableCount: 1, busy: false),
      isTrue,
    );
    expect(
      installedExportPlaylistEnabledForTest(exportableCount: 0, busy: false),
      isFalse,
    );
    expect(installedFavoritesExportEnabledForTest(busy: false), isTrue);
    expect(installedFavoritesExportEnabledForTest(busy: true), isFalse);
    expect(gameDirectoryInspectEnabledForTest(busy: false), isTrue);
    expect(gameDirectoryInspectEnabledForTest(busy: true), isFalse);
    expect(gameDirectoryInspectDisabledReasonForTest(busy: false), isEmpty);
    expect(
      gameDirectoryInspectDisabledReasonForTest(busy: true),
      '正在执行任务，暂不能检测游戏目录',
    );
    expect(
      songCoreFolderSaveEnabledForTest(
        busy: false,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: true,
      ),
      isTrue,
    );
    expect(
      songCoreFolderSaveEnabledForTest(
        busy: false,
        isBeatSaberDirectory: false,
        isSongCoreInstalled: true,
      ),
      isFalse,
    );
    expect(
      songCoreFolderSaveEnabledForTest(
        busy: false,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: false,
      ),
      isFalse,
    );
    expect(
      songCoreFolderSaveEnabledForTest(
        busy: true,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: true,
      ),
      isFalse,
    );
    expect(
      songCoreFolderReadEnabledForTest(
        busy: false,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: true,
      ),
      isTrue,
    );
    expect(
      songCoreFolderReadEnabledForTest(
        busy: false,
        isBeatSaberDirectory: false,
        isSongCoreInstalled: true,
      ),
      isFalse,
    );
    expect(
      songCoreFolderReadEnabledForTest(
        busy: false,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: false,
      ),
      isFalse,
    );
    expect(
      songCoreFolderReadEnabledForTest(
        busy: true,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: true,
      ),
      isFalse,
    );
    expect(songCoreFolderRemoveEnabledForTest(busy: false), isTrue);
    expect(songCoreFolderRemoveEnabledForTest(busy: true), isFalse);
    expect(
      gameDirectoryStatusLabelForTest(isBeatSaberDirectory: true),
      '游戏目录有效',
    );
    expect(
      gameDirectoryStatusLabelForTest(isBeatSaberDirectory: false),
      '游戏目录无效',
    );
    var chipState = gameDirectoryChipStateForTest(
      isBeatSaberDirectory: true,
      path: 'C:/Beat Saber',
    );
    expect(chipState.label, '游戏目录有效');
    expect(chipState.tooltip, '有效游戏目录：C:/Beat Saber');
    chipState = gameDirectoryChipStateForTest(
      isBeatSaberDirectory: false,
      path: 'C:/Beat Saber',
    );
    expect(chipState.label, '游戏目录无效');
    expect(chipState.tooltip, '无效游戏目录：C:/Beat Saber');
    expect(
      songCoreFolderDisabledReasonForTest(
        busy: true,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: true,
      ),
      '正在执行任务，暂不能操作 SongCore 保存列表',
    );
    expect(
      songCoreFolderDisabledReasonForTest(
        busy: false,
        isBeatSaberDirectory: false,
        isSongCoreInstalled: false,
      ),
      '请先检测并确认有效的 Beat Saber 游戏目录',
    );
    expect(
      songCoreFolderDisabledReasonForTest(
        busy: false,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: false,
      ),
      '需要安装 SongCore 后才能读取或保存 SongCore 列表',
    );
    expect(
      songCoreFolderDisabledReasonForTest(
        busy: false,
        isBeatSaberDirectory: true,
        isSongCoreInstalled: true,
      ),
      isEmpty,
    );
    var songCoreAction = songCoreFolderActionStateForTest(
      busy: false,
      isBeatSaberDirectory: true,
      isSongCoreInstalled: true,
    );
    expect(songCoreAction.enabled, isTrue);
    expect(songCoreAction.disabledReason, isEmpty);
    songCoreAction = songCoreFolderActionStateForTest(
      busy: true,
      isBeatSaberDirectory: true,
      isSongCoreInstalled: true,
    );
    expect(songCoreAction.enabled, isFalse);
    expect(songCoreAction.disabledReason, '正在执行任务，暂不能操作 SongCore 保存列表');
    songCoreAction = songCoreFolderActionStateForTest(
      busy: false,
      isBeatSaberDirectory: false,
      isSongCoreInstalled: false,
    );
    expect(songCoreAction.enabled, isFalse);
    expect(songCoreAction.disabledReason, '请先检测并确认有效的 Beat Saber 游戏目录');
    songCoreAction = songCoreFolderActionStateForTest(
      busy: false,
      isBeatSaberDirectory: true,
      isSongCoreInstalled: false,
    );
    expect(songCoreAction.enabled, isFalse);
    expect(songCoreAction.disabledReason, '需要安装 SongCore 后才能读取或保存 SongCore 列表');
    expect(
      gameDirectoryInspectStatusForTest(
        isBeatSaberDirectory: true,
        songCoreInstalled: true,
        playlistManagerInstalled: false,
        path: 'C:/Beat Saber',
      ),
      '游戏目录有效：C:/Beat Saber，SongCore 已安装，PlaylistManager 未安装',
    );
    expect(
      gameDirectoryInspectStatusForTest(
        isBeatSaberDirectory: false,
        songCoreInstalled: false,
        playlistManagerInstalled: true,
        path: 'C:/Wrong Folder',
      ),
      '游戏目录无效：C:/Wrong Folder，SongCore 未安装，PlaylistManager 已安装',
    );
    expect(
      songCoreInstallTooltipForTest(
        installed: false,
        path: 'C:/Beat Saber/Plugins/SongCore.dll',
      ),
      '未找到 SongCore：C:/Beat Saber/Plugins/SongCore.dll',
    );
    expect(
      songCoreInstallTooltipForTest(
        installed: true,
        path: 'C:/Beat Saber/Plugins/SongCore.dll',
      ),
      '已找到 SongCore：C:/Beat Saber/Plugins/SongCore.dll',
    );
    expect(songCoreInstallLabelForTest(installed: false), 'SongCore 未安装');
    expect(songCoreInstallLabelForTest(installed: true), 'SongCore 已安装');
    chipState = songCoreInstallChipStateForTest(
      installed: false,
      path: 'C:/Beat Saber/Plugins/SongCore.dll',
    );
    expect(chipState.label, 'SongCore 未安装');
    expect(
      chipState.tooltip,
      '未找到 SongCore：C:/Beat Saber/Plugins/SongCore.dll',
    );
    chipState = songCoreInstallChipStateForTest(
      installed: true,
      path: 'C:/Beat Saber/Plugins/SongCore.dll',
    );
    expect(chipState.label, 'SongCore 已安装');
    expect(
      chipState.tooltip,
      '已找到 SongCore：C:/Beat Saber/Plugins/SongCore.dll',
    );
    expect(
      playlistManagerInstallTooltipForTest(
        installed: false,
        path: 'C:/Beat Saber/Plugins/PlaylistManager.dll',
      ),
      '未找到 PlaylistManager：C:/Beat Saber/Plugins/PlaylistManager.dll',
    );
    expect(
      playlistManagerInstallLabelForTest(installed: false),
      'PlaylistManager 未安装',
    );
    expect(
      playlistManagerInstallLabelForTest(installed: true),
      'PlaylistManager 已安装',
    );
    chipState = playlistManagerInstallChipStateForTest(
      installed: false,
      path: 'C:/Beat Saber/Plugins/PlaylistManager.dll',
    );
    expect(chipState.label, 'PlaylistManager 未安装');
    expect(
      chipState.tooltip,
      '未找到 PlaylistManager：C:/Beat Saber/Plugins/PlaylistManager.dll',
    );
    chipState = playlistManagerInstallChipStateForTest(
      installed: true,
      path: 'C:/Beat Saber/Plugins/PlaylistManager.dll',
    );
    expect(chipState.label, 'PlaylistManager 已安装');
    expect(
      chipState.tooltip,
      '已找到 PlaylistManager：C:/Beat Saber/Plugins/PlaylistManager.dll',
    );
    expect(
      songCoreFolderSaveStatusForTest(
        added: true,
        updated: false,
        validSongs: 12,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
      ),
      'SongCore 保存列表已新增：有效歌曲 12，C:/Beat Saber/UserData/SongCore/folders.xml，'
      '无原文件备份',
    );
    expect(
      songCoreFolderReadStatusForTest(
        count: 2,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
      ),
      'SongCore 保存列表已读取：2 项，C:/Beat Saber/UserData/SongCore/folders.xml',
    );
    expect(
      songCoreFolderReadStatusForTest(
        count: 2,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
        backupDirectory: 'C:/Beat Saber/UserData/SongCore/backups',
      ),
      'SongCore 保存列表已读取：2 项，'
      'C:/Beat Saber/UserData/SongCore/folders.xml，'
      '备份目录：C:/Beat Saber/UserData/SongCore/backups',
    );
    expect(
      songCoreFolderSaveStatusForTest(
        added: false,
        updated: true,
        validSongs: 12,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
        songFolderPath: 'D:/Beat Saber Songs/Favorites',
        backupPath: 'C:/Beat Saber/UserData/SongCore/backups/backup.xml',
        backupDirectory: 'C:/Beat Saber/UserData/SongCore/backups',
      ),
      'SongCore 保存列表已更新：有效歌曲 12，'
      'C:/Beat Saber/UserData/SongCore/folders.xml，'
      '曲包：D:/Beat Saber Songs/Favorites，'
      '备份：C:/Beat Saber/UserData/SongCore/backups/backup.xml，'
      '备份目录：C:/Beat Saber/UserData/SongCore/backups',
    );
    expect(
      songCoreFolderSaveStatusForTest(
        added: false,
        updated: false,
        validSongs: 12,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
        songFolderPath: 'D:/Beat Saber Songs/Favorites',
      ),
      'SongCore 保存列表已保持：有效歌曲 12，'
      'C:/Beat Saber/UserData/SongCore/folders.xml，'
      '曲包：D:/Beat Saber Songs/Favorites，'
      '未改写，无需备份',
    );
    expect(
      songCoreFolderRemoveStatusForTest(
        removed: 1,
        remaining: 3,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
        removedEntryPath: 'D:/Beat Saber Songs/Favorites',
        backupPath: 'C:/Beat Saber/UserData/SongCore/backups/backup.xml',
        backupDirectory: 'C:/Beat Saber/UserData/SongCore/backups',
      ),
      'SongCore 保存列表已移除：1 项，剩余 3 项，'
      'C:/Beat Saber/UserData/SongCore/folders.xml，'
      '移除条目：D:/Beat Saber Songs/Favorites，'
      '备份：C:/Beat Saber/UserData/SongCore/backups/backup.xml，'
      '备份目录：C:/Beat Saber/UserData/SongCore/backups',
    );
    expect(
      songCoreFolderRemoveStatusForTest(
        removed: 0,
        remaining: 3,
        path: 'C:/Beat Saber/UserData/SongCore/folders.xml',
        removedEntryPath: 'D:/Beat Saber Songs/Missing',
      ),
      'SongCore 保存列表未找到匹配条目：剩余 3 项，'
      'C:/Beat Saber/UserData/SongCore/folders.xml，'
      '移除条目：D:/Beat Saber Songs/Missing，'
      '未改写，无需备份',
    );
    expect(songCoreFolderListScrollHintForTest(count: 8), '列表可滚动查看全部 8 项。');
    expect(
      copiedPathStatusForTest(
        label: 'SongCore 备份目录',
        path: 'C:/Beat Saber/UserData/SongCore/backups',
      ),
      'SongCore 备份目录已复制：C:/Beat Saber/UserData/SongCore/backups',
    );
    expect(
      songCoreBackupDirectoryForTest(
        foldersFilePath: r'C:\Beat Saber\UserData\SongCore\folders.xml',
      ),
      r'C:\Beat Saber\UserData\SongCore\backups',
    );
    expect(
      songCoreBackupDirectoryForTest(
        foldersFilePath: 'C:/Beat Saber/UserData/SongCore/folders.xml',
      ),
      'C:/Beat Saber/UserData/SongCore/backups',
    );
    expect(
      songCoreBackupDirectoryForTest(foldersFilePath: 'folders.xml'),
      'backups',
    );
    expect(
      installedVisibleSelectionEnabledForTest(visibleCount: 1, busy: false),
      isTrue,
    );
    expect(
      installedVisibleSelectionEnabledForTest(visibleCount: 0, busy: false),
      isFalse,
    );
    expect(
      installedSelectionActionEnabledForTest(selectedCount: 1, busy: false),
      isTrue,
    );
    expect(
      installedSelectionActionEnabledForTest(selectedCount: 0, busy: false),
      isFalse,
    );
    expect(
      installedSelectionActionEnabledForTest(selectedCount: 1, busy: true),
      isFalse,
    );
    expect(
      installedSelectionSummaryForTest(
        label: '',
        selectedCount: 3,
        validCount: 3,
      ),
      '已选 3 条',
    );
    expect(
      installedSelectionSummaryForTest(
        label: '重复',
        selectedCount: 4,
        validCount: 2,
      ),
      '重复已选 2 条，已失效 2 条',
    );
    expect(
      installedAdviceScrollHintForTest(label: '重复候选', count: 8),
      '重复候选可滚动查看全部 8 项。',
    );
    expect(
      installedAdviceScrollHintForTest(label: '路径建议', count: 12),
      '路径建议可滚动查看全部 12 项。',
    );
    expect(
      installedPathCorrectionFilterModeLabelForTest(
        InstalledPathCorrectionFilterMode.abnormal,
      ),
      '异常优先',
    );
    expect(
      installedPathCorrectionFilterModeLabelForTest(
        InstalledPathCorrectionFilterMode.template,
      ),
      '命名模板差异',
    );
    expect(
      installedPathCorrectionFilterModeLabelForTest(
        InstalledPathCorrectionFilterMode.all,
      ),
      '全部',
    );
  });

  test('covers final local library workspace checklist semantics', () {
    final normal = InstalledSongEntry(
      directory: Directory('installed/abc - Old Song'),
      directoryName: 'abc - Old Song',
      hasInfoDat: true,
      info: const InstalledSongInfo(
        songName: 'Song',
        songSubName: '',
        songAuthorName: 'Artist',
        levelAuthorName: 'Mapper',
        beatsPerMinute: 120,
      ),
      mapId: 'abc',
      title: 'Song',
    );
    final duplicate = InstalledSongEntry(
      directory: Directory('installed/ABC - Duplicate Song'),
      directoryName: 'ABC - Duplicate Song',
      hasInfoDat: true,
      info: const InstalledSongInfo(
        songName: 'Song',
        songSubName: '',
        songAuthorName: 'Artist',
        levelAuthorName: 'Mapper',
        beatsPerMinute: 120,
      ),
      mapId: 'ABC',
      title: 'Song',
    );
    final missingInfoWithAudio = InstalledSongEntry(
      directory: Directory('installed/broken-audio'),
      directoryName: 'broken-audio',
      hasInfoDat: false,
      hasAudioFile: true,
      mapId: 'def',
      title: 'Broken Audio',
    );
    final missingId = InstalledSongEntry(
      directory: Directory('installed/no-id'),
      directoryName: 'no-id',
      hasInfoDat: true,
      info: const InstalledSongInfo(
        songName: 'No ID',
        songSubName: '',
        songAuthorName: 'Artist',
        levelAuthorName: 'Mapper',
        beatsPerMinute: 128,
      ),
      title: 'No ID',
    );
    final entries = [normal, duplicate, missingInfoWithAudio, missingId];
    final snapshots = entries.map(installedEntrySnapshotForTest).toList();

    final summary = installedSummaryForTest(
      snapshots,
      filteredCount: snapshots.length,
    );
    expect(summary.totalLabel, '总数 4');
    expect(summary.filteredLabel, '当前 4');
    expect(summary.normalLabel, '正常 3');
    expect(summary.missingInfoLabel, '缺少 info.dat 1');
    expect(summary.missingInfoWithAudioLabel, '缺 info 但有音频 1');
    expect(summary.missingIdLabel, '无法识别 ID 1');
    expect(
      installedExportListForTest(snapshots),
      allOf(
        contains('abc\tSong\tArtist\tMapper\t正常\tabc - Old Song'),
        contains('def\tBroken Audio\t\t\t缺少 info.dat，有音频\tbroken-audio'),
        contains('\tNo ID\tArtist\tMapper\t正常\tno-id'),
      ),
    );
    expect(
      installedPlaylistExportStatusForTest(
        count: 2,
        skipped: 2,
        path: 'C:/out/current.bplist',
      ),
      '已安装歌单已导出：C:/out/current.bplist，歌曲 2 首，跳过 2 首无 ID 或缺 info.dat',
    );

    final duplicateGroups = findInstalledDuplicateGroups(entries);
    expect(duplicateGroups, hasLength(1));
    expect(duplicateGroups.single.kind, InstalledDuplicateKind.mapId);
    expect(duplicateGroups.single.entries, hasLength(2));
    final duplicateCandidates = installedDuplicateRemovalCandidates(
      duplicateGroups,
    );
    expect(duplicateCandidates.map((entry) => entry.directoryName), [
      'abc - Old Song',
    ]);
    expect(
      installedDuplicateDeleteStatusForTest(
        requested: 2,
        deleted: 1,
        backups: 1,
        skippedMissing: 1,
        backupDirectory: r'C:\CustomLevels_backup\duplicates',
      ),
      r'重复歌曲备份删除完成：请求 2，删除 1，备份 1，跳过 1 个已不存在目录，备份目录：C:\CustomLevels_backup\duplicates',
    );

    final corrections = suggestInstalledPathCorrections(entries);
    expect(corrections, hasLength(4));
    expect(
      filterInstalledPathCorrectionsForTest(
        corrections,
        InstalledPathCorrectionFilterMode.abnormal,
      ).map((correction) => correction.entry.directoryName),
      ['broken-audio', 'no-id'],
    );
    expect(
      filterInstalledPathCorrectionsForTest(
        corrections,
        InstalledPathCorrectionFilterMode.template,
      ).map((correction) => correction.entry.directoryName),
      ['abc - Old Song', 'ABC - Duplicate Song'],
    );
    expect(
      installedPathCorrectionBatchConfirmTextForTest(
        count: 2,
        preview: 'abc - Old Song -> abc - Song',
        hiddenCount: 0,
        templateDifferenceOnly: true,
      ),
      contains('不代表目录损坏'),
    );
    expect(
      installedAdviceScrollHintForTest(label: '路径建议', count: 12),
      '路径建议可滚动查看全部 12 项。',
    );
    expect(
      installedSelectionSummaryForTest(
        label: '路径建议',
        selectedCount: 3,
        validCount: 2,
      ),
      '路径建议已选 2 条，已失效 1 条',
    );
  });

  test(
    'enables playlist sync actions only for filtered and selected entries',
    () {
      expect(
        playlistSyncExportEnabledForTest(filteredCount: 1, busy: false),
        isTrue,
      );
      expect(
        playlistSyncExportEnabledForTest(filteredCount: 0, busy: false),
        isFalse,
      );
      expect(
        playlistSyncExportEnabledForTest(filteredCount: 1, busy: true),
        isFalse,
      );
      expect(
        playlistSyncSelectEnabledForTest(deletableCount: 1, busy: false),
        isTrue,
      );
      expect(
        playlistSyncSelectEnabledForTest(deletableCount: 0, busy: false),
        isFalse,
      );
      expect(
        playlistSyncClearSelectionEnabledForTest(selectedCount: 1, busy: false),
        isTrue,
      );
      expect(
        playlistSyncClearSelectionEnabledForTest(selectedCount: 0, busy: false),
        isFalse,
      );
      expect(
        playlistSyncDeleteEnabledForTest(selectedCount: 1, busy: false),
        isTrue,
      );
      expect(
        playlistSyncDeleteEnabledForTest(selectedCount: 0, busy: false),
        isFalse,
      );
      expect(
        playlistSyncDeleteEnabledForTest(selectedCount: 1, busy: true),
        isFalse,
      );
      expect(
        playlistSyncPlaylistRemoveEnabledForTest(selectedCount: 1, busy: false),
        isTrue,
      );
      expect(
        playlistSyncPlaylistRemoveEnabledForTest(selectedCount: 0, busy: false),
        isFalse,
      );
      expect(
        playlistSyncInstalledDeleteEnabledForTest(
          selectedInstalledCount: 1,
          busy: false,
        ),
        isTrue,
      );
      expect(
        playlistSyncInstalledDeleteEnabledForTest(
          selectedInstalledCount: 0,
          busy: false,
        ),
        isFalse,
      );
      expect(
        playlistSyncInstalledDeleteEnabledForTest(
          selectedInstalledCount: 1,
          busy: true,
        ),
        isFalse,
      );
    },
  );

  test('matches cover labels by tags and confidence', () {
    const labels = [
      CoverLabel(description: 'Anime illustration', score: 0.91),
      CoverLabel(description: 'Video game', score: 0.72),
      CoverLabel(description: 'Vehicle', score: 0.95),
    ];

    expect(
      coverLabelsMatchForTest(
        labels,
        includeTags: {'anime', 'game'},
        excludeTags: const {},
        includeConfidence: 0.7,
        excludeConfidence: 0.7,
        includeMatchAll: true,
        excludeMatchAll: false,
      ),
      isTrue,
    );
    expect(
      coverLabelsMatchForTest(
        labels,
        includeTags: {'anime', 'game'},
        excludeTags: const {},
        includeConfidence: 0.8,
        excludeConfidence: 0.7,
        includeMatchAll: true,
        excludeMatchAll: false,
      ),
      isFalse,
    );
    expect(
      coverLabelsMatchForTest(
        labels,
        includeTags: {'anime'},
        excludeTags: {'vehicle'},
        includeConfidence: 0.7,
        excludeConfidence: 0.7,
        includeMatchAll: false,
        excludeMatchAll: false,
      ),
      isFalse,
    );
  });

  test('parses manual cover labels for failure wait fallback', () {
    final labels = manualCoverLabelsForTest('anime, game\nillustration');

    expect(labels.map((label) => label.description), [
      'anime',
      'game',
      'illustration',
    ]);
    expect(labels.every((label) => label.score == 1.0), isTrue);
    expect(manualCoverLabelsForTest(' , \n '), isEmpty);
    expect(manualCoverLabelsForTest(null), isEmpty);
  });

  test(
    'uses manual cover labels after GCP failure when waiting is enabled',
    () async {
      final map = _testBeatSaverMap(
        id: 'abc',
        uploader: 'mapper',
        hash: 'HASH',
        coverUrl: 'https://covers.example.invalid/abc.jpg',
      );
      final cache = <String, List<CoverLabel>>{};
      final errors = <String>[];
      var prompted = 0;
      var cacheWrites = 0;

      final filtered = await filterCoverLabelsWithFallbackForTest(
        [map],
        token: 'test-token',
        includeTags: {'anime'},
        excludeTags: const {},
        includeConfidence: 0.7,
        excludeConfidence: 0.7,
        includeMatchAll: false,
        excludeMatchAll: false,
        waitOnFailure: true,
        labelCache: cache,
        detectLabels: (coverUrl, token) async {
          throw const FormatException('vision unavailable');
        },
        promptLabels: (map) async {
          prompted += 1;
          return const [CoverLabel(description: 'Anime poster', score: 1.0)];
        },
        onCacheChanged: () async {
          cacheWrites += 1;
        },
        onError: (map, error) {
          errors.add('${map.id}: $error');
        },
      );

      expect(filtered.map((map) => map.id), ['abc']);
      expect(prompted, 1);
      expect(cacheWrites, 1);
      expect(cache.keys, ['https://covers.example.invalid/abc.jpg']);
      expect(cache.values.single.single.description, 'Anime poster');
      expect(errors.single, contains('abc'));
      expect(errors.single, contains('vision unavailable'));
    },
  );

  test(
    'skips failed cover labels without prompting when waiting is disabled',
    () async {
      final map = _testBeatSaverMap(
        id: 'abc',
        uploader: 'mapper',
        hash: 'HASH',
        coverUrl: 'https://covers.example.invalid/abc.jpg',
      );
      var prompted = 0;

      final filtered = await filterCoverLabelsWithFallbackForTest(
        [map],
        token: 'test-token',
        includeTags: {'anime'},
        excludeTags: const {},
        includeConfidence: 0.7,
        excludeConfidence: 0.7,
        includeMatchAll: false,
        excludeMatchAll: false,
        waitOnFailure: false,
        labelCache: <String, List<CoverLabel>>{},
        detectLabels: (coverUrl, token) async {
          throw const FormatException('vision unavailable');
        },
        promptLabels: (map) async {
          prompted += 1;
          return const [CoverLabel(description: 'Anime poster', score: 1.0)];
        },
      );

      expect(filtered, isEmpty);
      expect(prompted, 0);
    },
  );

  test('matches search filter fields by tokens and regex', () {
    final map = _testBeatSaverMap(
      id: 'abc',
      uploader: 'UploaderName',
      hash: 'HASH',
      name: 'Title Name',
      songName: 'Song Name',
      songAuthor: 'Song Artist',
      mapper: 'Map Author',
      description: 'Long Description',
      tags: const ['anime', 'ranked'],
    );

    expect(
      matchesFieldFilterTokensForTest(
        map,
        {'anime', 'description'},
        title: false,
        songName: false,
        songAuthor: false,
        mapper: false,
        description: false,
        tags: false,
      ),
      isTrue,
    );
    expect(
      matchesFieldFilterTokensForTest(
        map,
        {'anime'},
        title: false,
        songName: true,
        songAuthor: false,
        mapper: false,
        description: false,
        tags: false,
      ),
      isFalse,
    );
    expect(
      matchesFieldFilterRegexForTest(
        map,
        RegExp(r'uploadername', caseSensitive: false),
        title: false,
        songName: false,
        songAuthor: false,
        mapper: true,
        description: false,
        tags: false,
      ),
      isTrue,
    );
    expect(
      matchesFieldFilterRegexForTest(
        map,
        RegExp(r'long description', caseSensitive: false),
        title: true,
        songName: false,
        songAuthor: false,
        mapper: false,
        description: false,
        tags: false,
      ),
      isFalse,
    );
  });

  test('matches map tags by include exclude and untagged filters', () {
    expect(
      tagsMatchForTest(
        const ['Anime', 'Ranked'],
        untaggedOnly: false,
        includeTags: {'anime'},
        excludeTags: {'curated'},
      ),
      isTrue,
    );
    expect(
      tagsMatchForTest(
        const ['Anime'],
        untaggedOnly: false,
        includeTags: {'anime', 'ranked'},
        excludeTags: const {},
      ),
      isFalse,
    );
    expect(
      tagsMatchForTest(
        const ['Anime', 'Curated'],
        untaggedOnly: false,
        includeTags: const {},
        excludeTags: {'curated'},
      ),
      isFalse,
    );
    expect(
      tagsMatchForTest(
        const [],
        untaggedOnly: true,
        includeTags: const {},
        excludeTags: const {},
      ),
      isTrue,
    );
    expect(
      tagsMatchForTest(
        const ['Anime'],
        untaggedOnly: true,
        includeTags: const {},
        excludeTags: const {},
      ),
      isFalse,
    );
  });

  test('matches Chinese preset by CJK or pinyin-like text', () {
    expect(
      matchesChinesePresetForTest(
        _testBeatSaverMap(id: 'abc', uploader: '', hash: '', songName: '夜曲'),
      ),
      isTrue,
    );
    expect(
      matchesChinesePresetForTest(
        _testBeatSaverMap(
          id: 'abc',
          uploader: '',
          hash: '',
          songName: 'xiao ming',
        ),
      ),
      isTrue,
    );
    expect(
      matchesChinesePresetForTest(
        _testBeatSaverMap(id: 'abc', uploader: '', hash: '', songName: 'rock'),
      ),
      isFalse,
    );
  });

  test('matches required and excluded difficulty components', () {
    final chromaNe = _testDifficulty(chroma: true, ne: true);
    final cinemaMe = _testDifficulty(cinema: true, me: true);
    final plain = _testDifficulty();

    expect(diffHasComponentForTest(chromaNe, 'chroma'), isTrue);
    expect(diffHasComponentForTest(chromaNe, 'noodle-extensions'), isTrue);
    expect(diffHasComponentForTest(cinemaMe, 'mappingextensions'), isTrue);
    expect(diffHasComponentForTest(plain, 'vivify'), isFalse);
    expect(
      diffsContainAllComponentsForTest([chromaNe, cinemaMe], {'chroma', 'me'}),
      isTrue,
    );
    expect(
      diffsContainAllComponentsForTest([chromaNe], {'chroma', 'cinema'}),
      isFalse,
    );
    expect(
      diffsContainAnyComponentForTest([plain, cinemaMe], {'vivify', 'cinema'}),
      isTrue,
    );
  });

  test('matches difficulty and characteristic filters', () {
    final diffs = [
      _testDifficulty(difficulty: 'Easy'),
      _testDifficulty(difficulty: 'ExpertPlus'),
      _testDifficulty(difficulty: 'Hard', characteristic: 'OneSaber'),
      _testDifficulty(difficulty: 'Expert', characteristic: '90Degree'),
    ];

    expect(difficultyMatchesForTest(diffs[1], 'expert+'), isTrue);
    expect(
      diffsMatchDifficultiesForTest(diffs, {
        'expert+',
        'normal',
      }, matchAll: false),
      isTrue,
    );
    expect(
      diffsMatchDifficultiesForTest(diffs, {
        'expert+',
        'normal',
      }, matchAll: true),
      isFalse,
    );
    expect(diffsMatchCharacteristicsForTest(diffs, {'one saber'}), isTrue);
    expect(diffsMatchCharacteristicsForTest(diffs, {'90'}), isTrue);
    expect(diffsMatchCharacteristicsForTest(diffs, {'360'}), isFalse);
  });

  test('formats difficulty and characteristic labels', () {
    expect(difficultyLabelForTest('easy'), 'Easy');
    expect(difficultyLabelForTest('ExpertPlus'), 'Expert+');
    expect(difficultyLabelForTest('expert+'), 'Expert+');
    expect(difficultyLabelForTest(''), '未知');
    expect(difficultyLabelForTest('Custom'), 'Custom');

    expect(
      difficultyRankForTest('Easy'),
      lessThan(difficultyRankForTest('Hard')),
    );
    expect(
      difficultyRankForTest('ExpertPlus'),
      lessThan(difficultyRankForTest('Custom')),
    );

    expect(characteristicLabelForTest('Standard'), '标准');
    expect(characteristicLabelForTest('OneSaber'), '单手');
    expect(characteristicLabelForTest('NoArrows'), '无箭头');
    expect(characteristicLabelForTest('360Degree'), '360');
    expect(characteristicLabelForTest('90Degree'), '90');
    expect(characteristicLabelForTest('Lightshow'), '灯光');
    expect(characteristicLabelForTest('Lawless'), 'Lawless');
    expect(characteristicLabelForTest('CustomMode'), 'CustomMode');
  });

  test('detects all standard difficulties', () {
    final allStandard = [
      _testDifficulty(difficulty: 'Easy'),
      _testDifficulty(difficulty: 'Normal'),
      _testDifficulty(difficulty: 'Hard'),
      _testDifficulty(difficulty: 'Expert'),
      _testDifficulty(difficulty: 'ExpertPlus'),
      _testDifficulty(difficulty: 'Easy', characteristic: 'OneSaber'),
    ];

    expect(hasAllStandardDifficultiesForTest(allStandard), isTrue);
    expect(
      hasAllStandardDifficultiesForTest(
        allStandard.where((diff) => diff.difficulty != 'Normal').toList(),
      ),
      isFalse,
    );
  });

  test('parses numeric and date filters', () {
    expect(parseIntForTest(' 42 '), 42);
    expect(parseIntForTest('4.2'), isNull);
    expect(parseDoubleForTest(' 4.25 '), 4.25);
    expect(parseDoubleForTest('bad'), isNull);
    expect(parseRatioForTest('0.75'), 0.75);
    expect(parseRatioForTest('75'), 0.75);
    expect(parseRatioForTest('-10'), 0);
    expect(parseRatioForTest('120'), 1);

    expect(parseDateForTest('2026-6-7'), DateTime(2026, 6, 7));
    expect(
      parseDateForTest('1700000000'),
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
    );
    expect(parseDateForTest('2026-02-31'), isNull);
    expect(parseDateForTest('not-a-date'), isNull);
  });

  test('formats full date time values', () {
    expect(
      formatDateTimeForTest(DateTime(2026, 6, 7, 8, 9, 10)),
      '2026-06-07 08:09:10',
    );
  });

  test('limits download items without mutating unlimited inputs', () {
    final items = ['a', 'b', 'c'];

    expect(limitedItemsForTest(items, null), same(items));
    expect(limitedItemsForTest(items, 0), same(items));
    expect(limitedItemsForTest(items, -1), same(items));
    expect(limitedItemsForTest(items, 5), same(items));
    expect(limitedItemsForTest(items, 2), ['a', 'b']);
  });

  test('parses semicolon and newline separated directories', () {
    final directories = directoriesFromTextForTest(
      ' C:/Songs ;\nD:/More\r\n ; E:/Other ',
    );

    expect(directories.map((directory) => directory.path), [
      'C:/Songs',
      'D:/More',
      'E:/Other',
    ]);
    expect(directoriesFromTextForTest(' ; \n '), isEmpty);
  });

  test('exports cover label cache as JSON', () {
    final jsonText = coverLabelCacheJsonForTest({
      'https://cdn.example.test/cover.jpg': const [
        CoverLabel(description: 'Anime', score: 0.91),
        CoverLabel(description: 'Video game', score: 0.72),
      ],
    });

    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final labels =
        decoded['https://cdn.example.test/cover.jpg'] as List<dynamic>;
    expect(labels.first, {'description': 'Anime', 'score': 0.91});
    expect(labels.last, {'description': 'Video game', 'score': 0.72});
  });

  test('builds playlist cover image data URLs', () async {
    final tempDir = await Directory.systemTemp.createTemp('playlist_cover_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final jpg = File('${tempDir.path}${Platform.pathSeparator}cover.jpg');
    await jpg.writeAsBytes([1, 2, 3]);

    expect(
      await playlistImageDataUrlForTest(jpg),
      'data:image/jpeg;base64,AQID',
    );
    final bmp = File('${tempDir.path}${Platform.pathSeparator}cover.bmp');
    await bmp.writeAsBytes([
      0x42,
      0x4d,
      0x3a,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x36,
      0x00,
      0x00,
      0x00,
      0x28,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x18,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x04,
      0x00,
      0x00,
      0x00,
      0x13,
      0x0b,
      0x00,
      0x00,
      0x13,
      0x0b,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xff,
      0x00,
      0x00,
      0x00,
    ]);

    final bmpDataUrl = await playlistImageDataUrlForTest(bmp);
    expect(bmpDataUrl, startsWith('data:image/jpeg;base64,'));
    expect(bmpDataUrl, isNot(contains('Qg==')));
    expect(playlistImageMimeTypeForTest('C:/covers/cover.PNG'), 'image/png');
    expect(playlistImageMimeTypeForTest('cover.gif'), isNull);
  });

  test('parses BeatSaver map ids and links', () {
    expect(
      parseBeatSaverIdsForTest(
        'ABC https://beatsaver.com/maps/def;'
        'https://api.beatsaver.com/maps/id/12345，bad-id abc ffffffff 123456789',
      ),
      ['abc', 'def', '12345', 'ffffffff'],
    );
  });

  test('parses BeatSaver playlist ids and links', () {
    expect(parseBeatSaverPlaylistIdForTest('42'), 42);
    expect(
      parseBeatSaverPlaylistIdForTest('https://beatsaver.com/playlists/id/42'),
      42,
    );
    expect(
      parseBeatSaverPlaylistIdForTest('https://beatsaver.com/playlists/99'),
      99,
    );
    expect(parseBeatSaverPlaylistIdForTest('not-a-playlist'), isNull);
  });

  test('builds BEASTSABER page URLs', () {
    expect(
      beastSaberPageUrlForTest('https://bsaber.com/songs/top/', 1).toString(),
      'https://bsaber.com/songs/top/',
    );
    expect(
      beastSaberPageUrlForTest('https://bsaber.com/songs/top/', 3).toString(),
      'https://bsaber.com/songs/top/page/3',
    );
    expect(
      beastSaberPageUrlForTest(
        'https://bsaber.com/songs/top/page/2/',
        5,
      ).toString(),
      'https://bsaber.com/songs/top/page/5',
    );
  });

  test('parses BEASTSABER preview hashes', () {
    const hashA = 'abcdefabcdefabcdefabcdefabcdefabcdefabcd';
    const hashB = '0123456789abcdef0123456789abcdef01234567';

    expect(
      parseBeastSaberPreviewHashesForTest(
        "previewSong(this, 'https://cdn.beatsaver.com/$hashA.mp3');"
        'https://cdn.beatsaver.com/$hashB.mp3 '
        'https://cdn.beatsaver.com/$hashA.mp3 '
        'https://cdn.beatsaver.com/not-a-hash.mp3',
      ),
      [hashA.toUpperCase(), hashB.toUpperCase()],
    );
  });

  test('classifies uploader data source input', () {
    final empty = uploaderQueryForTest('  ');
    expect(empty.isEmpty, isTrue);
    expect(empty.uploaderId, isNull);

    final idQuery = uploaderQueryForTest(' 3376 ');
    expect(idQuery.input, '3376');
    expect(idQuery.uploaderId, 3376);
    expect(idQuery.name, isEmpty);

    final nameQuery = uploaderQueryForTest(' FireStrike_ ');
    expect(nameQuery.input, 'FireStrike_');
    expect(nameQuery.uploaderId, isNull);
    expect(nameQuery.name, 'FireStrike_');
  });

  test('plans completion actions after successful tasks', () {
    expect(
      completionActionsForTest(
        autoPack: true,
        autoExtract: false,
        autoExit: true,
        stopped: 0,
        failed: 0,
      ),
      [CompletionActionForTest.packZip, CompletionActionForTest.exitApp],
    );
    expect(
      completionActionsForTest(
        autoPack: false,
        autoExtract: true,
        autoExit: true,
        stopped: 0,
        failed: 0,
      ),
      [
        CompletionActionForTest.extractDownloaded,
        CompletionActionForTest.exitApp,
      ],
    );
  });

  test('skips completion actions after stopped or failed tasks', () {
    expect(
      completionActionsForTest(
        autoPack: true,
        autoExtract: true,
        autoExit: true,
        stopped: 1,
        failed: 0,
      ),
      isEmpty,
    );
    expect(
      completionActionsForTest(
        autoPack: true,
        autoExtract: true,
        autoExit: true,
        stopped: 0,
        failed: 1,
      ),
      [
        CompletionActionForTest.packZip,
        CompletionActionForTest.extractDownloaded,
      ],
    );
  });

  test('keeps only unfinished queue entries when clearing finished items', () {
    expect(
      queueIdsAfterClearingFinishedForTest(const [
        QueueEntrySnapshotForTest(
          id: 'waiting',
          status: QueueStatusForTest.waiting,
        ),
        QueueEntrySnapshotForTest(
          id: 'running',
          status: QueueStatusForTest.running,
        ),
        QueueEntrySnapshotForTest(
          id: 'completed',
          status: QueueStatusForTest.completed,
        ),
        QueueEntrySnapshotForTest(
          id: 'skipped',
          status: QueueStatusForTest.skipped,
        ),
        QueueEntrySnapshotForTest(
          id: 'failed',
          status: QueueStatusForTest.failed,
        ),
      ]),
      ['waiting', 'running', 'failed'],
    );
  });

  test('summarizes queue panel counts', () {
    final summary = queueSummaryForTest(const [
      QueueEntrySnapshotForTest(
        id: 'waiting',
        status: QueueStatusForTest.waiting,
      ),
      QueueEntrySnapshotForTest(
        id: 'running',
        status: QueueStatusForTest.running,
      ),
      QueueEntrySnapshotForTest(
        id: 'completed',
        status: QueueStatusForTest.completed,
      ),
      QueueEntrySnapshotForTest(
        id: 'skipped-a',
        status: QueueStatusForTest.skipped,
      ),
      QueueEntrySnapshotForTest(
        id: 'skipped-b',
        status: QueueStatusForTest.skipped,
      ),
      QueueEntrySnapshotForTest(
        id: 'failed',
        status: QueueStatusForTest.failed,
      ),
    ]);

    expect(summary.waiting, 1);
    expect(summary.running, 1);
    expect(summary.completed, 1);
    expect(summary.skipped, 2);
    expect(summary.failed, 1);
    expect(summary.clearable, 3);
    expect(summary.label, '等待 1，处理中 1，完成 1，跳过 2，失败 1');
  });

  test('enables queue panel actions from busy and summary state', () {
    expect(queueStopEnabledForTest(busy: true, stopRequested: false), isTrue);
    expect(queueStopEnabledForTest(busy: false, stopRequested: false), isFalse);
    expect(queueStopEnabledForTest(busy: true, stopRequested: true), isFalse);

    expect(queueRetryFailedEnabledForTest(failedCount: 1, busy: false), isTrue);
    expect(
      queueRetryFailedEnabledForTest(failedCount: 0, busy: false),
      isFalse,
    );
    expect(queueRetryFailedEnabledForTest(failedCount: 1, busy: true), isFalse);

    expect(
      queueClearFinishedEnabledForTest(clearableCount: 1, busy: false),
      isTrue,
    );
    expect(
      queueClearFinishedEnabledForTest(clearableCount: 0, busy: false),
      isFalse,
    );
    expect(
      queueClearFinishedEnabledForTest(clearableCount: 1, busy: true),
      isFalse,
    );

    expect(queueClearAllEnabledForTest(busy: false), isTrue);
    expect(queueClearAllEnabledForTest(busy: true), isFalse);
  });

  test('covers final queue and ZIP cache checklist semantics', () {
    expect(zipCacheCountStatusForTest(3), 'ZIP 缓存：3 个');
    expect(zipCacheExportEnabledForTest(entryCount: 3, busy: false), isTrue);
    expect(zipCacheExportEnabledForTest(entryCount: 0, busy: false), isFalse);
    expect(
      zipCacheRecognizedActionEnabledForTest(recognizedCount: 2, busy: false),
      isTrue,
    );
    expect(
      zipCacheRecognizedActionEnabledForTest(recognizedCount: 0, busy: false),
      isFalse,
    );
    expect(
      zipCacheRecognizedActionEnabledForTest(recognizedCount: 2, busy: true),
      isFalse,
    );
    expect(
      exportFileStatusForTest(label: 'ZIP 缓存列表', path: 'C:/out/cache.txt'),
      'ZIP 缓存列表已导出：C:/out/cache.txt',
    );
    expect(
      successFailureStatusForTest(label: 'ZIP 缓存加入本次完成', success: 2, failed: 1),
      'ZIP 缓存加入本次完成：成功 2，失败 1',
    );
    expect(
      songCountStatusForTest(label: '已从 ZIP 缓存加入跳过歌曲', count: 2),
      '已从 ZIP 缓存加入跳过歌曲：2 首',
    );

    final queue = const [
      QueueEntrySnapshotForTest(
        id: 'waiting',
        status: QueueStatusForTest.waiting,
      ),
      QueueEntrySnapshotForTest(
        id: 'running',
        status: QueueStatusForTest.running,
      ),
      QueueEntrySnapshotForTest(
        id: 'done',
        task: QueueTaskForTest.downloadZip,
        status: QueueStatusForTest.completed,
      ),
      QueueEntrySnapshotForTest(
        id: 'skipped',
        status: QueueStatusForTest.skipped,
      ),
      QueueEntrySnapshotForTest(
        id: 'failed-install',
        status: QueueStatusForTest.failed,
      ),
      QueueEntrySnapshotForTest(
        id: 'failed-resolve',
        task: QueueTaskForTest.resolveMissing,
        status: QueueStatusForTest.failed,
      ),
    ];
    final summary = queueSummaryForTest(queue);

    expect(summary.label, '等待 1，处理中 1，完成 1，跳过 1，失败 2');
    expect(queueStopEnabledForTest(busy: true, stopRequested: false), isTrue);
    expect(queueStopEnabledForTest(busy: true, stopRequested: true), isFalse);
    expect(
      queueRetryFailedEnabledForTest(failedCount: summary.failed, busy: false),
      isTrue,
    );
    expect(
      queueRetryFailedEnabledForTest(failedCount: summary.failed, busy: true),
      isFalse,
    );
    expect(
      queueClearFinishedEnabledForTest(
        clearableCount: summary.clearable,
        busy: false,
      ),
      isTrue,
    );
    expect(queueIdsAfterClearingFinishedForTest(queue), [
      'waiting',
      'running',
      'failed-install',
      'failed-resolve',
    ]);
    expect(queueClearAllEnabledForTest(busy: false), isTrue);
    expect(queueClearAllEnabledForTest(busy: true), isFalse);
    expect(retryQueueEntriesForTest(queue).map((entry) => entry.id), [
      'failed-install',
    ]);
    expect(
      queueIdsToMarkSkippedForTest(
        queueIds: queue.map((entry) => entry.id),
        requestedIds: const ['waiting', 'missing'],
      ),
      ['waiting'],
    );
    expect(clearedStatusForTest('完成/跳过的队列项', prefix: true), '已清空完成/跳过的队列项');
    expect(clearedStatusForTest('队列'), '队列已清空');
    expect(queueStopTooltip, contains('停止队列'));
    expect(queueRetryFailedTooltip, contains('重试失败项'));
    expect(queueClearFinishedTooltip, contains('清空完成项'));
    expect(queueClearAllTooltip, contains('清空队列'));
  });

  testWidgets('clicks ZIP cache panel actions and shows feedback', (
    tester,
  ) async {
    var status = 'idle';
    final now = DateTime(2026, 6, 21);
    final entries = [
      ZipCacheEntryForTest(
        name: 'abc-111.zip',
        path: 'C:/cache/abc-111.zip',
        bytes: 1024,
        modified: now,
      ),
      ZipCacheEntryForTest(
        name: 'def-222.zip',
        path: 'C:/cache/def-222.zip',
        bytes: 2048,
        modified: now,
      ),
      ZipCacheEntryForTest(
        name: 'unmatched.zip',
        path: 'C:/cache/unmatched.zip',
        bytes: 512,
        modified: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Text(status),
                    zipCachePanelForTest(
                      entries: entries,
                      onRefresh: () => setState(() => status = 'scan'),
                      onExport: (selected) async =>
                          setState(() => status = 'export:${selected.length}'),
                      onAddToTargets: (selected) async => setState(
                        () => status =
                            'targets:${selected.map((entry) => entry.mapId).join(',')}',
                      ),
                      onAddToSkip: (selected) => setState(
                        () => status =
                            'skip:${selected.map((entry) => entry.mapId).join(',')}',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('文件 3'), findsOneWidget);
    expect(find.text('可识别 2'), findsOneWidget);

    await tester.tap(find.text('扫描 ZIP'));
    await tester.pump();
    expect(find.text('scan'), findsOneWidget);

    await tester.tap(find.text('导出列表'));
    await tester.pump();
    expect(find.text('export:3'), findsOneWidget);

    await tester.tap(find.text('加入本次(2)'));
    await tester.pump();
    expect(find.text('targets:abc,def'), findsOneWidget);

    await tester.tap(find.text('加入跳过(2)'));
    await tester.pump();
    expect(find.text('skip:abc,def'), findsOneWidget);
  });

  testWidgets('clicks queue panel controls and shows feedback', (tester) async {
    var status = 'idle';
    var busy = false;
    var stopRequested = false;
    final entries = [
      const QueueEntrySnapshotForTest(
        id: 'waiting',
        title: 'Waiting Song',
        status: QueueStatusForTest.waiting,
      ),
      const QueueEntrySnapshotForTest(
        id: 'completed',
        title: 'Completed Song',
        status: QueueStatusForTest.completed,
      ),
      const QueueEntrySnapshotForTest(
        id: 'skipped',
        title: 'Skipped Song',
        status: QueueStatusForTest.skipped,
      ),
      const QueueEntrySnapshotForTest(
        id: 'failed-install',
        title: 'Failed Install',
        status: QueueStatusForTest.failed,
      ),
      const QueueEntrySnapshotForTest(
        id: 'failed-resolve',
        title: 'Failed Resolve',
        task: QueueTaskForTest.resolveMissing,
        status: QueueStatusForTest.failed,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Text(status),
                    queuePanelForTest(
                      entries: entries,
                      busy: busy,
                      stopRequested: stopRequested,
                      onStop: () => setState(() {
                        stopRequested = true;
                        status = 'stop';
                      }),
                      onRetryFailed: () => setState(() => status = 'retry'),
                      onClearFinished: () =>
                          setState(() => status = 'clear-finished'),
                      onClearQueue: () => setState(() => status = 'clear-all'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => busy = true),
                      child: const Text('set busy'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('等待 1，处理中 0，完成 1，跳过 1，失败 2'), findsOneWidget);
    expect(find.text('重试失败项(1)'), findsOneWidget);

    await tester.tap(find.text('重试失败项(1)'));
    await tester.pump();
    expect(find.text('retry'), findsOneWidget);

    await tester.tap(find.text('清空完成项'));
    await tester.pump();
    expect(find.text('clear-finished'), findsOneWidget);

    await tester.tap(find.text('清空队列'));
    await tester.pump();
    expect(find.text('clear-all'), findsOneWidget);

    await tester.tap(find.text('set busy'));
    await tester.pump();
    await tester.tap(find.text('停止队列'));
    await tester.pump();
    expect(find.text('stop'), findsOneWidget);
    expect(find.text('停止已请求'), findsOneWidget);
  });

  test('formats queue status labels and default details', () {
    expect(queueStatusLabelForTest(QueueStatusForTest.waiting), '等待');
    expect(queueStatusLabelForTest(QueueStatusForTest.running), '处理中');
    expect(queueStatusLabelForTest(QueueStatusForTest.completed), '完成');
    expect(queueStatusLabelForTest(QueueStatusForTest.skipped), '跳过');
    expect(queueStatusLabelForTest(QueueStatusForTest.failed), '失败');

    expect(queueStatusDetailForTest(QueueStatusForTest.waiting), '等待处理');
    expect(queueStatusDetailForTest(QueueStatusForTest.running), '正在处理');
    expect(queueStatusDetailForTest(QueueStatusForTest.completed), '已完成');
    expect(queueStatusDetailForTest(QueueStatusForTest.skipped), '已跳过');
    expect(queueStatusDetailForTest(QueueStatusForTest.failed), '未记录失败原因');
  });

  test('formats queue task labels', () {
    expect(queueTaskLabelForTest(QueueTaskForTest.install), '安装');
    expect(queueTaskLabelForTest(QueueTaskForTest.downloadZip), '下载 ZIP');
    expect(queueTaskLabelForTest(QueueTaskForTest.resolveMissing), '解析缺失');
    expect(
      queueEntrySubtitleForTest(
        task: QueueTaskForTest.resolveMissing,
        id: 'missing:hash:abc',
        status: QueueStatusForTest.running,
        message: '正在解析 BeatSaver ID/hash',
      ),
      '解析缺失 | missing:hash:abc\n正在解析 BeatSaver ID/hash',
    );
    expect(
      queueEntrySubtitleForTest(
        task: QueueTaskForTest.resolveMissing,
        id: 'missing:hash:def',
        status: QueueStatusForTest.running,
        message: '正在解析后安装',
      ),
      '解析缺失 | missing:hash:def\n正在解析后安装',
    );
    expect(
      queueEntrySubtitleForTest(
        task: QueueTaskForTest.resolveMissing,
        id: 'missing:key:abc',
        status: QueueStatusForTest.running,
        message: '正在解析后下载 ZIP',
      ),
      '解析缺失 | missing:key:abc\n正在解析后下载 ZIP',
    );
  });

  test('formats download mode labels', () {
    expect(downloadModeLabelForTest(DownloadModeForTest.localCache), '本地缓存优先');
    expect(downloadModeLabelForTest(DownloadModeForTest.zeyuCache), '泽宇缓存(兼容)');
    expect(downloadModeLabelForTest(DownloadModeForTest.api), 'API 请求');
  });

  test('plans page navigation actions from result source', () {
    expect(
      goToPageActionForTest(ResultSourceForTest.textSearch),
      GoToPageActionForTest.search,
    );
    expect(
      goToPageActionForTest(ResultSourceForTest.uploader),
      GoToPageActionForTest.searchUploader,
    );
    expect(
      goToPageActionForTest(ResultSourceForTest.scoreSaber),
      GoToPageActionForTest.searchScoreSaber,
    );
    expect(
      goToPageActionForTest(ResultSourceForTest.beastSaber),
      GoToPageActionForTest.searchBeastSaber,
    );
    expect(
      goToPageActionForTest(ResultSourceForTest.localCache),
      GoToPageActionForTest.showLocalCachePage,
    );
  });

  test('marks only existing queue entries skipped after stop', () {
    expect(
      queueIdsToMarkSkippedForTest(
        queueIds: ['a', 'b', 'c'],
        requestedIds: ['b', 'missing', 'c', 'b'],
      ),
      ['b', 'c'],
    );
  });

  test('plans retry entries for failed queue items only', () {
    final retryEntries = retryQueueEntriesForTest(const [
      QueueEntrySnapshotForTest(
        id: 'install-failed',
        task: QueueTaskForTest.install,
        status: QueueStatusForTest.failed,
      ),
      QueueEntrySnapshotForTest(
        id: 'zip-failed',
        task: QueueTaskForTest.downloadZip,
        status: QueueStatusForTest.failed,
      ),
      QueueEntrySnapshotForTest(
        id: 'completed',
        task: QueueTaskForTest.install,
        status: QueueStatusForTest.completed,
      ),
      QueueEntrySnapshotForTest(
        id: 'waiting',
        task: QueueTaskForTest.downloadZip,
        status: QueueStatusForTest.waiting,
      ),
      QueueEntrySnapshotForTest(
        id: 'resolve-missing-failed',
        task: QueueTaskForTest.resolveMissing,
        status: QueueStatusForTest.failed,
      ),
    ]);

    expect(retryEntries.map((entry) => entry.id), [
      'install-failed',
      'zip-failed',
    ]);
    expect(retryEntries.map((entry) => entry.task), [
      QueueTaskForTest.install,
      QueueTaskForTest.downloadZip,
    ]);
  });

  test('clamps download thread limits', () {
    expect(
      downloadThreadLimitForTest(
        multiThreadDownload: false,
        maxDownloadThreads: '8',
      ),
      1,
    );
    expect(
      downloadThreadLimitForTest(
        multiThreadDownload: true,
        maxDownloadThreads: 'bad',
      ),
      1,
    );
    expect(
      downloadThreadLimitForTest(
        multiThreadDownload: true,
        maxDownloadThreads: '0',
      ),
      1,
    );
    expect(
      downloadThreadLimitForTest(
        multiThreadDownload: true,
        maxDownloadThreads: '64',
      ),
      32,
    );
  });

  test('limits download workers to available items', () {
    expect(downloadWorkerCountForTest(itemCount: 0, threadLimit: 3), 0);
    expect(downloadWorkerCountForTest(itemCount: 2, threadLimit: 3), 2);
    expect(downloadWorkerCountForTest(itemCount: 10, threadLimit: 3), 3);
  });

  test('summarizes concurrent download task results', () {
    final summary = downloadSummaryForTest(
      results: const [
        DownloadTaskResultForTest.downloaded,
        DownloadTaskResultForTest.skipped,
        DownloadTaskResultForTest.failed,
        DownloadTaskResultForTest.downloaded,
      ],
      stopped: 2,
    );

    expect(summary.downloaded, 2);
    expect(summary.skipped, 1);
    expect(summary.failed, 1);
    expect(summary.stopped, 2);

    expect(downloadSummaryForTest(results: const [], stopped: -1).stopped, 0);
  });

  test('parses download mode settings', () {
    expect(
      downloadModeFromSettingForTest(
        'zeyu',
        fallback: DownloadModeForTest.localCache,
      ),
      DownloadModeForTest.zeyuCache,
    );
    expect(
      downloadModeFromSettingForTest(
        'api',
        fallback: DownloadModeForTest.localCache,
      ),
      DownloadModeForTest.api,
    );
    expect(
      downloadModeFromSettingForTest(
        'unknown',
        fallback: DownloadModeForTest.localCache,
      ),
      DownloadModeForTest.localCache,
    );
  });

  test('plans download source from mode and version hash', () {
    expect(
      downloadSourceForTest(
        mode: DownloadModeForTest.localCache,
        hasVersionHash: true,
      ),
      DownloadSourceForTest.localZipCache,
    );
    expect(
      downloadSourceForTest(
        mode: DownloadModeForTest.zeyuCache,
        hasVersionHash: true,
      ),
      DownloadSourceForTest.zeyuCache,
    );
    expect(
      downloadSourceForTest(
        mode: DownloadModeForTest.zeyuCache,
        hasVersionHash: false,
      ),
      DownloadSourceForTest.beatSaverApi,
    );
    expect(
      downloadSourceForTest(
        mode: DownloadModeForTest.api,
        hasVersionHash: true,
      ),
      DownloadSourceForTest.beatSaverApi,
    );
  });

  test('builds Zeyu cache ZIP URLs', () {
    final uri = zeyuCacheZipUriForTest(
      ' abcdefabcdefabcdefabcdefabcdefabcdefabcd ',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'beatsaver.wgzeyu.vip');
    expect(uri.path, '/cdn/abcdefabcdefabcdefabcdefabcdefabcdefabcd.zip');
  });

  test('parses ZIP cache map ids from cache file names', () {
    expect(zipCacheMapIdForTest('abc-123def.zip'), 'abc');
    expect(zipCacheMapIdForTest('ABCDEF12-AABBCC.zip'), 'abcdef12');
    expect(zipCacheMapIdForTest('abcdef123-aabbcc.zip'), isNull);
    expect(zipCacheMapIdForTest('abc.zip'), isNull);
    expect(zipCacheMapIdForTest('abc-not-hash.zip'), isNull);
    expect(zipCacheMapIdForTest('abc-123def.bplist'), isNull);
  });

  test('scans ZIP cache files from a directory', () async {
    final tempDir = await Directory.systemTemp.createTemp('zip_cache_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await File(
      '${tempDir.path}${Platform.pathSeparator}b-222.zip',
    ).writeAsString('zip-b');
    await File(
      '${tempDir.path}${Platform.pathSeparator}a-111.ZIP',
    ).writeAsString('zip-a');
    await File(
      '${tempDir.path}${Platform.pathSeparator}ignore.txt',
    ).writeAsString('nope');
    await Directory(
      '${tempDir.path}${Platform.pathSeparator}folder.zip',
    ).create();

    final entries = await scanZipCacheForTest(tempDir);

    expect(entries.map((entry) => entry.name), ['a-111.ZIP', 'b-222.zip']);
    expect(entries.map((entry) => entry.mapId), ['a', 'b']);
    expect(entries.every((entry) => entry.bytes > 0), isTrue);
  });

  test('collects identifiable ZIP cache map ids', () {
    final now = DateTime(2026, 6, 6);

    expect(
      zipCacheMapIdsForTest([
        ZipCacheEntryForTest(
          name: 'ABC-111.zip',
          path: 'ABC-111.zip',
          bytes: 1,
          modified: now,
        ),
        ZipCacheEntryForTest(
          name: 'abc-222.ZIP',
          path: 'abc-222.ZIP',
          bytes: 1,
          modified: now,
        ),
        ZipCacheEntryForTest(
          name: 'def-333.zip',
          path: 'def-333.zip',
          bytes: 1,
          modified: now,
        ),
        ZipCacheEntryForTest(
          name: 'not-a-cache.zip',
          path: 'not-a-cache.zip',
          bytes: 1,
          modified: now,
        ),
      ]),
      ['abc', 'def'],
    );
  });

  test('summarizes ZIP cache files', () {
    final now = DateTime(2026, 6, 6);
    final summary = zipCacheSummaryForTest([
      ZipCacheEntryForTest(
        name: 'abc-111.zip',
        path: 'abc-111.zip',
        bytes: 1024,
        modified: now,
      ),
      ZipCacheEntryForTest(
        name: 'def-222.ZIP',
        path: 'def-222.ZIP',
        bytes: 512,
        modified: now,
      ),
      ZipCacheEntryForTest(
        name: 'not-a-cache.zip',
        path: 'not-a-cache.zip',
        bytes: 128,
        modified: now,
      ),
    ]);

    expect(summary.files, 3);
    expect(summary.recognized, 2);
    expect(summary.bytes, 1664);
    expect(summary.filesLabel, '文件 3');
    expect(summary.recognizedLabel, '可识别 2');
    expect(summary.sizeLabel, '大小 1.6 KB');
  });

  test('merges ZIP cache ids into skip ids', () {
    final now = DateTime(2026, 6, 6);
    final zipIds = zipCacheMapIdsForTest([
      ZipCacheEntryForTest(
        name: 'ABC-111.zip',
        path: 'ABC-111.zip',
        bytes: 1,
        modified: now,
      ),
      ZipCacheEntryForTest(
        name: 'def-222.zip',
        path: 'def-222.zip',
        bytes: 1,
        modified: now,
      ),
    ]);

    expect(
      mergedSkipIdsForTest(
        existingIds: const [' Def ', '12345', '', 'ABC'],
        newIds: zipIds,
      ),
      ['12345', 'abc', 'def'],
    );
  });

  test('calculates LocalCache.saver pagination', () {
    expect(localCacheTotalPagesForTest(itemCount: 0, pageSize: 20), 0);
    expect(localCacheTotalPagesForTest(itemCount: 1, pageSize: 20), 1);
    expect(localCacheTotalPagesForTest(itemCount: 40, pageSize: 20), 2);
    expect(localCacheTotalPagesForTest(itemCount: 41, pageSize: 20), 3);
    expect(localCacheTotalPagesForTest(itemCount: 41, pageSize: 0), 0);

    final items = [0, 1, 2, 3, 4];
    expect(pagedLocalCacheItemsForTest(items, page: 0, pageSize: 2), [0, 1]);
    expect(pagedLocalCacheItemsForTest(items, page: 2, pageSize: 2), [4]);
    expect(pagedLocalCacheItemsForTest(items, page: 3, pageSize: 2), isEmpty);
    expect(pagedLocalCacheItemsForTest(items, page: -1, pageSize: 2), isEmpty);
    expect(pagedLocalCacheItemsForTest(items, page: 3, pageSize: 0), items);
  });

  test('merges LocalCache.saver skip ids', () {
    expect(
      localCacheSkipIdsForTest(
        existingIds: ['ABC', '  ', 'def'],
        filteredIds: ['abc', '123', 'DEF', '456'],
      ),
      ['123', '456', 'abc', 'def'],
    );
  });

  test('summarizes LocalCache.saver filtered maps', () {
    final maps = [
      _testBeatSaverMap(id: 'a', uploader: 'mapper', hash: 'HASH-A'),
      _testBeatSaverMap(id: 'b', uploader: 'mapper', hash: ''),
      _testBeatSaverMap(id: 'c', uploader: 'other', hash: 'HASH-C'),
      _testBeatSaverMap(id: 'd', uploader: '', hash: 'HASH-D'),
    ];

    final summary = localCacheSummaryForTest(totalMaps: 10, filteredMaps: maps);

    expect(summary.totalMaps, 10);
    expect(summary.filteredMaps, 4);
    expect(summary.uploaders, 2);
    expect(summary.withHash, 3);
  });

  test('builds LocalCache.saver hash index for playlist imports', () {
    final first = _testBeatSaverMap(
      id: 'first',
      uploader: 'mapper',
      hash: 'HASH-A',
    );
    final duplicate = _testBeatSaverMap(
      id: 'duplicate',
      uploader: 'mapper',
      hash: 'hash-a',
    );
    final second = _testBeatSaverMap(
      id: 'second',
      uploader: 'mapper',
      hash: 'HASH-B',
    );
    final withoutHash = _testBeatSaverMap(
      id: 'empty',
      uploader: 'mapper',
      hash: '',
    );

    final index = localCacheHashIndexForTest([
      first,
      duplicate,
      second,
      withoutHash,
    ]);

    expect(index.keys, ['hash-a', 'hash-b']);
    expect(index['hash-a'], same(first));
    expect(index['hash-b'], same(second));
  });

  test('matches LocalCache.saver filter cache by source and signature', () {
    final source = <int>[1, 2, 3];
    final sameValues = <int>[1, 2, 3];

    expect(
      localCacheFilterCacheHitForTest(
        source: source,
        cachedSource: source,
        signature: 'a',
        cachedSignature: 'a',
      ),
      isTrue,
    );
    expect(
      localCacheFilterCacheHitForTest(
        source: source,
        cachedSource: sameValues,
        signature: 'a',
        cachedSignature: 'a',
      ),
      isFalse,
    );
    expect(
      localCacheFilterCacheHitForTest(
        source: source,
        cachedSource: source,
        signature: 'a',
        cachedSignature: 'b',
      ),
      isFalse,
    );
  });

  test('uses LocalCache index search only for simple keyword queries', () {
    bool canUse({
      String query = 'song',
      bool regexSearchMode = false,
      String uploader = '',
      String filterText = '',
      bool filterRegexMode = false,
      String includeTags = '',
      String excludeTags = '',
      String requiredComponents = '',
      String excludedComponents = '',
      String difficultyFilter = '',
      String characteristicFilter = '',
      bool hasNumericOrDateFilters = false,
      bool hasSwitchFilters = false,
    }) {
      return canUseLocalCacheIndexSearchForTest(
        query: query,
        regexSearchMode: regexSearchMode,
        uploader: uploader,
        filterText: filterText,
        filterRegexMode: filterRegexMode,
        includeTags: includeTags,
        excludeTags: excludeTags,
        requiredComponents: requiredComponents,
        excludedComponents: excludedComponents,
        difficultyFilter: difficultyFilter,
        characteristicFilter: characteristicFilter,
        hasNumericOrDateFilters: hasNumericOrDateFilters,
        hasSwitchFilters: hasSwitchFilters,
      );
    }

    expect(canUse(), isTrue);
    expect(canUse(query: ' '), isFalse);
    expect(canUse(regexSearchMode: true), isFalse);
    expect(canUse(uploader: 'mapper'), isFalse);
    expect(canUse(filterText: 'title'), isFalse);
    expect(canUse(includeTags: 'anime'), isFalse);
    expect(canUse(hasNumericOrDateFilters: true), isFalse);
    expect(canUse(hasSwitchFilters: true), isFalse);
  });

  test('selects playlist hash lookup source by cache priority', () {
    final memoryMap = _testBeatSaverMap(
      id: 'memory',
      uploader: 'mapper',
      hash: 'MEMORY',
    );
    final indexedMap = _testBeatSaverMap(
      id: 'indexed',
      uploader: 'mapper',
      hash: 'INDEXED',
    );
    final index = LocalCacheIndex.fromMaps(
      sourceFile: File('LocalCache.saver'),
      sourceStat: FileStat.statSync(Platform.resolvedExecutable),
      maps: [indexedMap],
    );
    final hashCache = BeatSaverHashCache.empty().put(
      'HASHCACHE',
      const BeatSaverHashDetail(id: 'cached', name: 'Cached', description: ''),
    );

    expect(
      playlistHashLookupSourceForTest(
        hash: 'hashcache',
        hashCache: hashCache,
        localCacheHashIndex: {'hashcache': memoryMap},
        localCacheIndex: index,
      ),
      'hash-cache',
    );
    expect(
      playlistHashLookupSourceForTest(
        hash: 'memory',
        hashCache: BeatSaverHashCache.empty(),
        localCacheHashIndex: {'memory': memoryMap},
        localCacheIndex: index,
      ),
      'local-cache-memory',
    );
    expect(
      playlistHashLookupSourceForTest(
        hash: 'indexed',
        hashCache: BeatSaverHashCache.empty(),
        localCacheHashIndex: const {},
        localCacheIndex: index,
      ),
      'local-cache-index',
    );
    expect(
      playlistHashLookupSourceForTest(
        hash: 'missing',
        hashCache: BeatSaverHashCache.empty(),
        localCacheHashIndex: const {},
        localCacheIndex: index,
      ),
      'beatsaver-api',
    );
  });

  test('exports LocalCache.saver list rows', () {
    final maps = [
      _testBeatSaverMap(
        id: 'abc',
        uploader: 'mapper',
        hash: 'HASH',
        songName: 'Song\nName',
      ),
      _testBeatSaverMap(id: 'def', uploader: 'mapper', hash: ''),
    ];

    expect(
      localCacheExportLineForTest(maps.first),
      'abc\tSong Name\thttps://beatsaver.com/maps/abc',
    );
    expect(
      mapExportLineForTest(maps.first),
      'abc\tSong Name\thttps://beatsaver.com/maps/abc',
    );
    expect(mapExportListForTest(maps).split('\n'), [
      'abc\tSong Name\thttps://beatsaver.com/maps/abc',
      'def\tdef\thttps://beatsaver.com/maps/def',
    ]);
  });

  test('exports target list rows', () {
    final maps = [
      _testBeatSaverMap(
        id: 'abc',
        uploader: 'mapper',
        hash: 'HASH',
        songName: 'Song\tName',
      ),
      _testBeatSaverMap(
        id: 'def',
        uploader: 'mapper',
        hash: '',
        songName: 'Line\r\nBreak',
      ),
    ];

    expect(targetExportLineForTest(maps.first), 'abc\tSong Name');
    expect(targetExportListForTest(maps).split('\n'), [
      'abc\tSong Name',
      'def\tLine Break',
    ]);
  });

  test('exports ZIP cache list rows', () {
    final entries = [
      ZipCacheEntryForTest(
        name: 'abc-111.zip',
        path: 'C:/cache/abc-111.zip',
        bytes: 123,
        modified: DateTime(2026, 6, 6, 12, 30),
      ),
      ZipCacheEntryForTest(
        name: 'bad\tname.zip',
        path: 'C:/cache/bad\r\nname.zip',
        bytes: 456,
        modified: DateTime(2026, 6, 7),
      ),
    ];

    expect(
      zipCacheExportLineForTest(entries.first),
      'abc-111.zip\t123\t2026-06-06\tC:/cache/abc-111.zip',
    );
    expect(zipCacheExportListForTest(entries).split('\n'), [
      'abc-111.zip\t123\t2026-06-06\tC:/cache/abc-111.zip',
      'bad name.zip\t456\t2026-06-07\tC:/cache/bad name.zip',
    ]);
  });

  test('exports installed song list rows', () {
    final entries = [
      const InstalledEntrySnapshotForTest(
        mapId: 'abc',
        title: 'Song\nName',
        songAuthor: 'Artist',
        levelAuthor: 'Mapper',
        hasInfoDat: true,
        directoryName: 'abc - Song',
        path: 'C:/songs/abc - Song',
      ),
      const InstalledEntrySnapshotForTest(
        mapId: '',
        title: '',
        songAuthor: 'A\tB',
        levelAuthor: 'C\r\nD',
        hasInfoDat: false,
        hasAudioFile: true,
        directoryName: 'broken',
        path: 'C:/songs/broken',
      ),
    ];

    expect(
      installedExportLineForTest(entries.first),
      'abc\tSong Name\tArtist\tMapper\t正常\tabc - Song\tC:/songs/abc - Song',
    );
    expect(installedExportListForTest(entries).split('\n'), [
      'abc\tSong Name\tArtist\tMapper\t正常\tabc - Song\tC:/songs/abc - Song',
      '\t\tA B\tC D\t缺少 info.dat，有音频\tbroken\tC:/songs/broken',
    ]);
    expect(installedEntryStatusLabelForTest(entries.last), '缺少 info.dat，有音频');
  });

  test('summarizes installed song panel counts', () {
    final summary = installedSummaryForTest(const [
      InstalledEntrySnapshotForTest(
        mapId: 'abc',
        title: 'Song',
        songAuthor: 'Artist',
        levelAuthor: 'Mapper',
        hasInfoDat: true,
        directoryName: 'abc - Song',
        path: 'C:/songs/abc - Song',
      ),
      InstalledEntrySnapshotForTest(
        mapId: '',
        title: '',
        songAuthor: '',
        levelAuthor: '',
        hasInfoDat: false,
        hasAudioFile: true,
        directoryName: 'broken',
        path: 'C:/songs/broken',
      ),
    ], filteredCount: 1);

    expect(summary.total, 2);
    expect(summary.filtered, 1);
    expect(summary.normal, 1);
    expect(summary.missingInfo, 1);
    expect(summary.missingInfoWithAudio, 1);
    expect(summary.missingId, 1);
    expect(summary.totalLabel, '总数 2');
    expect(summary.filteredLabel, '当前 1');
    expect(summary.normalLabel, '正常 1');
    expect(summary.missingInfoLabel, '缺少 info.dat 1');
    expect(summary.missingInfoWithAudioLabel, '缺 info 但有音频 1');
    expect(summary.missingIdLabel, '无法识别 ID 1');

    final emptySummary = installedSummaryForTest(const [], filteredCount: -1);
    expect(emptySummary.filtered, 0);
  });

  test('formats installed filter mode labels', () {
    expect(
      installedFilterModeLabelForTest(InstalledFilterModeForTest.all),
      '全部',
    );
    expect(
      installedFilterModeLabelForTest(InstalledFilterModeForTest.normal),
      '正常',
    );
    expect(
      installedFilterModeLabelForTest(InstalledFilterModeForTest.missingInfo),
      '缺少 info.dat',
    );
    expect(
      installedFilterModeLabelForTest(InstalledFilterModeForTest.missingId),
      '无法识别 ID',
    );
  });

  test('builds installed library management suggestions', () {
    final entries = [
      InstalledSongEntry(
        directory: Directory('installed/abc - A'),
        directoryName: 'abc - A',
        hasInfoDat: true,
        info: const InstalledSongInfo(
          songName: 'Song A',
          songSubName: '',
          songAuthorName: 'Artist',
          levelAuthorName: 'Mapper',
          beatsPerMinute: 180,
        ),
        mapId: 'abc',
        title: 'Song A',
      ),
      InstalledSongEntry(
        directory: Directory('installed/ABC - B'),
        directoryName: 'ABC - B',
        hasInfoDat: true,
        info: const InstalledSongInfo(
          songName: 'Song B',
          songSubName: '',
          songAuthorName: 'Artist',
          levelAuthorName: 'Mapper',
          beatsPerMinute: 180,
        ),
        mapId: 'ABC',
        title: 'Song B',
      ),
    ];

    final duplicates = findInstalledDuplicateGroups(entries);
    final corrections = suggestInstalledPathCorrections(entries);

    expect(duplicates.single.kind, InstalledDuplicateKind.mapId);
    expect(duplicates.single.value, 'abc');
    expect(corrections.first.expectedDirectoryName, 'abc - Song A');
    expect(
      installedPathCorrectionKeyForTest(corrections.first),
      'installed/abc - a\nabc - song a',
    );
    expect(
      installedDuplicateEntryKeyForTest(duplicates.single.entries.last),
      'installed/abc - b',
    );

    final mixedCorrections = suggestInstalledPathCorrections([
      entries.first,
      InstalledSongEntry(
        directory: Directory('installed/no-info'),
        directoryName: 'no-info',
        hasInfoDat: false,
        mapId: 'def',
        title: 'No Info',
      ),
      InstalledSongEntry(
        directory: Directory('installed/no-id'),
        directoryName: 'no-id',
        hasInfoDat: true,
        info: const InstalledSongInfo(
          songName: 'No ID',
          songSubName: '',
          songAuthorName: 'Artist',
          levelAuthorName: 'Mapper',
          beatsPerMinute: 120,
        ),
        title: 'No ID',
      ),
    ]);

    expect(
      filterInstalledPathCorrectionsForTest(
        mixedCorrections,
        InstalledPathCorrectionFilterMode.abnormal,
      ).map((correction) => correction.entry.directoryName),
      ['no-info', 'no-id'],
    );
    expect(
      filterInstalledPathCorrectionsForTest(
        mixedCorrections,
        InstalledPathCorrectionFilterMode.template,
      ).map((correction) => correction.entry.directoryName),
      ['abc - A'],
    );
    expect(
      filterInstalledPathCorrectionsForTest(
        mixedCorrections,
        InstalledPathCorrectionFilterMode.all,
      ),
      hasLength(3),
    );
  });

  testWidgets('shows search and installed panels', (tester) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());
    final theme = Theme.of(tester.element(find.byType(Scaffold)));

    expect(find.text('Beat Saber Song Toolkit v0.1.0'), findsOneWidget);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Microsoft YaHei');
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, contains('SimSun'));
    expect(theme.inputDecorationTheme.isDense, isTrue);
    expect(
      theme.inputDecorationTheme.contentPadding,
      const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    );
    expect(find.byTooltip('捐助作者'), findsOneWidget);
    expect(find.text('捐助作者'), findsOneWidget);
    expect(find.byTooltip('帮助'), findsOneWidget);
    const updateTooltip = '联网检查更新：请求已配置的 release API，不会自动下载或替换程序。';
    expect(find.byTooltip(updateTooltip), findsOneWidget);
    expect(
      tester.getTopLeft(find.byTooltip('帮助')).dx,
      greaterThan(tester.getTopLeft(find.byTooltip('捐助作者')).dx),
    );
    expect(
      tester.getTopLeft(find.byTooltip('帮助')).dx,
      lessThan(tester.getTopLeft(find.byTooltip(updateTooltip)).dx),
    );
    expect(find.text('BeatSaver 搜索'), findsOneWidget);
    expect(find.text('本次歌曲：未选择'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
    expect(find.byTooltip(selectedTargetsStartTooltip), findsOneWidget);
    expect(find.byTooltip(selectedTargetsImportTooltip), findsOneWidget);
    expect(find.byTooltip(selectedTargetsExportTooltip), findsOneWidget);
    expect(find.byTooltip(selectedTargetsClearTooltip), findsOneWidget);
    expect(find.text('找歌下载'), findsOneWidget);
    expect(find.text('本地曲库'), findsOneWidget);
    expect(find.text('歌单同步'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('找歌下载')).dy,
      lessThan(tester.getTopLeft(find.text('Beat Saber Song Toolkit 主面板')).dy),
    );
    expect(find.text('已安装'), findsNothing);
    expect(find.text('扫描歌单同步'), findsNothing);
    expect(find.text('搜索'), findsWidgets);
    expect(
      find.byTooltip('联网搜索：请求 BeatSaver 文本搜索接口，并按当前筛选条件显示结果。'),
      findsOneWidget,
    );
    expect(find.text('ScoreSaber'), findsOneWidget);
    expect(find.text('路径与保存方式'), findsOneWidget);
    expect(find.text('导出歌单'), findsNothing);
    expect(find.text('高级筛选'), findsOneWidget);
    expect(find.text('搜索过滤'), findsOneWidget);

    await tester.ensureVisible(find.text('本地曲库'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地曲库'));
    await tester.pumpAndSettle();
    expect(find.text('共享路径配置'), findsNothing);
    expect(find.text('高级筛选'), findsNothing);
    expect(find.text('ScoreSaber'), findsNothing);
    expect(find.text('SaverAPI'), findsNothing);
    expect(find.text('歌单封面'), findsNothing);
    expect(find.text('保存配置'), findsNothing);
    expect(find.text('下载方式'), findsNothing);
    expect(find.text('完成后'), findsNothing);
    expect(find.text('更新API'), findsNothing);
    expect(find.text('已安装'), findsOneWidget);
    expect(find.text('过滤已安装'), findsOneWidget);
    expect(find.text('状态'), findsOneWidget);
    expect(find.text('总数 0'), findsOneWidget);
    expect(find.text('当前 0'), findsOneWidget);
    expect(find.text('正常 0'), findsOneWidget);
    expect(find.text('当前加入本次(0)'), findsOneWidget);
    expect(find.text('当前加入跳过(0)'), findsOneWidget);
    expect(
      find.byTooltip(installedAddFilteredToTargetsTooltip),
      findsOneWidget,
    );
    expect(find.byTooltip(installedAddFilteredToSkipTooltip), findsOneWidget);
    expect(find.text('扫描目录后会在这里显示已安装歌曲。'), findsOneWidget);
    expect(find.text('导出歌单(0)'), findsOneWidget);
    expect(find.text('导出收藏'), findsOneWidget);
    expect(find.byTooltip(installedExportCurrentTooltip), findsOneWidget);
    expect(find.byTooltip(installedExportPlaylistTooltip), findsOneWidget);
    expect(find.byTooltip(installedExportFavoritesTooltip), findsOneWidget);
    expect(find.text('本地曲库管理'), findsNothing);
    expect(find.text('扫描 ZIP'), findsWidgets);
    expect(find.text('扫描曲库'), findsOneWidget);
    expect(find.byTooltip('扫描安装目录，刷新本地曲库歌曲列表。'), findsOneWidget);
    expect(find.text('游戏目录'), findsWidgets);
    expect(find.text('检测游戏目录'), findsOneWidget);
    expect(find.text('读取列表(0)'), findsOneWidget);
    expect(find.text('保存列表'), findsOneWidget);
    expect(find.text('复制XML路径'), findsOneWidget);
    expect(find.text('复制备份目录'), findsOneWidget);
    expect(find.byTooltip(gameDirectoryInspectTooltip), findsOneWidget);
    expect(find.byTooltip(songCoreCopyXmlTooltip), findsOneWidget);
    expect(find.byTooltip(songCoreCopyBackupTooltip), findsOneWidget);
    expect(_buttonEnabled(tester, '扫描曲库'), isTrue);
    expect(_buttonEnabled(tester, '检测游戏目录'), isTrue);
    expect(_buttonEnabled(tester, '读取列表(0)'), isFalse);
    expect(_buttonEnabled(tester, '保存列表'), isFalse);
    expect(_buttonEnabled(tester, '复制XML路径'), isFalse);
    expect(_buttonEnabled(tester, '复制备份目录'), isFalse);
    const songCoreDisabledTooltip = '请先检测并确认有效的 Beat Saber 游戏目录';
    expect(find.byTooltip(songCoreDisabledTooltip), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.text('读取列表(0)'),
        matching: find.byTooltip(songCoreDisabledTooltip),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('保存列表'),
        matching: find.byTooltip(songCoreDisabledTooltip),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('歌单同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('歌单同步'));
    await tester.pumpAndSettle();
    expect(find.text('共享路径配置'), findsNothing);
    expect(find.text('本地歌曲目录'), findsNothing);
    expect(find.text('命名方式'), findsNothing);
    expect(find.text('高级筛选'), findsNothing);
    expect(find.text('ScoreSaber'), findsNothing);
    expect(find.text('SaverAPI'), findsNothing);
    expect(find.text('歌单封面'), findsNothing);
    expect(find.text('保存配置'), findsNothing);
    expect(find.text('下载方式'), findsNothing);
    expect(find.text('完成后'), findsNothing);
    expect(find.text('安装目录'), findsWidgets);
    expect(find.text('歌单路径'), findsOneWidget);
    expect(find.text('扫描歌单同步'), findsOneWidget);
    expect(find.text('扫描曲库'), findsNothing);
    expect(_buttonEnabled(tester, '扫描歌单同步'), isTrue);
    expect(find.text('同步状态'), findsOneWidget);
    expect(find.byTooltip(playlistSyncFilterTooltip), findsOneWidget);
    expect(find.text('扩大表格'), findsOneWidget);
    expect(find.byTooltip(playlistSyncTableExpandTooltip), findsOneWidget);
    await tester.tap(find.text('扩大表格'));
    await tester.pumpAndSettle();
    expect(find.text('收起表格'), findsOneWidget);
    expect(find.byTooltip(playlistSyncTableCollapseTooltip), findsOneWidget);
    await tester.tap(find.text('收起表格'));
    await tester.pumpAndSettle();
    expect(find.text('扩大表格'), findsOneWidget);
    expect(find.text('导出当前(0)'), findsOneWidget);
    expect(find.text('缺失加入本次(0)'), findsOneWidget);
    expect(find.text('下载缺失(0)'), findsOneWidget);
    expect(find.text('安装缺失(0)'), findsOneWidget);
    expect(find.text('导出差异报告'), findsNothing);
    expect(find.text('导出本地有，歌单无(0)'), findsNothing);
    expect(find.text('本地有，歌单无加入本次(0)'), findsNothing);
    expect(find.text('本地有，歌单无加入跳过(0)'), findsNothing);
    expect(find.text('加入本次(0)'), findsNothing);
    expect(find.text('加入跳过(0)'), findsNothing);
    expect(find.byTooltip('读取当前 .bplist 歌单和安装目录，生成一一对比结果。'), findsOneWidget);
    expect(find.byTooltip(playlistSyncExportTooltip), findsOneWidget);
    expect(find.byTooltip(playlistSyncAddMissingTooltip), findsOneWidget);
    expect(find.byTooltip(playlistSyncDownloadMissingTooltip), findsOneWidget);
    expect(find.byTooltip(playlistSyncInstallMissingTooltip), findsOneWidget);
    expect(find.byTooltip(playlistSyncSelectCurrentTooltip), findsOneWidget);
    expect(find.byTooltip(playlistSyncSelectMissingEggTooltip), findsOneWidget);
    expect(
      find.byTooltip(playlistSyncSelectNameMismatchTooltip),
      findsOneWidget,
    );
    expect(find.byTooltip(playlistSyncClearSelectionTooltip), findsOneWidget);
    expect(
      find.byTooltip(playlistSyncRemoveFromPlaylistTooltip),
      findsOneWidget,
    );
    expect(find.byTooltip(playlistSyncBackupDeleteTooltip), findsOneWidget);
    expect(find.byTooltip(playlistSyncLocalOnlyExportTooltip), findsNothing);
    expect(
      find.byTooltip(playlistSyncLocalOnlyAddToTargetsTooltip),
      findsNothing,
    );
    expect(find.byTooltip(playlistSyncLocalOnlyAddToSkipTooltip), findsNothing);
    expect(find.text('已选 0'), findsOneWidget);
    expect(find.text('选择当前(0)'), findsOneWidget);
    expect(find.text('选择缺 egg(0)'), findsOneWidget);
    expect(find.text('选择名称不一致(0)'), findsOneWidget);
    expect(find.text('清空所选(0)'), findsOneWidget);
    expect(find.text('仅移出歌单(0)'), findsOneWidget);
    expect(find.text('备份删除所选(0)'), findsOneWidget);
    expect(_buttonEnabled(tester, '导出当前(0)'), isFalse);
    expect(_buttonEnabled(tester, '缺失加入本次(0)'), isFalse);
    expect(_buttonEnabled(tester, '下载缺失(0)'), isFalse);
    expect(_buttonEnabled(tester, '安装缺失(0)'), isFalse);
    expect(_buttonEnabled(tester, '选择当前(0)'), isFalse);
    expect(_buttonEnabled(tester, '选择缺 egg(0)'), isFalse);
    expect(_buttonEnabled(tester, '选择名称不一致(0)'), isFalse);
    expect(_buttonEnabled(tester, '清空所选(0)'), isFalse);
    expect(_buttonEnabled(tester, '仅移出歌单(0)'), isFalse);
    expect(_buttonEnabled(tester, '备份删除所选(0)'), isFalse);
    expect(find.text('条目 0'), findsOneWidget);
    expect(find.text('选择歌单和安装目录后，可扫描歌单与本地歌曲的差异。'), findsOneWidget);

    await tester.ensureVisible(find.text('找歌下载'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('找歌下载'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('路径与保存方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('路径与保存方式'));
    await tester.pumpAndSettle();
    expect(find.text('保存方式'), findsWidgets);
    expect(find.text('ZIP/命名'), findsWidgets);
    expect(find.text('下载/API'), findsWidgets);
    expect(find.text('完成后'), findsWidgets);
    expect(find.text('导出歌单'), findsOneWidget);
    expect(find.text('安装歌单'), findsOneWidget);
    expect(find.text('歌单入本次'), findsWidgets);
    expect(find.text('歌单封面'), findsOneWidget);
    expect(find.text('选择封面'), findsOneWidget);
    expect(find.byTooltip(profileSaveTooltip), findsOneWidget);
    expect(find.byTooltip(profileDeleteTooltip), findsOneWidget);
    expect(find.byTooltip(pickInstallDirectoryTooltip), findsOneWidget);
    expect(find.byTooltip(pickLocalSongsDirectoryTooltip), findsOneWidget);
    expect(find.byTooltip(pickSkipExistingDirectoryTooltip), findsOneWidget);
    expect(find.byTooltip(androidDirectoryTooltip), findsOneWidget);
    expect(find.byTooltip(pickZipDownloadDirectoryTooltip), findsOneWidget);
    expect(find.byTooltip(pickPlaylistFileTooltip), findsOneWidget);
    expect(find.byTooltip(pickPlaylistSaveTooltip), findsOneWidget);
    expect(find.byTooltip(pickPlaylistCoverTooltip), findsOneWidget);
    expect(find.byTooltip(exportPlaylistTooltip), findsOneWidget);
    expect(find.byTooltip(installPlaylistTooltip), findsOneWidget);
    expect(find.byTooltip(playlistToTargetsTooltip), findsOneWidget);
    expect(find.byTooltip(pickArchiveSaveTooltip), findsOneWidget);
    expect(find.byTooltip(exportInstalledZipTooltip), findsOneWidget);
    expect(find.text('下载方式'), findsOneWidget);
    expect(find.text('本地缓存优先'), findsOneWidget);
    expect(find.text('SaverAPI'), findsOneWidget);
    expect(find.text('更新API'), findsOneWidget);
    expect(find.text('访问重试'), findsOneWidget);
    expect(find.text('访问超时'), findsOneWidget);
    expect(find.text('UA标签'), findsOneWidget);
    expect(find.text('重试次数'), findsOneWidget);
    expect(find.text('超时秒数'), findsOneWidget);
    expect(find.text('多线程'), findsOneWidget);
    expect(find.text('线程数'), findsOneWidget);
    expect(find.text('打包 ZIP'), findsOneWidget);
    expect(find.text('读入本地'), findsOneWidget);
    expect(find.text('自动开始'), findsOneWidget);
    expect(find.text('自动打包'), findsOneWidget);
    expect(find.text('自动解压'), findsOneWidget);
    expect(find.text('自动退出'), findsOneWidget);
    expect(find.byTooltip(readLocalDataOnStartupTooltip), findsOneWidget);
    expect(find.byTooltip(autoStartOnStartupTooltip), findsOneWidget);
    expect(find.byTooltip(autoPackOnCompleteTooltip), findsOneWidget);
    expect(find.byTooltip(autoExtractOnCompleteTooltip), findsOneWidget);
    expect(find.byTooltip(autoExitOnCompleteTooltip), findsOneWidget);
    expect(find.text('命名方式'), findsOneWidget);
    expect(find.text('数据源'), findsOneWidget);
    expect(find.text('运行逻辑说明'), findsNothing);
    expect(find.text('搜索词'), findsOneWidget);

    final uploaderTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('谱师'),
    );
    await tester.ensureVisible(uploaderTab);
    await tester.pumpAndSettle();
    await tester.tap(uploaderTab);
    await tester.pumpAndSettle();
    expect(find.text('谱师谱面'), findsOneWidget);
    expect(
      find.byTooltip('联网搜索：按谱师名或上传者 ID 请求 BeatSaver 谱师谱面。'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('ScoreSaber'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('难度最低'), findsOneWidget);
    expect(find.text('难度最高'), findsOneWidget);
    expect(find.text('Ranked'), findsWidgets);
    expect(find.text('ScoreSaber'), findsWidgets);
    expect(
      find.byTooltip('联网搜索：请求 ScoreSaber ranked 谱面，再转 BeatSaver 详情。'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('BEASTSABER'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第一页地址'), findsOneWidget);
    expect(find.text('开始页数'), findsOneWidget);
    expect(find.text('开始'), findsWidgets);
    expect(
      find.byTooltip('联网搜索：读取 BEASTSABER 页面并用预览 hash 查询 BeatSaver 详情。'),
      findsOneWidget,
    );

    await tester.tap(find.text('本地缓存'));
    await tester.pumpAndSettle();
    expect(find.text('读取数据缓存'), findsOneWidget);
    expect(find.byTooltip(localCachePickTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheReadTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheRebuildTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheResumeTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheIncrementalTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheDeletedAuditTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheDeletedExportTooltip), findsOneWidget);
    expect(find.byTooltip(localCachePauseTooltip), findsOneWidget);
    expect(find.text('数据入本次'), findsOneWidget);
    expect(find.text('数据入跳过'), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('导出摘要'), findsOneWidget);
    expect(find.text('清空数据'), findsOneWidget);
    expect(find.byTooltip(localCacheAddToTargetsTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheAddToSkipTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheExportTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheSummaryTooltip), findsOneWidget);
    expect(find.byTooltip(localCacheClearTooltip), findsOneWidget);
    expect(find.text('Hash 0'), findsOneWidget);
    expect(find.text('导出Hash'), findsOneWidget);
    expect(find.text('清空Hash'), findsOneWidget);
    expect(find.byTooltip(hashCacheExportTooltip), findsOneWidget);
    expect(find.byTooltip(hashCacheClearTooltip), findsOneWidget);
    expect(find.text('ZIP 0'), findsOneWidget);
    expect(find.text('可识别 0'), findsWidgets);
    expect(find.text('扫描 ZIP'), findsWidgets);
    expect(find.text('ZIP 入本次'), findsOneWidget);
    expect(find.text('ZIP 入跳过'), findsOneWidget);
    expect(find.text('导出 ZIP'), findsOneWidget);
    expect(find.byTooltip(zipCacheScanTooltip), findsWidgets);
    expect(find.byTooltip(zipCacheAddToTargetsTooltip), findsWidgets);
    expect(find.byTooltip(zipCacheAddToSkipTooltip), findsWidgets);
    expect(find.byTooltip(zipCacheExportTooltip), findsWidgets);

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('歌曲列表')),
    );
    await tester.pumpAndSettle();
    expect(find.text('在线歌单/链接'), findsOneWidget);
    expect(find.text('歌单入本次'), findsWidgets);
    expect(
      find.byTooltip('联网导入：按 BeatSaver 在线歌单 ID/链接读取歌单，并把筛选后的谱面加入本次列表。'),
      findsOneWidget,
    );
    expect(find.text('读取列表'), findsOneWidget);
    expect(find.text('列表入本次'), findsOneWidget);
    expect(find.text('导出结果'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('手动')),
    );
    await tester.pumpAndSettle();
    expect(find.text('手动 ID/链接'), findsOneWidget);
    expect(find.text('跳过歌曲'), findsOneWidget);
    expect(find.text('安装手动输入'), findsOneWidget);
    expect(find.byTooltip(manualInstallTooltip), findsOneWidget);

    await tester.ensureVisible(find.text('高级筛选'));
    await tester.pumpAndSettle();

    expect(find.text('包含标签'), findsOneWidget);
    expect(find.text('排除标签'), findsOneWidget);
    expect(find.text('封面标签'), findsOneWidget);
    expect(
      find.byTooltip('联网识别：开启后搜索结果会用 GCP Vision 识别封面标签；已命中封面缓存时优先离线复用。'),
      findsOneWidget,
    );
    expect(find.text('GCP Token'), findsOneWidget);
    expect(find.text('封面包含'), findsOneWidget);
    expect(find.text('封面排除'), findsOneWidget);
    expect(find.text('包含置信'), findsOneWidget);
    expect(find.text('排除置信'), findsOneWidget);
    expect(find.text('封面 ACG'), findsOneWidget);
    expect(find.text('失败等待'), findsOneWidget);
    expect(find.text('包含-与'), findsOneWidget);
    expect(find.text('排除-与'), findsOneWidget);
    expect(find.text('导出封面缓存'), findsOneWidget);
    expect(find.text('清空封面缓存'), findsOneWidget);
    expect(find.byTooltip(coverLabelCacheExportTooltip), findsOneWidget);
    expect(find.byTooltip(coverLabelCacheClearTooltip), findsOneWidget);
    for (final label in const [
      '下载量 >=*',
      '游戏 >=',
      '游戏 <=',
      '点赞 >=',
      '赞比 >=',
      '赞比 <=',
      '点踩 <=',
      '踩比 >=',
      '踩比 <=',
      '评分 >=',
      '评分 <=',
      'BPM >=',
      'BPM <=',
      '上传起始',
      '上传截止',
      '方块 >=',
      '方块 <=',
      '炸弹 >=',
      '炸弹 <=',
      '墙 >=',
      '墙 <=',
      '谱秒 >=',
      '谱秒 <=',
      'NJS >=',
      'NJS <=',
      'NPS >=',
      'NPS <=',
      '偏移 >=',
      '偏移 <=',
      '灯光 >=',
      '灯光 <=',
      'Sage >=',
      'Sage <=',
      '星级 >=',
      '星级 <=',
      '最高分 >=',
      '最高分 <=',
      '错 <=',
      '警 <=',
      '重 <=',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('covers final workspace first-screen checklist', (tester) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());
    await tester.pumpAndSettle();

    expect(find.text('Beat Saber Song Toolkit v0.1.0'), findsOneWidget);
    expect(find.text('找歌下载'), findsOneWidget);
    expect(find.text('本地曲库'), findsOneWidget);
    expect(find.text('歌单同步'), findsOneWidget);
    expect(find.byTooltip('捐助作者'), findsOneWidget);
    expect(find.byTooltip('帮助'), findsOneWidget);
    expect(
      find.byTooltip('联网检查更新：请求已配置的 release API，不会自动下载或替换程序。'),
      findsOneWidget,
    );
    expect(find.text('Beat Saber Song Toolkit 主面板'), findsOneWidget);
    expect(find.text('本次歌曲：未选择'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('扫描曲库'), findsNothing);
    expect(find.text('扫描歌单同步'), findsNothing);

    await tester.ensureVisible(find.text('本地曲库'));
    await tester.tap(find.text('本地曲库'));
    await tester.pumpAndSettle();

    expect(find.text('本地曲库'), findsWidgets);
    expect(find.text('安装目录'), findsWidgets);
    expect(find.text('本地歌曲目录'), findsWidgets);
    expect(find.text('游戏目录'), findsWidgets);
    expect(find.text('扫描曲库'), findsOneWidget);
    expect(find.text('检测游戏目录'), findsOneWidget);
    expect(find.text('读取列表(0)'), findsOneWidget);
    expect(find.text('保存列表'), findsOneWidget);
    expect(find.text('复制XML路径'), findsOneWidget);
    expect(find.text('复制备份目录'), findsOneWidget);
    expect(find.text('扫描歌单同步'), findsNothing);

    await tester.ensureVisible(find.text('歌单同步'));
    await tester.tap(find.text('歌单同步'));
    await tester.pumpAndSettle();

    expect(find.text('歌单同步'), findsWidgets);
    expect(find.text('安装目录'), findsWidgets);
    expect(find.text('歌单路径'), findsWidgets);
    expect(find.text('扫描歌单同步'), findsOneWidget);
    expect(find.text('扫描曲库'), findsNothing);
    expect(find.text('选择歌单和安装目录后，可扫描歌单与本地歌曲的差异。'), findsOneWidget);
    expect(find.text('缺失加入本次(0)'), findsOneWidget);
    expect(find.text('下载缺失(0)'), findsOneWidget);
    expect(find.text('安装缺失(0)'), findsOneWidget);
    expect(find.text('仅移出歌单(0)'), findsOneWidget);
    expect(find.text('备份删除所选(0)'), findsOneWidget);
  });

  testWidgets('keeps playlist sync table header fixed while scrolling', (
    tester,
  ) async {
    final entries = List.generate(18, _testPlaylistSyncEntry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 430,
            child: playlistSyncComparisonTableForTest(entries: entries),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerFinder = find.text('歌单歌曲');
    final firstRowFinder = find.text('Song 0\nID id0\nHash hash0');
    expect(headerFinder, findsOneWidget);
    expect(firstRowFinder, findsOneWidget);
    final headerTop = tester.getTopLeft(headerFinder).dy;
    final headerLeft = tester.getTopLeft(headerFinder).dx;
    final firstRowLeft = tester.getTopLeft(firstRowFinder).dx;

    await tester.drag(
      find.byKey(const ValueKey('playlist-sync-table-vertical-scroll')),
      const Offset(0, -560),
    );
    await tester.pumpAndSettle();

    expect(headerFinder, findsOneWidget);
    expect(tester.getTopLeft(headerFinder).dy, closeTo(headerTop, 0.1));
    expect(find.text('Song 10\nID id10\nHash hash10'), findsOneWidget);
    expect(firstRowFinder, findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('playlist-sync-table-horizontal-scroll')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(headerFinder).dx, lessThan(headerLeft));
    expect(
      tester.getTopLeft(find.text('Song 10\nID id10\nHash hash10')).dx,
      lessThan(firstRowLeft),
    );
    expect(find.text('实际歌曲'), findsOneWidget);
  });

  testWidgets('scrolls long playlist sync table to the last row', (
    tester,
  ) async {
    final entries = List.generate(100, _testPlaylistSyncEntry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            height: 520,
            child: playlistSyncComparisonTableForTest(entries: entries),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerFinder = find.text('歌单歌曲');
    expect(headerFinder, findsOneWidget);
    expect(find.text('Song 0\nID id0\nHash hash0'), findsOneWidget);
    expect(find.text('Song 99\nID id99\nHash hash99'), findsNothing);
    final headerTop = tester.getTopLeft(headerFinder).dy;

    await tester.dragUntilVisible(
      find.text('Song 99\nID id99\nHash hash99'),
      find.byKey(const ValueKey('playlist-sync-table-vertical-scroll')),
      const Offset(0, -640),
      maxIteration: 30,
    );
    await tester.pumpAndSettle();

    expect(find.text('Song 99\nID id99\nHash hash99'), findsOneWidget);
    expect(headerFinder, findsOneWidget);
    expect(tester.getTopLeft(headerFinder).dy, closeTo(headerTop, 0.1));
    expect(find.text('Song 0\nID id0\nHash hash0'), findsNothing);
  });

  testWidgets('expands playlist sync table height for long scans', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = List.generate(100, _testPlaylistSyncEntry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 620,
              child: playlistSyncComparisonTableForTest(entries: entries),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final collapsedHeight = tester
        .getSize(find.byKey(const ValueKey('playlist-sync-comparison-table')))
        .height;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 620,
              child: playlistSyncComparisonTableForTest(
                entries: entries,
                expanded: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expandedHeight = tester
        .getSize(find.byKey(const ValueKey('playlist-sync-comparison-table')))
        .height;

    expect(collapsedHeight, closeTo(620, 0.1));
    expect(expandedHeight, closeTo(820, 0.1));
    expect(expandedHeight, greaterThan(collapsedHeight));
    expect(find.text('歌单歌曲'), findsOneWidget);
  });

  testWidgets('keeps enhanced filters collapsed in wide layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BeatSaberSongToolkitApp());
    await tester.pumpAndSettle();

    expect(find.text('高级筛选'), findsOneWidget);
    expect(find.text('搜索过滤'), findsOneWidget);
    expect(find.text('更多增强筛选'), findsOneWidget);
    expect(find.text('包含标签'), findsNothing);
    expect(find.text('封面包含'), findsNothing);

    await tester.tap(find.text('更多增强筛选'));
    await tester.pumpAndSettle();

    expect(find.text('包含标签'), findsOneWidget);
    expect(find.text('封面包含'), findsOneWidget);
    expect(find.text('下载量 >=*'), findsOneWidget);
  });

  testWidgets('shows donation links and sponsor QR', (tester) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());

    await tester.tap(find.byTooltip('捐助作者'));
    await tester.pumpAndSettle();

    expect(find.text('捐助作者'), findsWidgets);
    expect(find.text(donateAuthorMessageForTest()), findsOneWidget);
    expect(find.bySemanticsLabel('赞助收款码'), findsOneWidget);
  });

  testWidgets('shows donation links and sponsor QR from bottom entry', (
    tester,
  ) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());

    await tester.ensureVisible(find.text('捐助作者'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('捐助作者'));
    await tester.pumpAndSettle();

    expect(find.text('捐助作者'), findsWidgets);
    expect(find.text(donateAuthorMessageForTest()), findsOneWidget);
    expect(find.bySemanticsLabel('赞助收款码'), findsOneWidget);
  });

  testWidgets('shows log controls and empty queue state', (tester) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());

    await tester.ensureVisible(find.text('操作日志'));
    await tester.pumpAndSettle();

    expect(find.text('操作日志'), findsOneWidget);
    expect(find.text('实时输出'), findsOneWidget);
    expect(find.text('导出日志'), findsOneWidget);
    expect(find.text('清空日志'), findsOneWidget);
    expect(find.byTooltip(logExportTooltip), findsOneWidget);
    expect(find.byTooltip(logClearTooltip), findsOneWidget);
    expect(find.text('搜索、下载、安装和错误信息会显示在这里。'), findsOneWidget);

    await tester.ensureVisible(find.text('下载队列'));
    await tester.pumpAndSettle();

    expect(find.text('下载队列'), findsOneWidget);
    expect(find.text('批量下载或安装时会在这里显示队列状态。'), findsOneWidget);
  });

  testWidgets('shows workspace help from the title bar', (tester) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());

    await tester.tap(find.byTooltip('帮助'));
    await tester.pumpAndSettle();

    expect(find.text('找歌下载帮助'), findsOneWidget);
    expect(find.text('输入格式'), findsOneWidget);
    expect(find.text('运行逻辑'), findsOneWidget);
    expect(find.text('联网入口'), findsOneWidget);
    expect(
      find.textContaining(
        'BeatSaver 搜索、谱师谱面、ScoreSaber、BEASTSABER 和在线歌单都会访问外部服务',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('封面标签开启后会访问 GCP Vision'), findsOneWidget);
    expect(find.textContaining('检查更新会访问配置的 release API'), findsOneWidget);
    expect(find.text('本地缓存'), findsWidgets);
    expect(find.text('禁止商用'), findsOneWidget);
    expect(find.textContaining('LocalCache.saver'), findsOneWidget);
    expect(find.textContaining('LocalCache.time'), findsOneWidget);
    expect(find.textContaining('轻量索引'), findsOneWidget);
    expect(find.textContaining('/maps/latest'), findsOneWidget);
    expect(find.textContaining('默认 15 天内不重复重建'), findsOneWidget);
    expect(find.textContaining('-fastlog'), findsOneWidget);
    expect(find.textContaining('原远程数据缓存接口已不可用'), findsOneWidget);
    expect(find.textContaining('泽宇缓存(兼容)'), findsOneWidget);
    expect(find.textContaining('默认不视为可靠下载源'), findsOneWidget);
    expect(find.textContaining('本地歌曲目录命中时会优先复制'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('本地曲库'));
    await tester.tap(find.text('本地曲库'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('帮助'));
    await tester.pumpAndSettle();
    expect(find.text('本地曲库帮助'), findsOneWidget);
    expect(find.text('扫描曲库'), findsWidgets);
    expect(find.textContaining('SongCore folders.xml'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('歌单同步'));
    await tester.tap(find.text('歌单同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('帮助'));
    await tester.pumpAndSettle();
    expect(find.text('歌单同步帮助'), findsOneWidget);
    expect(find.text('扫描对比'), findsOneWidget);
    expect(find.textContaining('一一对比'), findsOneWidget);
    expect(find.textContaining('联网解析后加入本次、下载 ZIP 或安装到本地'), findsOneWidget);
    expect(find.textContaining('这些操作不会修改 .bplist'), findsOneWidget);
    expect(find.textContaining('导出当前会保存当前筛选后的表格行'), findsOneWidget);
    expect(
      find.textContaining('导出“本地有，歌单无”只导出本地存在但不在当前歌单中的歌曲'),
      findsOneWidget,
    );
    expect(find.textContaining('加入本次/加入跳过'), findsOneWidget);
  });

  testWidgets('shows LocalCache snapshot builder controls', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BeatSaberSongToolkitApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('本地缓存'));
    await tester.pumpAndSettle();

    expect(find.text('LocalCache.saver'), findsOneWidget);
    expect(find.text('读取数据缓存'), findsOneWidget);
    expect(find.text('重建快照'), findsOneWidget);
    expect(find.text('继续快照'), findsOneWidget);
    expect(find.text('增量更新'), findsOneWidget);
    expect(find.text('审计删除'), findsOneWidget);
    expect(find.text('导出删除'), findsOneWidget);
    expect(find.text('暂停快照'), findsOneWidget);
    expect(_buttonEnabled(tester, '重建快照'), isTrue);
    expect(_buttonEnabled(tester, '继续快照'), isTrue);
    expect(_buttonEnabled(tester, '增量更新'), isTrue);
    expect(_buttonEnabled(tester, '审计删除'), isTrue);
    expect(_buttonEnabled(tester, '导出删除'), isFalse);
    expect(_buttonEnabled(tester, '暂停快照'), isFalse);

    expect(
      find.byTooltip(
        '联网维护：从 BeatSaver /maps/latest 重新构建 LocalCache.saver，'
        '会限速并支持暂停/继续。',
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
        '联网审计：需要已有 LocalCache.saver；读取 BeatSaver 删除候选并标记命中项；不会修改缓存。',
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaves update check disabled without a release URL', (
    tester,
  ) async {
    await tester.pumpWidget(const BeatSaberSongToolkitApp());

    await tester.tap(find.byTooltip('联网检查更新：请求已配置的 release API，不会自动下载或替换程序。'));
    await tester.pump();

    expect(find.text('检查更新地址未配置'), findsOneWidget);
  });

  testWidgets('shows update dialog from configured release API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var requestedReleaseUrl = '';
    releaseFetcherOverrideForTest = (releaseUrl) async {
      requestedReleaseUrl = releaseUrl.toString();
      return const ReleaseInfo(
        tagName: 'v9.9.9',
        htmlUrl: 'https://example.invalid/releases/v9.9.9',
        downloadUrl:
            'https://example.invalid/downloads/Beat Saber Song Toolkit.zip',
      );
    };
    addTearDown(() {
      releaseFetcherOverrideForTest = null;
    });

    await tester.pumpWidget(const BeatSaberSongToolkitApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('路径与保存方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('路径与保存方式'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('更新API'));
    await tester.pumpAndSettle();
    final releaseApiField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'GitHub latest release API',
    );
    await tester.enterText(
      releaseApiField,
      'https://example.invalid/api/releases/latest',
    );
    await tester.pump();

    await tester.tap(find.byTooltip('联网检查更新：请求已配置的 release API，不会自动下载或替换程序。'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(requestedReleaseUrl, 'https://example.invalid/api/releases/latest');
    expect(find.text('发现新版'), findsOneWidget);
    expect(find.textContaining('发现新版 v9.9.9'), findsWidgets);
    expect(
      find.textContaining('https://example.invalid/releases/v9.9.9'),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'https://example.invalid/downloads/Beat Saber Song Toolkit.zip',
      ),
      findsWidgets,
    );

    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 100));
  });
}

bool _buttonEnabled(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    ),
  );
  return button.onPressed != null;
}

PlaylistSyncEntry _testPlaylistSyncEntry(int index) {
  return PlaylistSyncEntry(
    playlistEntry: BplistSongEntry(key: 'id$index', hash: 'hash$index'),
    beatSaverDetail: BeatSaverHashDetail(
      id: 'id$index',
      name: 'Song $index',
      description: '',
    ),
    installedEntry: InstalledSongEntry(
      directory: Directory('installed/id$index'),
      directoryName: 'id$index',
      hasInfoDat: true,
      info: InstalledSongInfo(
        songName: 'Installed $index',
        songSubName: '',
        songAuthorName: 'Artist',
        levelAuthorName: 'Mapper',
        beatsPerMinute: 120,
      ),
      mapId: 'id$index',
      title: 'Installed $index',
    ),
    matchType: PlaylistSyncMatchType.mapId,
    hasEgg: index.isEven,
  );
}

BeatSaverMap _testBeatSaverMap({
  required String id,
  required String uploader,
  required String hash,
  String? name,
  String? songName,
  String? songAuthor,
  String? mapper,
  String? description,
  String? coverUrl,
  List<String> tags = const [],
}) {
  return BeatSaverMap.fromJson({
    'id': id,
    'name': name ?? id,
    'description': description ?? '',
    if (uploader.isNotEmpty) 'uploader': {'id': 1, 'name': uploader},
    if (tags.isNotEmpty) 'tags': tags,
    'metadata': {
      'songName': songName ?? id,
      'songAuthorName': songAuthor ?? 'artist',
      'levelAuthorName': mapper ?? 'mapper',
    },
    'stats': {},
    'versions': [
      if (hash.isNotEmpty) {'hash': hash, 'coverURL': ?coverUrl},
    ],
  });
}

BeatSaverDifficulty _testDifficulty({
  String difficulty = 'Expert',
  String characteristic = 'Standard',
  bool chroma = false,
  bool cinema = false,
  bool me = false,
  bool ne = false,
  bool vivify = false,
}) {
  return BeatSaverDifficulty.fromJson({
    'difficulty': difficulty,
    'characteristic': characteristic,
    'chroma': chroma,
    'cinema': cinema,
    'me': me,
    'ne': ne,
    'vivify': vivify,
  });
}
