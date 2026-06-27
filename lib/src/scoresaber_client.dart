import 'dart:convert';
import 'dart:io';

class ScoreSaberClient {
  ScoreSaberClient({
    Uri? baseUri,
    HttpClient? httpClient,
  })  : _baseUri = baseUri ?? Uri.parse('https://scoresaber.com'),
        _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final HttpClient _httpClient;

  Future<ScoreSaberMapsResponse> maps({
    int page = 1,
    double? minStar,
    double? maxStar,
    bool? ranked,
  }) async {
    final query = <String, String>{'page': page.toString()};
    if (minStar != null) {
      query['minStar'] = minStar.toString();
    }
    if (maxStar != null) {
      query['maxStar'] = maxStar.toString();
    }
    if (ranked != null) {
      query['ranked'] = ranked.toString();
    }
    final uri = _baseUri.replace(
      path: '/api/v2/leaderboards',
      queryParameters: query,
    );
    final json = await _getJsonObject(uri);
    return ScoreSaberMapsResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJsonObject(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'ScoreSaber request failed with HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object from ScoreSaber.');
    }
    return decoded;
  }
}

class ScoreSaberMapsResponse {
  const ScoreSaberMapsResponse({
    required this.beatSaverIds,
    required this.total,
  });

  factory ScoreSaberMapsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final ids = <String>[];
    if (data is List) {
      for (final entry in data.whereType<Map<String, dynamic>>()) {
        final map = entry['map'];
        final id = (entry['bsid'] ?? (map is Map ? map['bsid'] : null))
                ?.toString()
                .trim() ??
            '';
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return ScoreSaberMapsResponse(
      beatSaverIds: ids,
      total: _intValue(
        json['metadata'] is Map<String, dynamic>
            ? (json['metadata'] as Map<String, dynamic>)['total']
            : json['total'],
      ),
    );
  }

  final List<String> beatSaverIds;
  final int total;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
