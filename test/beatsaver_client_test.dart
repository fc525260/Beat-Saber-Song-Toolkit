import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('retries API requests and sends user agent', () async {
    var requests = 0;
    final userAgents = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) {
      requests += 1;
      userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
      if (requests == 1) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('temporary failure');
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_testMapJson()));
      }
      request.response.close();
    });

    final client = BeatSaverClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
      requestRetryCount: 1,
      userAgent: 'BeatSaberSongToolkitTest',
    );
    final map = await client.getMapById('abc');

    expect(map.id, 'abc');
    expect(requests, 2);
    expect(
        userAgents, ['BeatSaberSongToolkitTest', 'BeatSaberSongToolkitTest']);
  });

  test('requests latest maps with pagination parameters', () async {
    Uri? requestedUri;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) {
      requestedUri = request.uri;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'docs': []}));
      request.response.close();
    });

    final client = BeatSaverClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    final page = await client.getLatestMapsPageRaw(
      before: '2026-06-17T10:00:00+00:00',
      pageSize: 500,
      sort: 'UPDATED',
      automapper: false,
    );

    expect(page['docs'], isEmpty);
    expect(requestedUri?.path, '/maps/latest');
    expect(
        requestedUri?.queryParameters['before'], '2026-06-17T10:00:00+00:00');
    expect(requestedUri?.queryParameters['pageSize'], '100');
    expect(requestedUri?.queryParameters['sort'], 'UPDATED');
    expect(requestedUri?.queryParameters['automapper'], 'false');
  });

  test('requests deleted maps with pagination parameters', () async {
    Uri? requestedUri;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) {
      requestedUri = request.uri;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'docs': []}));
      request.response.close();
    });

    final client = BeatSaverClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    final page = await client.getDeletedMapsPageRaw(
      before: '2026-06-17T10:00:00+00:00',
      after: '2026-06-01T10:00:00+00:00',
      pageSize: 500,
    );

    expect(page['docs'], isEmpty);
    expect(requestedUri?.path, '/maps/deleted');
    expect(
        requestedUri?.queryParameters['before'], '2026-06-17T10:00:00+00:00');
    expect(requestedUri?.queryParameters['after'], '2026-06-01T10:00:00+00:00');
    expect(requestedUri?.queryParameters['pageSize'], '100');
  });

  test('retries failed ZIP downloads', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) {
      requests += 1;
      if (requests == 1) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('temporary failure');
      } else {
        request.response.add([1, 2, 3, 4]);
      }
      request.response.close();
    });

    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final client = BeatSaverClient(downloadRetryCount: 1);
    final file = await client.downloadLatestVersion(
      _testMap(
        downloadUrl:
            'http://${server.address.host}:${server.port}/download.zip',
      ),
      tempDir,
    );

    expect(requests, 2);
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
  });

  test('downloads ZIP from the map download URL', () async {
    Uri? requestedUri;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) {
      requestedUri = request.uri;
      request.response.add([9, 10, 11, 12]);
      request.response.close();
    });

    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final client = BeatSaverClient();
    final file = await client.downloadLatestVersion(
      _testMap(
        downloadUrl:
            'http://${server.address.host}:${server.port}/api/download.zip',
      ),
      tempDir,
    );

    expect(requestedUri?.path, '/api/download.zip');
    expect(await file.readAsBytes(), [9, 10, 11, 12]);
  });

  test('downloads ZIP from an explicit mirror URL', () async {
    Uri? requestedUri;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) {
      requestedUri = request.uri;
      request.response.add([5, 6, 7, 8]);
      request.response.close();
    });

    final tempDir =
        await Directory.systemTemp.createTemp('beat_saber_song_toolkit_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final client = BeatSaverClient();
    final file = await client.downloadLatestVersionFromUrl(
      _testMap(downloadUrl: 'http://example.invalid/original.zip'),
      Uri.parse('http://${server.address.host}:${server.port}/mirror/hash.zip'),
      tempDir,
    );

    expect(requestedUri?.path, '/mirror/hash.zip');
    expect(await file.readAsBytes(), [5, 6, 7, 8]);
  });

  test('downloads a ZIP and extracts it into the installed library', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'Info.dat',
          26,
          utf8.encode('{"_songName":"Zip Song"}'),
        ),
      )
      ..addFile(ArchiveFile('song.egg', 5, utf8.encode('audio')));
    final zipBytes = ZipEncoder().encode(archive);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      request.response.add(zipBytes);
      request.response.close();
    });

    final downloadDir = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_download_',
    );
    final libraryDir = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_library_',
    );
    addTearDown(() async {
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      if (await libraryDir.exists()) {
        await libraryDir.delete(recursive: true);
      }
    });

    final map = _testMap(
      downloadUrl: 'http://${server.address.host}:${server.port}/map.zip',
    );
    final client = BeatSaverClient();
    final zipFile = await client.downloadLatestVersion(map, downloadDir);

    final songDirectory = Directory(
      '${libraryDir.path}${Platform.pathSeparator}'
      '${installedSongDirectoryName(map)}',
    );
    await songDirectory.create(recursive: true);
    await extractZipBytesToDirectory(
        await zipFile.readAsBytes(), songDirectory);
    final installed = await scanInstalledLibrary(libraryDir);

    expect(await zipFile.exists(), isTrue);
    expect(installed, hasLength(1));
    expect(installed.single.mapId, 'abc');
    expect(installed.single.hasInfoDat, isTrue);
    expect(installed.single.title, 'Zip Song');
  });
}

Map<String, Object?> _testMapJson() {
  return {
    'id': 'abc',
    'name': 'Song',
    'description': '',
    'metadata': {
      'songName': 'Song',
      'songAuthorName': 'Artist',
      'levelAuthorName': 'Mapper',
    },
    'stats': {},
    'versions': [],
  };
}

BeatSaverMap _testMap({required String downloadUrl}) {
  return BeatSaverMap(
    id: 'abc',
    name: 'Song',
    description: '',
    metadata: const BeatSaverMetadata(
      songName: 'Song',
      songSubName: '',
      songAuthorName: 'Artist',
      levelAuthorName: 'Mapper',
      bpm: 180,
      durationSeconds: 120,
    ),
    stats: const BeatSaverStats(
      downloads: 0,
      plays: 0,
      upvotes: 0,
      downvotes: 0,
      score: 0,
      reviews: 0,
    ),
    versions: [
      BeatSaverVersion(
        hash: 'hash',
        state: 'Published',
        createdAt: DateTime(2026),
        downloadUrl: downloadUrl,
        coverUrl: '',
        previewUrl: '',
        sageScore: 0,
        diffs: const [],
      ),
    ],
  );
}
