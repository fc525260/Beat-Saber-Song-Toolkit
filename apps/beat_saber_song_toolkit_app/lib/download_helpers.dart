enum CompletionActionForTest { packZip, extractDownloaded, exitApp }

List<CompletionActionForTest> completionActionsForTest({
  required bool autoPack,
  required bool autoExtract,
  required bool autoExit,
  required int stopped,
  required int failed,
}) {
  return [
    if (stopped == 0 && autoPack) CompletionActionForTest.packZip,
    if (stopped == 0 && autoExtract) CompletionActionForTest.extractDownloaded,
    if (stopped == 0 && failed == 0 && autoExit)
      CompletionActionForTest.exitApp,
  ];
}

enum DownloadModeForTest { localCache, zeyuCache, api }

enum DownloadSourceForTest { localZipCache, zeyuCache, beatSaverApi }

enum DownloadTaskResultForTest { downloaded, skipped, failed }

class DownloadSummaryForTest {
  const DownloadSummaryForTest({
    required this.downloaded,
    required this.skipped,
    required this.stopped,
    required this.failed,
  });

  final int downloaded;
  final int skipped;
  final int stopped;
  final int failed;
}

DownloadSummaryForTest downloadSummaryForTest({
  required Iterable<DownloadTaskResultForTest> results,
  required int stopped,
}) {
  var downloaded = 0;
  var skipped = 0;
  var failed = 0;
  for (final result in results) {
    switch (result) {
      case DownloadTaskResultForTest.downloaded:
        downloaded += 1;
      case DownloadTaskResultForTest.skipped:
        skipped += 1;
      case DownloadTaskResultForTest.failed:
        failed += 1;
    }
  }
  return DownloadSummaryForTest(
    downloaded: downloaded,
    skipped: skipped,
    stopped: stopped < 0 ? 0 : stopped,
    failed: failed,
  );
}

String downloadModeLabelForTest(DownloadModeForTest mode) {
  return switch (mode) {
    DownloadModeForTest.localCache => '本地缓存优先',
    DownloadModeForTest.zeyuCache => '泽宇缓存(兼容)',
    DownloadModeForTest.api => 'API 请求',
  };
}

int downloadThreadLimitForTest({
  required bool multiThreadDownload,
  required String maxDownloadThreads,
}) {
  if (!multiThreadDownload) {
    return 1;
  }
  final parsed = int.tryParse(maxDownloadThreads.trim()) ?? 1;
  return parsed.clamp(1, 32);
}

int downloadWorkerCountForTest({
  required int itemCount,
  required int threadLimit,
}) {
  if (itemCount <= 0 || threadLimit <= 0) {
    return 0;
  }
  return threadLimit < itemCount ? threadLimit : itemCount;
}

DownloadModeForTest downloadModeFromSettingForTest(
  String? value, {
  required DownloadModeForTest fallback,
}) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == 'zeyu' || normalized == 'zeyucache') {
    return DownloadModeForTest.zeyuCache;
  }
  return DownloadModeForTest.values.firstWhere(
    (mode) => mode.name.toLowerCase() == normalized,
    orElse: () => fallback,
  );
}

DownloadSourceForTest downloadSourceForTest({
  required DownloadModeForTest mode,
  required bool hasVersionHash,
}) {
  return switch (mode) {
    DownloadModeForTest.localCache => DownloadSourceForTest.localZipCache,
    DownloadModeForTest.zeyuCache when hasVersionHash =>
      DownloadSourceForTest.zeyuCache,
    DownloadModeForTest.zeyuCache ||
    DownloadModeForTest.api => DownloadSourceForTest.beatSaverApi,
  };
}

Uri zeyuCacheZipUriForTest(String hash) {
  return Uri.parse('https://beatsaver.wgzeyu.vip/cdn/${hash.trim()}.zip');
}

String batchInstallStatusForTest({
  required int installed,
  required int skipped,
  required int stopped,
  required int failed,
}) {
  return '批量完成：安装 $installed，跳过 $skipped，停止 $stopped，失败 $failed';
}

String batchInstallAutoPackStatusForTest({
  required int installed,
  required int skipped,
  required int failed,
  required String path,
}) {
  return '批量完成并已自动打包：安装 $installed，跳过 $skipped，失败 $failed，$path';
}

String zipDownloadStatusForTest({
  required int downloaded,
  required int skipped,
  required int stopped,
  required int failed,
}) {
  return '批量 ZIP 下载完成：下载 $downloaded，跳过 $skipped，停止 $stopped，失败 $failed';
}

String zipDownloadAutoExtractStatusForTest({
  required int downloaded,
  required int installed,
  required int skipped,
  required int failed,
}) {
  return '批量 ZIP 下载完成并已自动解压：下载 $downloaded，安装 $installed，'
      '跳过 $skipped，失败 $failed';
}

String saveSelectedActionLabelForTest({
  required bool saveSongList,
  required bool saveSongFiles,
}) {
  if (saveSongList && saveSongFiles) {
    return '保存本次歌曲列表并下载 ZIP';
  }
  if (saveSongList) {
    return '保存本次歌曲列表';
  }
  return '下载 ZIP';
}

String saveSelectedStatusForTest({
  required String? listPath,
  required bool saveSongFiles,
  required int downloaded,
  required int skipped,
  required int stopped,
  required int failed,
}) {
  final listPart = listPath == null ? '列表未保存' : '列表 $listPath';
  final zipPart = saveSongFiles
      ? 'ZIP 下载 $downloaded，跳过 $skipped，停止 $stopped，失败 $failed'
      : 'ZIP 未下载';
  return '保存完成：$listPart，$zipPart';
}

String saveSelectedAutoExtractStatusForTest({
  required String? listPath,
  required int downloaded,
  required int installed,
  required int skipped,
  required int failed,
}) {
  final listPart = listPath == null ? '列表未保存' : '列表 $listPath';
  return '保存完成并已自动解压：$listPart，ZIP 下载 $downloaded，'
      '安装 $installed，跳过 $skipped，失败 $failed';
}

String manualInstallStatusForTest({
  required int installed,
  required int skipped,
  required int stopped,
  required int failed,
}) {
  return '手动安装完成：安装 $installed，跳过 $skipped，停止 $stopped，失败 $failed';
}
