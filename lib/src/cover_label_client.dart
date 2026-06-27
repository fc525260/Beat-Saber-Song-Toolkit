import 'dart:convert';
import 'dart:io';

class CoverLabelClient {
  CoverLabelClient({
    Uri? baseUri,
    HttpClient? httpClient,
  })  : _baseUri = baseUri ??
            Uri.parse('https://vision.googleapis.com/v1/images:annotate'),
        _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final HttpClient _httpClient;

  Future<List<CoverLabel>> detectLabels({
    required String imageUrl,
    required String apiKey,
  }) async {
    final uri = _baseUri.replace(
      queryParameters: {
        ..._baseUri.queryParameters,
        'key': apiKey,
      },
    );
    final request = await _httpClient.postUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(
      jsonEncode({
        'requests': [
          {
            'image': {
              'source': {'imageUri': imageUrl}
            },
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 20},
            ],
          },
        ],
      }),
    );

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GCP Vision request failed with HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object from GCP Vision.');
    }
    return parseCoverLabels(decoded);
  }
}

List<CoverLabel> parseCoverLabels(Map<String, dynamic> json) {
  final responses = json['responses'];
  if (responses is! List || responses.isEmpty) {
    return const [];
  }
  final first = responses.first;
  if (first is! Map<String, dynamic>) {
    return const [];
  }
  final annotations = first['labelAnnotations'];
  if (annotations is! List) {
    return const [];
  }
  return annotations
      .whereType<Map<String, dynamic>>()
      .map(CoverLabel.fromJson)
      .where((label) => label.description.isNotEmpty)
      .toList(growable: false);
}

class CoverLabel {
  const CoverLabel({
    required this.description,
    required this.score,
  });

  factory CoverLabel.fromJson(Map<String, dynamic> json) {
    return CoverLabel(
      description: json['description']?.toString() ?? '',
      score: _doubleValue(json['score']),
    );
  }

  final String description;
  final double score;

  Map<String, Object?> toJson() {
    return {
      'description': description,
      'score': score,
    };
  }
}

double _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
