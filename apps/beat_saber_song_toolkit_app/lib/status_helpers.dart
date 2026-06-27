String pathSelectionStatusForTest({
  required String label,
  required String? path,
}) {
  return path == null ? '未选择$label' : '$label：$path';
}

String exportFileStatusForTest({required String label, required String? path}) {
  return path == null ? '未选择$label保存位置' : '$label已导出：$path';
}

String favoritePlaylistExportStatusForTest({
  required int count,
  required String path,
}) {
  return '收藏歌单已导出：$path，收藏歌曲 $count 首';
}

String installedPlaylistExportStatusForTest({
  required int count,
  required int skipped,
  required String path,
}) {
  final skippedText = skipped > 0 ? '，跳过 $skipped 首无 ID 或缺 info.dat' : '';
  return '已安装歌单已导出：$path，歌曲 $count 首$skippedText';
}

String songCountStatusForTest({required String label, required int count}) {
  return '$label：$count 首';
}

String androidDirectoryStatusForTest(String? uri) {
  return uri == null ? '未选择 Android 目录' : 'Android 目录 URI：$uri';
}

String readFileStatusForTest({required String label, required String path}) {
  return '已读取$label：$path';
}

String savedFileStatusForTest({required String label, required String path}) {
  return '$label已保存：$path';
}

String profileDeleteStatusForTest({
  required bool removed,
  required String profileName,
}) {
  return removed ? '配置已删除：$profileName' : '未找到配置：$profileName';
}

String profileDeleteConfirmTextForTest(String profileName) {
  return '将删除已保存配置：$profileName\n\n'
      '只会从 settings.json 的配置预设列表中移除该项，不会删除歌曲、ZIP、歌单或 LocalCache.saver。';
}

String cacheFileClearConfirmTextForTest({
  required String label,
  required String path,
  required String preserved,
}) {
  return '将清空本地$label缓存：\n'
      '$path\n\n'
      '这会删除该缓存文件中的已保存结果；不会删除$preserved。';
}

String presetAppliedStatusForTest(String presetName) {
  return '已应用 $presetName';
}

String completedFileStatusForTest({
  required String label,
  String action = '已下载',
  String separator = '',
  required String path,
}) {
  return '$label$separator$action：$path';
}

String localScanStatusForTest({
  required int installedCount,
  required int zipCacheCount,
}) {
  return '已安装歌曲：$installedCount 首，ZIP 缓存 $zipCacheCount 个';
}

String localScanLogForTest({
  required int installedCount,
  required int zipCacheCount,
}) {
  return '扫描完成：$installedCount 首，ZIP 缓存 $zipCacheCount 个';
}

String deleteInstalledStatusForTest({
  required String id,
  required String? deletedTitle,
}) {
  return deletedTitle == null ? '未找到 id 为 $id 的已安装歌曲' : '已删除 $deletedTitle';
}

String installedPathCorrectionStatusForTest({
  required String oldName,
  required String newName,
  required String path,
}) {
  return '路径纠错完成：$oldName -> $newName，$path';
}

String installedPathCorrectionBatchStatusForTest({
  required int requested,
  required int renamed,
  required int failed,
  String? failureSourcePath,
  String? failureExpectedDirectoryName,
  String? failureReason,
}) {
  final failureExample =
      failed > 0 &&
          failureSourcePath != null &&
          failureExpectedDirectoryName != null &&
          failureReason != null
      ? '，失败示例：$failureSourcePath -> $failureExpectedDirectoryName（$failureReason）'
      : '';
  return '批量路径纠错完成：请求 $requested，重命名 $renamed，失败 $failed$failureExample';
}

String installedDuplicateDeleteStatusForTest({
  required int requested,
  required int deleted,
  required int backups,
  int skippedMissing = 0,
  String? backupDirectory,
}) {
  final skipped = skippedMissing > 0 ? '，跳过 $skippedMissing 个已不存在目录' : '';
  final backup = backupDirectory == null ? '' : '，备份目录：$backupDirectory';
  return '重复歌曲备份删除完成：请求 $requested，删除 $deleted，备份 $backups$skipped$backup';
}

String installedPathCorrectionConfirmTextForTest({
  required String oldName,
  required String newName,
}) {
  return '将本地歌曲目录重命名：\n'
      '$oldName\n'
      '-> $newName\n\n'
      '只会在同一父目录内重命名；如果目标目录已存在，会自动停止。';
}

String installedPathCorrectionBatchConfirmTextForTest({
  required int count,
  required String preview,
  required int hiddenCount,
  bool templateDifferenceOnly = false,
}) {
  final extra = hiddenCount > 0 ? '\n还有 $hiddenCount 条未显示。' : '';
  final templateWarning = templateDifferenceOnly
      ? '\n\n这些条目主要是当前命名模板与现有目录名不同；'
            '批量重命名会按当前模板统一改名，不代表目录损坏。'
      : '';
  return '将批量重命名 $count 个本地歌曲目录：\n'
      '$preview$extra$templateWarning\n\n'
      '每条只会在同一父目录内重命名；如果目标目录已存在，该条会失败并跳过。';
}

String installedDuplicateDeleteConfirmTextForTest({
  required int count,
  required String preview,
  required int hiddenCount,
}) {
  final extra = hiddenCount > 0 ? '\n\n还有 $hiddenCount 项未显示。' : '';
  return '将备份并删除 $count 个本地歌曲目录：\n\n'
      '$preview$extra\n\n'
      '备份目录会写入安装目录同级的 *_backup\\duplicates；删除前不会改写歌单。';
}

String installedSingleDeleteConfirmTextForTest({
  required String title,
  required String path,
}) {
  return '将直接删除这个本地歌曲目录：\n'
      '$title\n'
      '$path\n\n'
      '此操作不会创建备份，也不会修改任何歌单文件；如需保留恢复点，请先手动备份或使用重复歌曲的备份删除流程。';
}

String playlistSyncDeleteConfirmTextForTest({required int count}) {
  return '将先在歌单文件同目录的 backup 文件夹中备份当前歌单文件和 $count 个本地歌曲目录，'
      '然后删除这些本地目录，并从歌单 songs 中移除对应条目。\n\n'
      '此操作会修改歌单文件，也会删除本地歌曲目录；请确认已选项都是要删除的已安装歌曲。';
}

String playlistSyncPlaylistRemoveConfirmTextForTest({required int count}) {
  return '将先在歌单文件同目录的 backup 文件夹中备份当前歌单文件，'
      '然后仅从歌单 songs 中移除 $count 个条目。\n\n'
      '不会删除或移动任何本地歌曲目录；适合处理本地缺失或不想保留在歌单中的条目。'
      '此操作会修改歌单文件。';
}

String songCoreFolderRemoveConfirmTextForTest({
  required String name,
  required String path,
}) {
  return '将从 SongCore 保存列表移除该条目：\n'
      '$name\n'
      '$path\n\n'
      '只会修改 folders.xml，不会删除本地歌曲目录。';
}

String addedTargetStatusForTest(String title) {
  return '已加入本次：$title';
}

String logOutputStatusForTest({required bool paused}) {
  return paused ? '日志输出已暂停' : '日志输出已恢复';
}

String errorStatusForTest(Object error) {
  return '错误：$error';
}

String clearedStatusForTest(String target, {bool prefix = false}) {
  return prefix ? '已清空$target' : '$target已清空';
}

String emptyExportStatusForTest(String target) {
  return '当前没有$target可导出';
}

String requireActionStatusForTest(String action) {
  return '请先$action';
}

String emptyFilteredLocalCacheStatusForTest() {
  return '当前本地数据缓存筛选结果为空';
}

String missingLocalCacheForIncrementalUpdateStatusForTest() {
  return '请先选择、读取或重建 LocalCache.saver 后再执行增量更新';
}

String localCacheAddStatusForTest({
  required String target,
  required int count,
}) {
  return '已从本地数据缓存加入$target：$count 首';
}

String successFailureStatusForTest({
  required String label,
  required int success,
  required int failed,
}) {
  return '$label：成功 $success，失败 $failed';
}

String importedPlaylistInstallStatusForTest({
  required String title,
  required int installed,
  required int skipped,
  required int failed,
}) {
  return '导入“$title”完成：安装 $installed 首，跳过 $skipped 首，失败 $failed 首';
}

String importedPlaylistReadyStatusForTest({
  required String title,
  required int maps,
  required int failed,
}) {
  return '歌单“$title”读取完成：可安装 $maps 首，失败 $failed 首';
}

String importedPlaylistTargetsStatusForTest({
  required String title,
  required int added,
  required int failed,
}) {
  return '歌单“$title”已加入本次：$added 首，失败 $failed 首';
}

String restoredTargetsStatusForTest({
  required int restored,
  required int failed,
}) {
  return failed == 0 ? '已恢复本次歌曲：$restored 首' : '已恢复本次歌曲：$restored 首，失败 $failed';
}

String manualAddResultsStatusForTest({
  required int added,
  required int failed,
}) {
  return '已添加 $added 张谱面到结果，失败 $failed';
}

String zipCacheCountStatusForTest(int count) {
  return 'ZIP 缓存：$count 个';
}

enum ConfigFileProblemForTest { missing, invalid }

String configFileProblemStatusForTest(ConfigFileProblemForTest problem) {
  return switch (problem) {
    ConfigFileProblemForTest.missing => '配置文件不存在',
    ConfigFileProblemForTest.invalid => '配置文件格式无效',
  };
}

String emptyActionStatusForTest(String target) {
  return '当前没有$target';
}

String outputModeDisabledStatusForTest() {
  return '保存方式未启用歌曲列表或下载歌曲';
}

String autoExitReadyStatusForTest() {
  return '任务完成，准备自动退出...';
}

String configLoadedStatusForTest() {
  return '配置已读取';
}

String missingBeatSaverIdStatusForTest({required String action}) {
  return '无法$action：缺少 BeatSaver id';
}

String noRetryFailedStatusForTest() {
  return '没有失败项可重试';
}

String selectedTargetsTitleForTest(int selectedCount) {
  return selectedCount <= 0 ? '本次歌曲：未选择' : '本次歌曲：$selectedCount 首';
}

String selectedTargetsPrimaryButtonLabelForTest({
  required bool busy,
  required bool stopRequested,
}) {
  return busy ? (stopRequested ? '停止已请求' : '停止') : '开始';
}

bool selectedTargetsStartEnabledForTest({
  required int selectedCount,
  required bool busy,
  required bool stopRequested,
}) {
  return !busy && selectedCount > 0 && !stopRequested;
}

bool selectedTargetsStopEnabledForTest({
  required bool busy,
  required bool stopRequested,
}) {
  return busy && !stopRequested;
}

bool selectedResultsActionEnabledForTest({
  required int selectedCount,
  required bool busy,
}) {
  return !busy && selectedCount > 0;
}

bool zipCacheExportEnabledForTest({
  required int entryCount,
  required bool busy,
}) {
  return !busy && entryCount > 0;
}

bool zipCacheRecognizedActionEnabledForTest({
  required int recognizedCount,
  required bool busy,
}) {
  return !busy && recognizedCount > 0;
}

bool coverLabelCacheActionEnabledForTest({
  required int entries,
  required bool busy,
}) {
  return !busy && entries > 0;
}

bool installedFilteredIdActionEnabledForTest({
  required int entryCount,
  required bool busy,
}) {
  return !busy && entryCount > 0;
}

bool installedExportCurrentEnabledForTest({
  required int filteredCount,
  required bool busy,
}) {
  return !busy && filteredCount > 0;
}

bool installedExportPlaylistEnabledForTest({
  required int exportableCount,
  required bool busy,
}) {
  return !busy && exportableCount > 0;
}

bool installedFavoritesExportEnabledForTest({required bool busy}) {
  return !busy;
}

bool gameDirectoryInspectEnabledForTest({required bool busy}) {
  return !busy;
}

String gameDirectoryInspectDisabledReasonForTest({required bool busy}) {
  return busy ? '正在执行任务，暂不能检测游戏目录' : '';
}

class SongCoreFolderActionState {
  const SongCoreFolderActionState({
    required this.enabled,
    required this.disabledReason,
  });

  final bool enabled;
  final String disabledReason;
}

SongCoreFolderActionState songCoreFolderActionStateForTest({
  required bool busy,
  required bool isBeatSaberDirectory,
  required bool isSongCoreInstalled,
}) {
  final reason = songCoreFolderDisabledReasonForTest(
    busy: busy,
    isBeatSaberDirectory: isBeatSaberDirectory,
    isSongCoreInstalled: isSongCoreInstalled,
  );
  return SongCoreFolderActionState(
    enabled: reason.isEmpty,
    disabledReason: reason,
  );
}

bool songCoreFolderSaveEnabledForTest({
  required bool busy,
  required bool isBeatSaberDirectory,
  required bool isSongCoreInstalled,
}) {
  return songCoreFolderActionStateForTest(
    busy: busy,
    isBeatSaberDirectory: isBeatSaberDirectory,
    isSongCoreInstalled: isSongCoreInstalled,
  ).enabled;
}

bool songCoreFolderReadEnabledForTest({
  required bool busy,
  required bool isBeatSaberDirectory,
  required bool isSongCoreInstalled,
}) {
  return songCoreFolderActionStateForTest(
    busy: busy,
    isBeatSaberDirectory: isBeatSaberDirectory,
    isSongCoreInstalled: isSongCoreInstalled,
  ).enabled;
}

bool songCoreFolderRemoveEnabledForTest({required bool busy}) {
  return !busy;
}

class StatusChipState {
  const StatusChipState({required this.label, this.tooltip = ''});

  final String label;
  final String tooltip;
}

String songCoreFolderDisabledReasonForTest({
  required bool busy,
  required bool isBeatSaberDirectory,
  required bool isSongCoreInstalled,
}) {
  if (busy) {
    return '正在执行任务，暂不能操作 SongCore 保存列表';
  }
  if (!isBeatSaberDirectory) {
    return '请先检测并确认有效的 Beat Saber 游戏目录';
  }
  if (!isSongCoreInstalled) {
    return '需要安装 SongCore 后才能读取或保存 SongCore 列表';
  }
  return '';
}

String gameDirectoryInspectStatusForTest({
  required bool isBeatSaberDirectory,
  required bool songCoreInstalled,
  required bool playlistManagerInstalled,
  required String path,
}) {
  final game = gameDirectoryStatusLabelForTest(
    isBeatSaberDirectory: isBeatSaberDirectory,
  );
  final songCore = songCoreInstalled ? '已安装' : '未安装';
  final playlistManager = playlistManagerInstalled ? '已安装' : '未安装';
  return '$game：$path，SongCore $songCore，PlaylistManager $playlistManager';
}

String gameDirectoryStatusLabelForTest({required bool isBeatSaberDirectory}) {
  return isBeatSaberDirectory ? '游戏目录有效' : '游戏目录无效';
}

StatusChipState gameDirectoryChipStateForTest({
  required bool isBeatSaberDirectory,
  required String path,
}) {
  return StatusChipState(
    label: gameDirectoryStatusLabelForTest(
      isBeatSaberDirectory: isBeatSaberDirectory,
    ),
    tooltip: isBeatSaberDirectory ? '有效游戏目录：$path' : '无效游戏目录：$path',
  );
}

String songCoreInstallTooltipForTest({
  required bool installed,
  required String path,
}) {
  return installed ? '已找到 SongCore：$path' : '未找到 SongCore：$path';
}

String songCoreInstallLabelForTest({required bool installed}) {
  return installed ? 'SongCore 已安装' : 'SongCore 未安装';
}

StatusChipState songCoreInstallChipStateForTest({
  required bool installed,
  required String path,
}) {
  return StatusChipState(
    label: songCoreInstallLabelForTest(installed: installed),
    tooltip: songCoreInstallTooltipForTest(installed: installed, path: path),
  );
}

String playlistManagerInstallTooltipForTest({
  required bool installed,
  required String path,
}) {
  return installed ? '已找到 PlaylistManager：$path' : '未找到 PlaylistManager：$path';
}

String playlistManagerInstallLabelForTest({required bool installed}) {
  return installed ? 'PlaylistManager 已安装' : 'PlaylistManager 未安装';
}

StatusChipState playlistManagerInstallChipStateForTest({
  required bool installed,
  required String path,
}) {
  return StatusChipState(
    label: playlistManagerInstallLabelForTest(installed: installed),
    tooltip: playlistManagerInstallTooltipForTest(
      installed: installed,
      path: path,
    ),
  );
}

String songCoreFolderSaveStatusForTest({
  required bool added,
  required bool updated,
  required int validSongs,
  required String path,
  String? songFolderPath,
  String? backupPath,
  String? backupDirectory,
}) {
  final action = added
      ? '已新增'
      : updated
      ? '已更新'
      : '已保持';
  final backup = _songCoreBackupText(
    backupPath,
    backupDirectory,
    fallback: !added && !updated ? '未改写，无需备份' : '无原文件备份',
  );
  final songFolder = songFolderPath == null ? '' : '，曲包：$songFolderPath';
  return 'SongCore 保存列表$action：有效歌曲 $validSongs，$path$songFolder，$backup';
}

String songCoreFolderReadStatusForTest({
  required int count,
  required String path,
  String? backupDirectory,
}) {
  final backup = backupDirectory == null ? '' : '，备份目录：$backupDirectory';
  return 'SongCore 保存列表已读取：$count 项，$path$backup';
}

String songCoreFolderRemoveStatusForTest({
  required int removed,
  required int remaining,
  required String path,
  String? removedEntryPath,
  String? backupPath,
  String? backupDirectory,
}) {
  final backup = _songCoreBackupText(
    backupPath,
    backupDirectory,
    fallback: removed == 0 ? '未改写，无需备份' : '无原文件备份',
  );
  final removedEntry = removedEntryPath == null
      ? ''
      : '，移除条目：$removedEntryPath';
  if (removed == 0) {
    return 'SongCore 保存列表未找到匹配条目：剩余 $remaining 项，$path$removedEntry，$backup';
  }
  return 'SongCore 保存列表已移除：$removed 项，剩余 $remaining 项，$path$removedEntry，$backup';
}

String songCoreFolderListScrollHintForTest({required int count}) {
  return '列表可滚动查看全部 $count 项。';
}

String copiedPathStatusForTest({required String label, required String path}) {
  return '$label已复制：$path';
}

String songCoreBackupDirectoryForTest({required String foldersFilePath}) {
  final separator = foldersFilePath.contains('\\') ? '\\' : '/';
  final index = foldersFilePath.lastIndexOf(separator);
  if (index < 0) {
    return 'backups';
  }
  return '${foldersFilePath.substring(0, index)}${separator}backups';
}

String _songCoreBackupText(
  String? backupPath,
  String? backupDirectory, {
  required String fallback,
}) {
  if (backupPath == null) {
    return fallback;
  }
  final directory = backupDirectory == null ? '' : '，备份目录：$backupDirectory';
  return '备份：$backupPath$directory';
}

bool installedSelectionActionEnabledForTest({
  required int selectedCount,
  required bool busy,
}) {
  return !busy && selectedCount > 0;
}

String installedSelectionSummaryForTest({
  required String label,
  required int selectedCount,
  required int validCount,
}) {
  final staleCount = selectedCount - validCount;
  final staleText = staleCount > 0 ? '，已失效 $staleCount 条' : '';
  return '$label已选 $validCount 条$staleText';
}

String installedAdviceScrollHintForTest({
  required String label,
  required int count,
}) {
  return '$label可滚动查看全部 $count 项。';
}

bool installedVisibleSelectionEnabledForTest({
  required int visibleCount,
  required bool busy,
}) {
  return !busy && visibleCount > 0;
}

bool playlistSyncExportEnabledForTest({
  required int filteredCount,
  required bool busy,
}) {
  return !busy && filteredCount > 0;
}

bool playlistSyncSelectEnabledForTest({
  required int deletableCount,
  required bool busy,
}) {
  return !busy && deletableCount > 0;
}

bool playlistSyncClearSelectionEnabledForTest({
  required int selectedCount,
  required bool busy,
}) {
  return !busy && selectedCount > 0;
}

bool playlistSyncDeleteEnabledForTest({
  required int selectedCount,
  required bool busy,
}) {
  return !busy && selectedCount > 0;
}

bool playlistSyncPlaylistRemoveEnabledForTest({
  required int selectedCount,
  required bool busy,
}) {
  return !busy && selectedCount > 0;
}

bool playlistSyncInstalledDeleteEnabledForTest({
  required int selectedInstalledCount,
  required bool busy,
}) {
  return !busy && selectedInstalledCount > 0;
}

bool queueStopEnabledForTest({
  required bool busy,
  required bool stopRequested,
}) {
  return busy && !stopRequested;
}

bool queueRetryFailedEnabledForTest({
  required int failedCount,
  required bool busy,
}) {
  return !busy && failedCount > 0;
}

bool queueClearFinishedEnabledForTest({
  required int clearableCount,
  required bool busy,
}) {
  return !busy && clearableCount > 0;
}

bool queueClearAllEnabledForTest({required bool busy}) {
  return !busy;
}
