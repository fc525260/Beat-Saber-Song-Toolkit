import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('parses GCP Vision label annotations', () {
    final labels = parseCoverLabels({
      'responses': [
        {
          'labelAnnotations': [
            {'description': 'Anime', 'score': 0.91},
            {'description': 'Game', 'score': 0.75},
          ],
        },
      ],
    });

    expect(labels.map((label) => label.description), ['Anime', 'Game']);
    expect(labels.first.score, 0.91);
  });

  test('sends GCP Vision label detection requests', () async {
    Uri? requestedUri;
    Map<String, dynamic>? requestJson;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      requestedUri = request.uri;
      requestJson =
          jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'responses': [
            {
              'labelAnnotations': [
                {'description': 'Illustration', 'score': 0.88},
              ],
            },
          ],
        }),
      );
      await request.response.close();
    });

    final client = CoverLabelClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}/vision'),
    );
    final labels = await client.detectLabels(
      imageUrl: 'https://example.invalid/cover.jpg',
      apiKey: 'test-key',
    );

    expect(requestedUri?.path, '/vision');
    expect(requestedUri?.queryParameters['key'], 'test-key');
    final requests = requestJson?['requests'] as List<dynamic>;
    final first = requests.single as Map<String, dynamic>;
    expect(
      (first['image'] as Map<String, dynamic>)['source'],
      {'imageUri': 'https://example.invalid/cover.jpg'},
    );
    expect(
      first['features'],
      [
        {'type': 'LABEL_DETECTION', 'maxResults': 20},
      ],
    );
    expect(labels.single.description, 'Illustration');
    expect(labels.single.score, 0.88);
  });
}
