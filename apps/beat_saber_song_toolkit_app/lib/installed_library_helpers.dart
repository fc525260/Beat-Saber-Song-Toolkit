import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

enum InstalledFilterModeForTest { all, normal, missingInfo, missingId }

class InstalledEntrySnapshotForTest {
  const InstalledEntrySnapshotForTest({
    required this.mapId,
    required this.title,
    required this.songAuthor,
    required this.levelAuthor,
    required this.hasInfoDat,
    required this.directoryName,
    required this.path,
    this.hasAudioFile = false,
  });

  final String mapId;
  final String title;
  final String songAuthor;
  final String levelAuthor;
  final bool hasInfoDat;
  final bool hasAudioFile;
  final String directoryName;
  final String path;
}

class InstalledSummaryForTest {
  const InstalledSummaryForTest({
    required this.total,
    required this.filtered,
    required this.normal,
    required this.missingInfo,
    required this.missingInfoWithAudio,
    required this.missingId,
  });

  final int total;
  final int filtered;
  final int normal;
  final int missingInfo;
  final int missingInfoWithAudio;
  final int missingId;

  String get totalLabel => '总数 $total';

  String get filteredLabel => '当前 $filtered';

  String get normalLabel => '正常 $normal';

  String get missingInfoLabel => '缺少 info.dat $missingInfo';

  String get missingInfoWithAudioLabel => '缺 info 但有音频 $missingInfoWithAudio';

  String get missingIdLabel => '无法识别 ID $missingId';
}

InstalledEntrySnapshotForTest installedEntrySnapshotForTest(
  InstalledSongEntry entry,
) {
  return InstalledEntrySnapshotForTest(
    mapId: entry.mapId ?? '',
    title: entry.title ?? '',
    songAuthor: entry.info?.songAuthorName ?? '',
    levelAuthor: entry.info?.levelAuthorName ?? '',
    hasInfoDat: entry.hasInfoDat,
    hasAudioFile: entry.hasAudioFile,
    directoryName: entry.directoryName,
    path: entry.directory.path,
  );
}

InstalledSummaryForTest installedSummaryForTest(
  Iterable<InstalledEntrySnapshotForTest> entries, {
  required int filteredCount,
}) {
  var total = 0;
  var normal = 0;
  var missingInfo = 0;
  var missingInfoWithAudio = 0;
  var missingId = 0;
  for (final entry in entries) {
    total += 1;
    if (entry.hasInfoDat) {
      normal += 1;
    } else {
      missingInfo += 1;
      if (entry.hasAudioFile) {
        missingInfoWithAudio += 1;
      }
    }
    if (entry.mapId.trim().isEmpty) {
      missingId += 1;
    }
  }
  return InstalledSummaryForTest(
    total: total,
    filtered: filteredCount < 0 ? 0 : filteredCount,
    normal: normal,
    missingInfo: missingInfo,
    missingInfoWithAudio: missingInfoWithAudio,
    missingId: missingId,
  );
}

String installedExportListForTest(
  Iterable<InstalledEntrySnapshotForTest> entries,
) {
  return entries.map(installedExportLineForTest).join('\n');
}

String installedExportLineForTest(InstalledEntrySnapshotForTest entry) {
  final fields = [
    entry.mapId,
    entry.title,
    entry.songAuthor,
    entry.levelAuthor,
    installedEntryStatusLabelForTest(entry),
    entry.directoryName,
    entry.path,
  ].map((value) => value.replaceAll(RegExp(r'[\r\n\t]+'), ' '));
  return fields.join('\t');
}

String installedEntryStatusLabelForTest(InstalledEntrySnapshotForTest entry) {
  if (entry.hasInfoDat) {
    return '正常';
  }
  return entry.hasAudioFile ? '缺少 info.dat，有音频' : '缺少 info.dat';
}

String installedFilterModeLabelForTest(InstalledFilterModeForTest mode) {
  return switch (mode) {
    InstalledFilterModeForTest.all => '全部',
    InstalledFilterModeForTest.normal => '正常',
    InstalledFilterModeForTest.missingInfo => '缺少 info.dat',
    InstalledFilterModeForTest.missingId => '无法识别 ID',
  };
}

List<InstalledSongEntry> filterInstalledEntriesForTest(
  List<InstalledSongEntry> entries, {
  required Set<String> tokens,
  required InstalledFilterModeForTest mode,
}) {
  return entries
      .where((entry) {
        final modeMatched = switch (mode) {
          InstalledFilterModeForTest.all => true,
          InstalledFilterModeForTest.normal => entry.hasInfoDat,
          InstalledFilterModeForTest.missingInfo => !entry.hasInfoDat,
          InstalledFilterModeForTest.missingId =>
            entry.mapId == null || entry.mapId!.isEmpty,
        };
        if (!modeMatched) {
          return false;
        }
        if (tokens.isEmpty) {
          return true;
        }
        final haystack = [
          entry.mapId ?? '',
          entry.title ?? '',
          entry.directoryName,
          entry.info?.songName ?? '',
          entry.info?.songAuthorName ?? '',
          entry.info?.levelAuthorName ?? '',
        ].join(' ').toLowerCase();
        return tokens.every(haystack.contains);
      })
      .toList(growable: false);
}

enum InstalledPathCorrectionFilterMode { abnormal, template, all }

String installedPathCorrectionFilterModeLabelForTest(
  InstalledPathCorrectionFilterMode mode,
) {
  return switch (mode) {
    InstalledPathCorrectionFilterMode.abnormal => '异常优先',
    InstalledPathCorrectionFilterMode.template => '命名模板差异',
    InstalledPathCorrectionFilterMode.all => '全部',
  };
}

List<InstalledPathCorrection> filterInstalledPathCorrectionsForTest(
  Iterable<InstalledPathCorrection> corrections,
  InstalledPathCorrectionFilterMode mode,
) {
  return corrections
      .where((correction) {
        final abnormal = installedPathCorrectionIsAbnormalForTest(correction);
        return switch (mode) {
          InstalledPathCorrectionFilterMode.abnormal => abnormal,
          InstalledPathCorrectionFilterMode.template => !abnormal,
          InstalledPathCorrectionFilterMode.all => true,
        };
      })
      .toList(growable: false);
}

bool installedPathCorrectionIsAbnormalForTest(
  InstalledPathCorrection correction,
) {
  final entry = correction.entry;
  return !entry.hasInfoDat || (entry.mapId ?? '').trim().isEmpty;
}

String installedPathCorrectionKeyForTest(InstalledPathCorrection correction) {
  return '${correction.entry.directory.path}\n'
          '${correction.expectedDirectoryName}'
      .toLowerCase();
}

String installedDuplicateEntryKeyForTest(InstalledSongEntry entry) {
  return entry.directory.path.toLowerCase();
}

String installedDuplicateKindLabelForTest(InstalledDuplicateKind kind) {
  return switch (kind) {
    InstalledDuplicateKind.mapId => 'ID重复',
    InstalledDuplicateKind.songName => '歌名重复',
  };
}
