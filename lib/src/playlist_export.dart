import 'dart:convert';
import 'dart:io';

import 'installed_library.dart';

class BplistPlaylist {
  const BplistPlaylist({
    required this.title,
    required this.entries,
  });

  final String title;

  final List<BplistSongEntry> entries;

  List<String> get mapIds => entries
      .map((entry) => entry.key)
      .where((key) => key.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

class BplistSongEntry {
  const BplistSongEntry({required this.key, required this.hash});

  final String key;
  final String hash;
}

List<String> favoriteHashesFromPlayerDataJson(Map<String, dynamic> json) {
  final players = json['localPlayers'];
  if (players is! List) {
    return const [];
  }

  final hashes = <String>{};
  for (final player in players) {
    if (player is! Map) {
      continue;
    }
    final favorites = player['favoritesLevelIds'];
    if (favorites is! List) {
      continue;
    }
    for (final favorite in favorites) {
      final hash = _favoriteHash(favorite?.toString() ?? '');
      if (hash.isNotEmpty) {
        hashes.add(hash);
      }
    }
  }
  return hashes.toList(growable: false);
}

Future<List<String>> readFavoriteHashesFromPlayerData(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected PlayerData JSON object.');
  }
  return favoriteHashesFromPlayerDataJson(decoded);
}

Future<File> exportFavoriteHashesBplist({
  required Iterable<String> hashes,
  required File outputFile,
  String playlistTitle = '导出收藏歌曲',
  String? playlistAuthor,
  String? playlistDescription,
  String? playlistImage,
}) async {
  final effectiveAuthor = playlistAuthor ?? '$playlistTitle - BSSFM@WGzeyu';
  final effectiveDescription = playlistDescription ??
      '该歌单由$effectiveAuthor使用BSSFM生成。\n'
          'BeatSaberSongFolderManager(BS歌曲路径管理器)是由WGzeyu制作的免费软件，禁止商用。\n'
          '项目地址：https://github.com/WGzeyu/Beat-Saber-Song-Folder-Manager';
  final songs = hashes
      .map(_favoriteHash)
      .where((hash) => hash.isNotEmpty)
      .toSet()
      .map((hash) => {'hash': hash})
      .toList(growable: false);

  final playlist = {
    'playlistTitle': playlistTitle,
    'playlistAuthor': effectiveAuthor,
    'PlaylistDescription': effectiveDescription,
    if (playlistImage != null && playlistImage.trim().isNotEmpty)
      'image': playlistImage.trim(),
    'songs': songs,
  };

  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(playlist),
    flush: true,
  );
  return outputFile;
}

Future<File> exportBplist({
  required Directory libraryDirectory,
  required File outputFile,
  required String playlistTitle,
  String? playlistAuthor,
  String? playlistDescription,
  String? playlistImage,
}) async {
  final effectiveAuthor =
      playlistAuthor ?? '$playlistTitle - BeatSpider@WGzeyu';
  final effectiveDescription = playlistDescription ??
      '该歌单由$effectiveAuthor使用BeatSpider生成。\n'
          'BeatSpider是由WGzeyu制作的用于生成与整理曲包的免费软件，禁止商用。\n'
          '项目地址：https://github.com/WGzeyu/BeatSpider';
  final entries = await scanInstalledLibrary(libraryDirectory);
  final effectivePlaylistImage =
      _nonEmpty(playlistImage) ?? await installedCoverImageDataUrl(entries);
  final songs = entries
      .where((entry) => entry.mapId != null && entry.hasInfoDat)
      .map(
        (entry) => {
          'key': entry.mapId,
          'songName': entry.title ?? entry.directoryName,
        },
      )
      .toList(growable: false);

  final playlist = {
    'playlistTitle': playlistTitle,
    'playlistAuthor': effectiveAuthor,
    'playlistDescription': effectiveDescription,
    if (effectivePlaylistImage != null) 'image': effectivePlaylistImage,
    'songs': songs,
  };

  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(playlist),
    flush: true,
  );
  return outputFile;
}

Future<File> exportBplistFromInstalledEntries({
  required Iterable<InstalledSongEntry> entries,
  required File outputFile,
  required String playlistTitle,
  String? playlistAuthor,
  String? playlistDescription,
  String? playlistImage,
}) async {
  final effectiveAuthor =
      playlistAuthor ?? '$playlistTitle - BeatSpider@WGzeyu';
  final effectiveDescription = playlistDescription ??
      '该歌单由$effectiveAuthor使用BeatSpider生成。\n'
          'BeatSpider是由WGzeyu制作的用于生成与整理曲包的免费软件，禁止商用。\n'
          '项目地址：https://github.com/WGzeyu/BeatSpider';
  final entryList = entries.toList(growable: false);
  final effectivePlaylistImage =
      _nonEmpty(playlistImage) ?? await installedCoverImageDataUrl(entryList);
  final songs = entryList
      .where((entry) => entry.mapId != null && entry.hasInfoDat)
      .map(
        (entry) => {
          'key': entry.mapId,
          'songName': entry.title ?? entry.directoryName,
        },
      )
      .toList(growable: false);

  final playlist = {
    'playlistTitle': playlistTitle,
    'playlistAuthor': effectiveAuthor,
    'playlistDescription': effectiveDescription,
    if (effectivePlaylistImage != null) 'image': effectivePlaylistImage,
    'songs': songs,
  };

  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(playlist),
    flush: true,
  );
  return outputFile;
}

Future<String?> installedCoverImageDataUrl(
  Iterable<InstalledSongEntry> entries,
) async {
  for (final entry in entries) {
    if (!entry.hasInfoDat || entry.mapId == null) {
      continue;
    }
    final filename = entry.info?.coverImageFilename.trim() ?? '';
    if (filename.isEmpty) {
      continue;
    }
    final mimeType = playlistImageMimeType(filename);
    if (mimeType == null) {
      continue;
    }
    final file = File(_safeChildPath(entry.directory, filename));
    if (!await file.exists()) {
      continue;
    }
    final bytes = await file.readAsBytes();
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
  return null;
}

String? playlistImageMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  return null;
}

Future<BplistPlaylist> readBplist(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected bplist JSON object.');
  }

  final songs = decoded['songs'];
  return BplistPlaylist(
    title: decoded['playlistTitle']?.toString() ?? '',
    entries: songs is List
        ? songs.whereType<Map<String, dynamic>>().map((song) {
            return BplistSongEntry(
              key: song['key']?.toString().trim() ?? '',
              hash: song['hash']?.toString().trim() ?? '',
            );
          }).toList(growable: false)
        : const [],
  );
}

String _favoriteHash(String value) {
  final normalized = value.trim().toLowerCase();
  final hash = normalized.startsWith('custom_level_')
      ? normalized.substring('custom_level_'.length)
      : normalized;
  return RegExp(r'^[0-9a-f]{40}$').hasMatch(hash) ? hash : '';
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _safeChildPath(Directory parent, String filename) {
  final basename = filename.replaceAll('\\', '/').split('/').last;
  return '${parent.path}${Platform.pathSeparator}$basename';
}
