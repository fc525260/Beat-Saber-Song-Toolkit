import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'beatsaver_models.dart';
import 'installed_library.dart';
import 'search_options.dart';

class BeatSaverClient {
  BeatSaverClient({
    Uri? baseUri,
    HttpClient? httpClient,
    Duration? requestTimeout,
    int requestRetryCount = 0,
    String? userAgent,
    Duration? downloadTimeout,
    int downloadRetryCount = 0,
  })  : _baseUri = baseUri ?? Uri.parse('https://api.beatsaver.com'),
        _httpClient = httpClient ?? HttpClient(),
        _requestTimeout = requestTimeout,
        _requestRetryCount = requestRetryCount < 0 ? 0 : requestRetryCount,
        _userAgent = userAgent?.trim() ?? '',
        _downloadTimeout = downloadTimeout,
        _downloadRetryCount = downloadRetryCount < 0 ? 0 : downloadRetryCount;

  final Uri _baseUri;
  final HttpClient _httpClient;
  final Duration? _requestTimeout;
  final int _requestRetryCount;
  final String _userAgent;
  final Duration? _downloadTimeout;
  final int _downloadRetryCount;

  Future<BeatSaverSearchResponse> searchText(
    BeatSaverSearchOptions options,
  ) async {
    final uri = _buildUri(
      '/search/text/${options.page}',
      options.toQueryParameters(),
    );
    final json = await _getJsonObject(uri);
    return BeatSaverSearchResponse.fromJson(json);
  }

  Future<BeatSaverSearchResponse> searchUploaderMaps({
    required int uploaderId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = _buildUri('/maps/uploader/$uploaderId/$page', {
      'pageSize': pageSize.toString(),
    });
    final json = await _getJsonObject(uri);
    return BeatSaverSearchResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> getLatestMapsPageRaw({
    String? before,
    String? after,
    int pageSize = 100,
    String sort = 'UPDATED',
    bool? automapper,
  }) async {
    final safePageSize = pageSize.clamp(1, 100).toString();
    final query = <String, String>{
      'pageSize': safePageSize,
      if (sort.trim().isNotEmpty) 'sort': sort.trim(),
      if (before != null && before.trim().isNotEmpty) 'before': before.trim(),
      if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
      if (automapper != null) 'automapper': automapper.toString(),
    };
    final uri = _buildUri('/maps/latest', query);
    return _getJsonObject(uri);
  }

  Future<Map<String, dynamic>> getDeletedMapsPageRaw({
    String? before,
    String? after,
    int pageSize = 100,
  }) async {
    final safePageSize = pageSize.clamp(1, 100).toString();
    final query = <String, String>{
      'pageSize': safePageSize,
      if (before != null && before.trim().isNotEmpty) 'before': before.trim(),
      if (after != null && after.trim().isNotEmpty) 'after': after.trim(),
    };
    final uri = _buildUri('/maps/deleted', query);
    return _getJsonObject(uri);
  }

  Future<BeatSaverMap> getMapById(String id) async {
    final uri = _buildUri('/maps/id/$id');
    final json = await _getJsonObject(uri);
    return BeatSaverMap.fromJson(json);
  }

  Future<BeatSaverMap> getMapByHash(String hash) async {
    final uri = _buildUri('/maps/hash/$hash');
    final json = await _getJsonObject(uri);
    return BeatSaverMap.fromJson(json);
  }

  Future<BeatSaverUser> getUserById(int id) async {
    final uri = _buildUri('/users/id/$id');
    final json = await _getJsonObject(uri);
    return BeatSaverUser.fromJson(json);
  }

  Future<BeatSaverUser> getUserByName(String name) async {
    final uri = _baseUri.replace(pathSegments: ['users', 'name', name]);
    final json = await _getJsonObject(uri);
    return BeatSaverUser.fromJson(json);
  }

  Future<BeatSaverPlaylistPage> getPlaylistPage({
    required int playlistId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final uri = _buildUri('/playlists/id/$playlistId/$page', {
      'pageSize': pageSize.toString(),
    });
    final json = await _getJsonObject(uri);
    return BeatSaverPlaylistPage.fromJson(json);
  }

  Future<List<BeatSaverMap>> getMapsByIds(Iterable<String> ids) async {
    final normalizedIds = ids
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final maps = <BeatSaverMap>[];
    for (var index = 0; index < normalizedIds.length; index += 50) {
      final chunk = normalizedIds.skip(index).take(50).join(',');
      final uri = _buildUri('/maps/ids/$chunk');
      final json = await _getJsonObject(uri);
      maps.addAll(
        json.values
            .whereType<Map<String, dynamic>>()
            .map(BeatSaverMap.fromJson),
      );
    }
    return maps;
  }

  Future<File> downloadLatestVersion(
    BeatSaverMap map,
    Directory outputDirectory,
  ) async {
    final version = map.latestVersion;
    if (version == null || version.downloadUrl.isEmpty) {
      throw StateError('Map ${map.id} has no downloadable version.');
    }

    await outputDirectory.create(recursive: true);
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}${map.id}-${version.hash}.zip',
    );

    await _downloadToFile(Uri.parse(version.downloadUrl), file);
    return file;
  }

  Future<File> downloadLatestVersionFromUrl(
    BeatSaverMap map,
    Uri downloadUrl,
    Directory outputDirectory,
  ) async {
    final version = map.latestVersion;
    if (version == null || version.hash.isEmpty) {
      throw StateError('Map ${map.id} has no downloadable version.');
    }

    await outputDirectory.create(recursive: true);
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}${map.id}-${version.hash}.zip',
    );

    await _downloadToFile(downloadUrl, file);
    return file;
  }

  Future<Directory> installLatestVersion(
    BeatSaverMap map,
    Directory outputDirectory, {
    String? directoryNameTemplate,
    bool asciiDirectoryName = false,
  }) async {
    final installedDirectory = await findInstalledMapDirectory(
      map,
      outputDirectory,
    );
    if (installedDirectory != null) {
      return installedDirectory;
    }

    final tempDirectory =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_');
    try {
      final zipFile = await downloadLatestVersion(map, tempDirectory);
      final bytes = await zipFile.readAsBytes();
      final songDirectory = Directory(
        p.join(
          outputDirectory.path,
          installedSongDirectoryName(
            map,
            template: directoryNameTemplate,
            asciiOnly: asciiDirectoryName,
          ),
        ),
      );
      await songDirectory.create(recursive: true);
      await extractZipBytesToDirectory(bytes, songDirectory);
      return songDirectory;
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    return _baseUri.replace(
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _getJsonObject(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _requestRetryCount; attempt += 1) {
      try {
        return await _getJsonObjectOnce(uri);
      } catch (error) {
        lastError = error;
      }
    }
    Error.throwWithStackTrace(lastError!, StackTrace.current);
  }

  Future<Map<String, dynamic>> _getJsonObjectOnce(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (_userAgent.isNotEmpty) {
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    }

    final response = await request.close().timeoutOrSelf(_requestTimeout);
    final body = await utf8.decodeStream(response).timeoutOrSelf(
          _requestTimeout,
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'BeatSaver request failed with HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object from BeatSaver.');
    }
    return decoded;
  }

  Future<void> _downloadToFile(Uri uri, File file) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _downloadRetryCount; attempt += 1) {
      try {
        await _downloadToFileOnce(uri, file);
        return;
      } catch (error) {
        lastError = error;
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    Error.throwWithStackTrace(lastError!, StackTrace.current);
  }

  Future<void> _downloadToFileOnce(Uri uri, File file) async {
    final request = await _httpClient.getUrl(uri);
    final response = await request.close().timeoutOrSelf(_downloadTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decodeStream(response);
      throw HttpException(
        'BeatSaver download failed with HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }

    await response.pipe(file.openWrite()).timeoutOrSelf(_downloadTimeout);
  }
}

extension _TimeoutOrSelf<T> on Future<T> {
  Future<T> timeoutOrSelf(Duration? duration) {
    return duration == null ? this : timeout(duration);
  }
}

Future<Directory?> findInstalledMapDirectory(
  BeatSaverMap map,
  Directory outputDirectory, {
  Iterable<Directory> extraDirectories = const [],
}) async {
  final directories = [outputDirectory, ...extraDirectories];
  for (final directory in directories) {
    final found = await _findInstalledMapDirectoryIn(map, directory);
    if (found != null) {
      return found;
    }
  }

  return null;
}

Future<Directory?> _findInstalledMapDirectoryIn(
  BeatSaverMap map,
  Directory directory,
) async {
  if (!await directory.exists()) {
    return null;
  }

  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final name = p.basename(entity.path);
    final parsed = parseInstalledDirectoryName(name);
    if (parsed.mapId?.toLowerCase() != map.id.toLowerCase()) {
      continue;
    }
    if (await containsInfoDat(entity)) {
      return entity;
    }
  }

  return null;
}

String installedSongDirectoryName(
  BeatSaverMap map, {
  String? template,
  bool asciiOnly = false,
}) {
  final title =
      map.metadata.songName.isNotEmpty ? map.metadata.songName : map.name;
  final rawName =
      (template == null || template.trim().isEmpty ? '[id] - [歌名]' : template)
          .replaceAll('[id]', map.id)
          .replaceAll('[bsr]', map.id)
          .replaceAll('[歌名]', title)
          .replaceAll('[song]', title)
          .replaceAll('[歌曲]', title)
          .replaceAll('[作者]', map.metadata.songAuthorName)
          .replaceAll('[artist]', map.metadata.songAuthorName)
          .replaceAll('[制作者]', map.metadata.levelAuthorName)
          .replaceAll('[mapper]', map.metadata.levelAuthorName)
          .replaceAll('[bpm]', _formatBpm(map.metadata.bpm));
  final baseName =
      asciiOnly ? rawName.replaceAll(RegExp(r'[^\x20-\x7E]'), '_') : rawName;
  final safeName =
      baseName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  return safeName.isEmpty ? 'Untitled' : safeName;
}

String _formatBpm(double bpm) {
  if (bpm <= 0) {
    return '';
  }
  return bpm == bpm.roundToDouble() ? bpm.toInt().toString() : bpm.toString();
}

class ZipFileEntry {
  const ZipFileEntry({
    required this.relativePath,
    required this.bytes,
  });

  final String relativePath;
  final List<int> bytes;
}

List<ZipFileEntry> decodeZipFileEntries(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final entries = <ZipFileEntry>[];

  for (final entry in archive) {
    if (!entry.isFile) {
      continue;
    }
    entries.add(
      ZipFileEntry(
        relativePath: _safeArchiveRelativePath(entry.name),
        bytes: entry.content as List<int>,
      ),
    );
  }

  return entries;
}

Future<void> extractZipBytesToDirectory(
  List<int> bytes,
  Directory outputDirectory,
) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  final root = p.normalize(p.absolute(outputDirectory.path));

  for (final entry in archive) {
    final safePath = _resolveArchivePath(root, entry.name);
    if (entry.isFile) {
      final file = File(safePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content as List<int>, flush: true);
    } else {
      await Directory(safePath).create(recursive: true);
    }
  }
}

String _safeArchiveRelativePath(String entryName) {
  final normalized = p.url.normalize(entryName.replaceAll(r'\', '/'));
  if (normalized == '.' ||
      normalized.startsWith('../') ||
      normalized == '..' ||
      p.url.isAbsolute(normalized)) {
    throw FormatException('Blocked unsafe archive path: $entryName');
  }
  return normalized;
}

String _resolveArchivePath(String root, String entryName) {
  final resolvedEntry = p.normalize(p.absolute(p.join(root, entryName)));
  if (!p.isWithin(root, resolvedEntry) && resolvedEntry != root) {
    throw FormatException('Blocked unsafe archive path: $entryName');
  }
  return resolvedEntry;
}
