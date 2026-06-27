import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

import 'installed_library_helpers.dart';

enum PlaylistSyncFilterModeForTest {
  all,
  installed,
  missing,
  hashMatched,
  nameMatched,
  nameMismatched,
  missingEgg,
}

String playlistSyncStatusForTest(Iterable<PlaylistSyncEntry> entries) {
  final list = entries.toList(growable: false);
  final installed = list.where((entry) => entry.isInstalled).length;
  final missing = list.length - installed;
  final nameMatched = list
      .where((entry) => entry.matchType == PlaylistSyncMatchType.normalizedName)
      .length;
  final hashMatched = list
      .where((entry) => entry.matchType == PlaylistSyncMatchType.localHash)
      .length;
  final missingEgg = list
      .where((entry) => entry.isInstalled && !entry.hasEgg)
      .length;
  return '歌单同步扫描完成：共 ${list.length}，本地存在 $installed，'
      '缺失 $missing，名称辅助匹配 $nameMatched，Hash匹配 $hashMatched，'
      '缺少 egg $missingEgg';
}

String playlistSyncDeleteStatusForTest(PlaylistSyncDeleteResult result) {
  final backup = result.playlistBackup;
  final playlistBackupText = backup == null
      ? '无歌单备份'
      : '歌单备份：${backup.path}，歌单备份目录：${backup.parent.path}';
  final songBackupText = result.songBackups.isEmpty
      ? '未备份本地歌曲目录'
      : '歌曲备份目录：${result.songBackups.first.parent.path}';
  return '歌单同步删除完成：请求 ${result.requested}，'
      '删除本地目录 ${result.deleted}，歌单移除 ${result.removedPlaylistEntries}，'
      '歌曲备份 ${result.songBackups.length}，$playlistBackupText，$songBackupText';
}

String playlistSyncPlaylistRemoveStatusForTest(
  PlaylistSyncPlaylistRemoveResult result,
) {
  final backup = result.playlistBackup;
  final backupText = backup == null
      ? '无歌单备份'
      : '歌单备份：${backup.path}，歌单备份目录：${backup.parent.path}';
  return '歌单同步移出完成：请求 ${result.requested}，'
      '歌单移除 ${result.removedPlaylistEntries}，未删除本地目录，$backupText';
}

String playlistSyncMissingAddProgressStatusForTest({
  required int current,
  required int total,
  required PlaylistSyncEntry entry,
}) {
  final id = entry.mapId.isEmpty ? '-' : entry.mapId;
  final hash = entry.hash.isEmpty ? '-' : entry.hash;
  return '正在解析缺失歌曲 $current/$total：ID $id，Hash $hash';
}

String playlistSyncMissingAddStatusForTest({
  required int requested,
  required int added,
  required int existing,
  required int failed,
}) {
  return '缺失加入本次完成：请求 $requested，新增 $added，已存在 $existing，失败 $failed';
}

String playlistSyncMissingDownloadStatusForTest({
  required int requested,
  required int resolved,
  required int downloaded,
  required int skipped,
  required int stopped,
  required int failed,
}) {
  return '缺失下载完成：请求 $requested，解析 $resolved，下载 $downloaded，'
      '跳过 $skipped，停止 $stopped，失败 $failed';
}

String playlistSyncMissingInstallStatusForTest({
  required int requested,
  required int resolved,
  required int installed,
  required int skipped,
  required int stopped,
  required int failed,
}) {
  return '缺失安装完成：请求 $requested，解析 $resolved，安装 $installed，'
      '跳过 $skipped，停止 $stopped，失败 $failed';
}

String playlistSyncExportListForTest(Iterable<PlaylistSyncEntry> entries) {
  final rows = [
    '状态\t原因\t匹配\t名称一致\tID\tHash\tBeatSaver名称\t本地名称\t作者\t难度\tEgg\t路径',
    for (final entry in entries)
      [
        entry.isInstalled ? '本地存在' : '缺失',
        playlistSyncMissingReasonForTest(entry),
        playlistSyncMatchLabelForTest(entry.matchType),
        playlistSyncNameMismatchForTest(entry) ? '否' : '是',
        entry.mapId.isEmpty ? '-' : entry.mapId,
        entry.hash.isEmpty ? '-' : entry.hash,
        entry.beatSaverDetail?.name.trim().isNotEmpty == true
            ? entry.beatSaverDetail!.name.trim()
            : '-',
        entry.installedEntry?.info?.songName.trim().isNotEmpty == true
            ? entry.installedEntry!.info!.songName.trim()
            : entry.installedEntry?.title ?? '-',
        entry.installedEntry?.info?.songAuthorName ?? '-',
        entry.installedEntry?.info?.difficulties.join('/').isNotEmpty == true
            ? entry.installedEntry!.info!.difficulties.join('/')
            : '-',
        entry.hasEgg ? '是' : '否',
        entry.installedEntry?.directory.path ?? '-',
      ].join('\t'),
  ];
  return rows.join('\n');
}

String playlistSyncDifferenceReportForTest({
  required Iterable<PlaylistSyncEntry> entries,
  required Iterable<InstalledSongEntry> localOnlyInstalledEntries,
}) {
  final list = entries.toList(growable: false);
  final localOnly = localOnlyInstalledEntries.toList(growable: false);
  final missing = list.where((entry) => !entry.isInstalled).toList();
  final nameMismatched = list.where(playlistSyncNameMismatchForTest).toList();
  final missingEgg = list
      .where((entry) => entry.isInstalled && !entry.hasEgg)
      .toList();
  return [
    '歌单同步差异报告',
    '汇总',
    '歌单条目\t${list.length}',
    '缺失\t${missing.length}',
    '本地有，歌单无\t${localOnly.length}',
    '名称不一致\t${nameMismatched.length}',
    '缺 egg\t${missingEgg.length}',
    '',
    '缺失',
    playlistSyncExportListForTest(missing),
    '',
    '本地有，歌单无',
    installedExportListForTest(localOnly.map(installedEntrySnapshotForTest)),
    '',
    '名称不一致',
    playlistSyncExportListForTest(nameMismatched),
    '',
    '缺 egg',
    playlistSyncExportListForTest(missingEgg),
  ].join('\n');
}

String playlistSyncEntryKeyForTest(PlaylistSyncEntry entry) {
  final key = entry.playlistEntry.key.trim().toLowerCase();
  final hash = entry.playlistEntry.hash.trim().toLowerCase();
  if (key.isNotEmpty && hash.isNotEmpty) {
    return '$key|$hash';
  }
  if (key.isNotEmpty) {
    return 'key:$key';
  }
  if (hash.isNotEmpty) {
    return 'hash:$hash';
  }
  return '';
}

bool playlistSyncNameMismatchForTest(PlaylistSyncEntry entry) {
  final remoteName = entry.beatSaverDetail?.name.trim();
  final localName =
      entry.installedEntry?.info?.songName.trim() ??
      entry.installedEntry?.title;
  if (remoteName == null ||
      remoteName.isEmpty ||
      localName == null ||
      localName.isEmpty) {
    return false;
  }
  return _normalizedPlaylistSyncName(remoteName) !=
      _normalizedPlaylistSyncName(localName);
}

String playlistSyncMissingReasonForTest(PlaylistSyncEntry entry) {
  if (entry.isInstalled) {
    return '-';
  }
  if (entry.mapId.isNotEmpty) {
    return '本地未找到相同 ID';
  }
  if (entry.hash.isNotEmpty) {
    return '本地未找到相同 hash';
  }
  return '歌单条目缺少 ID/hash';
}

String playlistSyncMatchLabelForTest(PlaylistSyncMatchType matchType) {
  return switch (matchType) {
    PlaylistSyncMatchType.mapId => 'ID 匹配',
    PlaylistSyncMatchType.normalizedName => '名称辅助匹配',
    PlaylistSyncMatchType.localHash => 'Hash 匹配',
    PlaylistSyncMatchType.missing => '本地缺失',
  };
}

String playlistSyncFilterModeLabelForTest(PlaylistSyncFilterModeForTest mode) {
  return switch (mode) {
    PlaylistSyncFilterModeForTest.all => '全部',
    PlaylistSyncFilterModeForTest.installed => '本地存在',
    PlaylistSyncFilterModeForTest.missing => '缺失',
    PlaylistSyncFilterModeForTest.hashMatched => 'Hash匹配',
    PlaylistSyncFilterModeForTest.nameMatched => '名称辅助匹配',
    PlaylistSyncFilterModeForTest.nameMismatched => '名称不一致',
    PlaylistSyncFilterModeForTest.missingEgg => '缺 egg',
  };
}

List<String> playlistSyncFilterLabelsForTest() {
  return PlaylistSyncFilterModeForTest.values
      .map(playlistSyncFilterModeLabelForTest)
      .toList(growable: false);
}

List<PlaylistSyncEntry> filterPlaylistSyncEntriesForTest(
  List<PlaylistSyncEntry> entries,
  PlaylistSyncFilterModeForTest mode,
) {
  return entries
      .where((entry) {
        return switch (mode) {
          PlaylistSyncFilterModeForTest.all => true,
          PlaylistSyncFilterModeForTest.installed => entry.isInstalled,
          PlaylistSyncFilterModeForTest.missing => !entry.isInstalled,
          PlaylistSyncFilterModeForTest.hashMatched =>
            entry.matchType == PlaylistSyncMatchType.localHash,
          PlaylistSyncFilterModeForTest.nameMatched =>
            entry.matchType == PlaylistSyncMatchType.normalizedName,
          PlaylistSyncFilterModeForTest.nameMismatched =>
            playlistSyncNameMismatchForTest(entry),
          PlaylistSyncFilterModeForTest.missingEgg =>
            entry.isInstalled && !entry.hasEgg,
        };
      })
      .toList(growable: false);
}

String playlistSyncTitleForTest(PlaylistSyncEntry entry) {
  final name = entry.beatSaverDetail?.name.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final localTitle = entry.installedEntry?.title;
  if (localTitle != null && localTitle.isNotEmpty) {
    return localTitle;
  }
  final id = entry.mapId;
  if (id.isNotEmpty) {
    return 'BeatSaver ID $id';
  }
  final hash = entry.hash;
  return hash.isEmpty ? '未知歌单条目' : 'Hash $hash';
}

String playlistSyncPlaylistLabelForTest(PlaylistSyncEntry entry) {
  final title = playlistSyncTitleForTest(entry);
  final id = entry.mapId.isEmpty ? '-' : entry.mapId;
  final hash = entry.hash.isEmpty ? '-' : entry.hash;
  return '$title\nID $id\nHash $hash';
}

String playlistSyncInstalledLabelForTest(PlaylistSyncEntry entry) {
  final local = entry.installedEntry;
  if (local == null) {
    return '-';
  }
  final title = local.title?.trim().isNotEmpty == true
      ? local.title!.trim()
      : local.directoryName;
  final author = local.info?.songAuthorName.trim();
  final mapper = local.info?.levelAuthorName.trim();
  final parts = <String>[
    title,
    if (author != null && author.isNotEmpty) '作者 $author',
    if (mapper != null && mapper.isNotEmpty) '谱师 $mapper',
  ];
  return parts.join('\n');
}

String _normalizedPlaylistSyncName(String value) {
  return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}
