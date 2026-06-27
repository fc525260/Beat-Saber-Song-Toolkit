import 'dart:convert';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

import 'input_parsing_helpers.dart';

bool coverLabelsMatchForTest(
  List<CoverLabel> labels, {
  required Set<String> includeTags,
  required Set<String> excludeTags,
  required double includeConfidence,
  required double excludeConfidence,
  required bool includeMatchAll,
  required bool excludeMatchAll,
}) {
  final normalized = labels
      .map(
        (label) => _CoverLabelMatch(
          description: label.description.toLowerCase(),
          score: label.score,
        ),
      )
      .toList(growable: false);
  final includeMatched =
      includeTags.isEmpty ||
      (includeMatchAll
          ? includeTags.every(
              (tag) => _coverTagMatched(normalized, tag, includeConfidence),
            )
          : includeTags.any(
              (tag) => _coverTagMatched(normalized, tag, includeConfidence),
            ));
  if (!includeMatched) {
    return false;
  }
  final excludeMatched =
      excludeTags.isNotEmpty &&
      (excludeMatchAll
          ? excludeTags.every(
              (tag) => _coverTagMatched(normalized, tag, excludeConfidence),
            )
          : excludeTags.any(
              (tag) => _coverTagMatched(normalized, tag, excludeConfidence),
            ));
  return !excludeMatched;
}

Future<List<BeatSaverMap>> filterCoverLabelsWithFallbackForTest(
  List<BeatSaverMap> maps, {
  required String token,
  required Set<String> includeTags,
  required Set<String> excludeTags,
  required double includeConfidence,
  required double excludeConfidence,
  required bool includeMatchAll,
  required bool excludeMatchAll,
  required bool waitOnFailure,
  required Map<String, List<CoverLabel>> labelCache,
  required Future<List<CoverLabel>> Function(String coverUrl, String token)
  detectLabels,
  required Future<List<CoverLabel>> Function(BeatSaverMap map) promptLabels,
  Future<void> Function()? onCacheChanged,
  void Function(BeatSaverMap map, Object error)? onError,
}) async {
  final filtered = <BeatSaverMap>[];
  for (final map in maps) {
    final coverUrl = map.latestVersion?.coverUrl ?? '';
    if (coverUrl.isEmpty) {
      filtered.add(map);
      continue;
    }
    try {
      final labels = await detectLabels(coverUrl, token);
      if (coverLabelsMatchForTest(
        labels,
        includeTags: includeTags,
        excludeTags: excludeTags,
        includeConfidence: includeConfidence,
        excludeConfidence: excludeConfidence,
        includeMatchAll: includeMatchAll,
        excludeMatchAll: excludeMatchAll,
      )) {
        filtered.add(map);
      }
    } catch (error) {
      onError?.call(map, error);
      if (!waitOnFailure) {
        continue;
      }
      final labels = await promptLabels(map);
      if (labels.isEmpty) {
        continue;
      }
      labelCache[coverUrl] = labels;
      await onCacheChanged?.call();
      if (coverLabelsMatchForTest(
        labels,
        includeTags: includeTags,
        excludeTags: excludeTags,
        includeConfidence: includeConfidence,
        excludeConfidence: excludeConfidence,
        includeMatchAll: includeMatchAll,
        excludeMatchAll: excludeMatchAll,
      )) {
        filtered.add(map);
      }
    }
  }
  return filtered;
}

String coverLabelCacheJsonForTest(Map<String, List<CoverLabel>> cache) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(
    cache.map(
      (url, labels) =>
          MapEntry(url, labels.map((label) => label.toJson()).toList()),
    ),
  );
}

List<CoverLabel> manualCoverLabelsForTest(String? input) {
  return splitFilterTokensForTest(input ?? '')
      .map((tag) => CoverLabel(description: tag, score: 1.0))
      .toList(growable: false);
}

bool tagsMatchForTest(
  Iterable<String> tags, {
  required bool untaggedOnly,
  required Set<String> includeTags,
  required Set<String> excludeTags,
}) {
  final mapTags = tags.map((tag) => tag.toLowerCase()).toSet();
  if (untaggedOnly && mapTags.isNotEmpty) {
    return false;
  }
  if (includeTags.any((tag) => !mapTags.contains(tag.toLowerCase()))) {
    return false;
  }
  if (excludeTags.map((tag) => tag.toLowerCase()).any(mapTags.contains)) {
    return false;
  }
  return true;
}

bool _coverTagMatched(
  List<_CoverLabelMatch> labels,
  String tag,
  double minScore,
) {
  final normalizedTag = tag.toLowerCase();
  return labels.any(
    (label) =>
        label.score >= minScore && label.description.contains(normalizedTag),
  );
}

class _CoverLabelMatch {
  const _CoverLabelMatch({required this.description, required this.score});

  final String description;
  final double score;
}
