import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

import 'status_helpers.dart';

enum ResultSourceForTest {
  textSearch,
  uploader,
  scoreSaber,
  beastSaber,
  localCache,
}

enum GoToPageActionForTest {
  search,
  searchUploader,
  searchScoreSaber,
  searchBeastSaber,
  showLocalCachePage,
}

class UploaderQueryForTest {
  const UploaderQueryForTest({required this.input, required this.uploaderId});

  final String input;
  final int? uploaderId;

  String get name => uploaderId == null ? input : '';

  bool get isEmpty => input.isEmpty;
}

GoToPageActionForTest goToPageActionForTest(ResultSourceForTest source) {
  return switch (source) {
    ResultSourceForTest.textSearch => GoToPageActionForTest.search,
    ResultSourceForTest.uploader => GoToPageActionForTest.searchUploader,
    ResultSourceForTest.scoreSaber => GoToPageActionForTest.searchScoreSaber,
    ResultSourceForTest.beastSaber => GoToPageActionForTest.searchBeastSaber,
    ResultSourceForTest.localCache => GoToPageActionForTest.showLocalCachePage,
  };
}

UploaderQueryForTest uploaderQueryForTest(String input) {
  final trimmed = input.trim();
  return UploaderQueryForTest(
    input: trimmed,
    uploaderId: int.tryParse(trimmed),
  );
}

String formatDurationForTest(int seconds) {
  if (seconds <= 0) {
    return '未知时长';
  }
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

String formatDownloadsForTest(int downloads) {
  return downloads <= 0 ? '下载量未提供' : '下载 $downloads';
}

String searchOrderLabelForTest(BeatSaverSearchOrder order) {
  return switch (order) {
    BeatSaverSearchOrder.latest => '最新',
    BeatSaverSearchOrder.relevance => '相关',
    BeatSaverSearchOrder.rating => '评分',
    BeatSaverSearchOrder.curated => '精选',
    BeatSaverSearchOrder.random => '随机',
    BeatSaverSearchOrder.duration => '时长',
  };
}

Uri beastSaberPageUrlForTest(String firstPageUrl, int pageNumber) {
  final uri = Uri.parse(firstPageUrl.trim());
  if (pageNumber <= 1) {
    return uri;
  }

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: true);
  final pageIndex = segments.indexWhere(
    (segment) => segment.toLowerCase() == 'page',
  );
  if (pageIndex >= 0 && pageIndex + 1 < segments.length) {
    segments[pageIndex + 1] = pageNumber.toString();
  } else {
    segments.addAll(['page', pageNumber.toString()]);
  }
  return uri.replace(pathSegments: segments);
}

List<String> parseBeastSaberPreviewHashesForTest(String html) {
  final hashes = <String>{};
  final pattern = RegExp(r'https://cdn\.beatsaver\.com/([0-9a-fA-F]{40})\.mp3');
  for (final match in pattern.allMatches(html)) {
    hashes.add(match.group(1)!.toUpperCase());
  }
  return hashes.toList(growable: false);
}

List<String> parseBeatSaverIdsForTest(String input) {
  final ids = <String>[];
  final seen = <String>{};
  final tokens = input.split(RegExp(r'[\s,;，；]+'));
  for (final token in tokens) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final uri = Uri.tryParse(trimmed);
    final segments = uri?.pathSegments ?? const <String>[];
    String id;
    if (segments.length >= 2 && segments[segments.length - 2] == 'maps') {
      id = segments.last;
    } else if (segments.length >= 3 &&
        segments[segments.length - 3] == 'maps' &&
        segments[segments.length - 2] == 'id') {
      id = segments.last;
    } else {
      id = trimmed;
    }
    if (!RegExp(r'^[0-9a-fA-F]{1,8}$').hasMatch(id)) {
      continue;
    }
    final normalized = id.toLowerCase();
    if (seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    ids.add(normalized);
  }
  return ids;
}

int? parseBeatSaverPlaylistIdForTest(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final directId = int.tryParse(trimmed);
  if (directId != null) {
    return directId;
  }
  final uri = Uri.tryParse(trimmed);
  final segments = uri?.pathSegments ?? const <String>[];
  for (var index = 0; index < segments.length - 2; index += 1) {
    if (segments[index].toLowerCase() == 'playlists' &&
        segments[index + 1].toLowerCase() == 'id') {
      return int.tryParse(segments[index + 2]);
    }
  }
  for (var index = 0; index < segments.length - 1; index += 1) {
    if (segments[index].toLowerCase() == 'playlists') {
      return int.tryParse(segments[index + 1]);
    }
  }
  return null;
}

String resultPageStatusForTest({
  String prefix = '',
  required int pageNumber,
  required int returnedCount,
  required int filteredCount,
}) {
  return filteredCount == returnedCount
      ? '$prefix第 $pageNumber 页：$returnedCount 张谱面'
      : '$prefix第 $pageNumber 页：返回 $returnedCount 张，筛选后 $filteredCount 张';
}

String sourcePageStatusForTest({
  required String sourceName,
  required int pageNumber,
  required int visibleCount,
  required int failed,
}) {
  return failed == 0
      ? '$sourceName 第 $pageNumber 页：$visibleCount 张谱面'
      : '$sourceName 第 $pageNumber 页：显示 $visibleCount 张，失败 $failed';
}

String playlistImportStatusForTest({
  required String name,
  required int loadedCount,
  required int filteredCount,
}) {
  return filteredCount == loadedCount
      ? '在线歌单 $name：已加入 $filteredCount 首到本次'
      : '在线歌单 $name：读取 $loadedCount 首，筛选后加入 $filteredCount 首';
}

Future<String?> playlistImportProblemForTest(String playlistPath) async {
  final path = playlistPath.trim();
  if (path.isEmpty) {
    return requireActionStatusForTest('选择歌单文件');
  }
  if (await FileSystemEntity.type(path) != FileSystemEntityType.file) {
    return '歌单文件不存在或不是文件：$path';
  }
  try {
    final playlist = await readBplist(File(path));
    if (playlist.entries.isEmpty) {
      return '歌单文件没有可导入歌曲：$path';
    }
  } catch (error) {
    return '歌单文件格式无效：$path，$error';
  }
  return null;
}
