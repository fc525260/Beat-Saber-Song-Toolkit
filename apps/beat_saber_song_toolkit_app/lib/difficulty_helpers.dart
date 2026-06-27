import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

bool diffsContainAllComponentsForTest(
  List<BeatSaverDifficulty> diffs,
  Set<String> components,
) {
  return components.every(
    (component) =>
        diffs.any((diff) => diffHasComponentForTest(diff, component)),
  );
}

bool diffsContainAnyComponentForTest(
  List<BeatSaverDifficulty> diffs,
  Set<String> components,
) {
  return components.any(
    (component) =>
        diffs.any((diff) => diffHasComponentForTest(diff, component)),
  );
}

bool diffHasComponentForTest(BeatSaverDifficulty diff, String component) {
  return switch (component.toLowerCase()) {
    'chroma' => diff.chroma,
    'cinema' => diff.cinema,
    'me' || 'mappingextensions' || 'mapping-extensions' => diff.me,
    'ne' || 'noodle' || 'noodleextensions' || 'noodle-extensions' => diff.ne,
    'vivify' => diff.vivify,
    _ => false,
  };
}

bool difficultyMatchesForTest(BeatSaverDifficulty diff, String filter) {
  return difficultyLabelForTest(diff.difficulty).toLowerCase() ==
      difficultyLabelForTest(filter).toLowerCase();
}

bool diffsMatchDifficultiesForTest(
  List<BeatSaverDifficulty> diffs,
  Set<String> filters, {
  required bool matchAll,
}) {
  if (matchAll) {
    return filters.every(
      (filter) => diffs.any((diff) => difficultyMatchesForTest(diff, filter)),
    );
  }
  return filters.any(
    (filter) => diffs.any((diff) => difficultyMatchesForTest(diff, filter)),
  );
}

bool diffsMatchCharacteristicsForTest(
  List<BeatSaverDifficulty> diffs,
  Set<String> filters,
) {
  final normalizedFilters = filters.map(normalizeCharacteristicForTest).toSet();
  return diffs.any(
    (diff) => normalizedFilters.contains(
      normalizeCharacteristicForTest(diff.characteristic),
    ),
  );
}

String normalizeCharacteristicForTest(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  return switch (normalized) {
    'one' || 'onesaber' => 'onesaber',
    'noarrow' || 'noarrows' => 'noarrows',
    '90' || '90degree' => '90degree',
    '360' || '360degree' => '360degree',
    _ => normalized,
  };
}

bool hasAllStandardDifficultiesForTest(List<BeatSaverDifficulty> diffs) {
  final standardDifficulties = diffs
      .where((diff) => diff.characteristic.toLowerCase() == 'standard')
      .map((diff) => difficultyLabelForTest(diff.difficulty).toLowerCase())
      .toSet();
  return const {
    'easy',
    'normal',
    'hard',
    'expert',
    'expert+',
  }.every(standardDifficulties.contains);
}

double difficultyStarsForTest(BeatSaverDifficulty diff) {
  return diff.stars > 0 ? diff.stars : diff.blStars;
}

String difficultyLabelForTest(String value) {
  return switch (value.toLowerCase()) {
    'easy' => 'Easy',
    'normal' => 'Normal',
    'hard' => 'Hard',
    'expert' => 'Expert',
    'expertplus' || 'expert+' => 'Expert+',
    _ => value.isEmpty ? '未知' : value,
  };
}

int difficultyRankForTest(String value) {
  return switch (value.toLowerCase()) {
    'easy' => 0,
    'normal' => 1,
    'hard' => 2,
    'expert' => 3,
    'expert+' || 'expertplus' => 4,
    _ => 99,
  };
}

String characteristicLabelForTest(String value) {
  return switch (value.toLowerCase()) {
    'standard' => '标准',
    'onesaber' => '单手',
    'noarrows' => '无箭头',
    '360degree' => '360',
    '90degree' => '90',
    'lawless' => 'Lawless',
    'lightshow' => '灯光',
    _ => value,
  };
}
