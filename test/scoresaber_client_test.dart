import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('parses ScoreSaber map response into BeatSaver ids', () {
    final response = ScoreSaberMapsResponse.fromJson({
      'data': [
        {'bsid': '51d36', 'songName': 'Nine Circles'},
        {
          'map': {'bsid': '356af', 'songName': 'Fly'},
        },
        {'bsid': ' 5160e '},
        {'songName': 'missing id'},
        {'bsid': ''},
      ],
      'metadata': {'total': 123},
    });

    expect(response.beatSaverIds, ['51d36', '356af', '5160e']);
    expect(response.total, 123);
  });

  test('sends ScoreSaber star range and ranked parameters', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    final requests = <Uri>[];
    server.listen((request) {
      requests.add(request.uri);
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': [
              {'bsid': '51d36'},
            ],
            'metadata': {'total': 1},
          }),
        )
        ..close();
    });

    final client = ScoreSaberClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    final response = await client.maps(
      page: 2,
      minStar: 0,
      maxStar: 50,
      ranked: true,
    );

    expect(response.beatSaverIds, ['51d36']);
    expect(requests.single.path, '/api/v2/leaderboards');
    expect(requests.single.queryParameters, {
      'page': '2',
      'minStar': '0.0',
      'maxStar': '50.0',
      'ranked': 'true',
    });
  });
}
