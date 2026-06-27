import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:flutter/material.dart';

import 'difficulty_helpers.dart';
import 'output_helpers.dart';

class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.music_note,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (url.isEmpty) {
      return SizedBox(width: 48, height: 48, child: fallback);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class DifficultySummary extends StatelessWidget {
  const DifficultySummary({super.key, required this.diffs});

  final List<BeatSaverDifficulty> diffs;

  @override
  Widget build(BuildContext context) {
    if (diffs.isEmpty) {
      return Text(
        '难度：未知',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    final byCharacteristic = <String, List<BeatSaverDifficulty>>{};
    for (final diff in diffs) {
      final characteristic = diff.characteristic.isEmpty
          ? 'Standard'
          : diff.characteristic;
      byCharacteristic
          .putIfAbsent(characteristic, () => <BeatSaverDifficulty>[])
          .add(diff);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in byCharacteristic.entries)
          Tooltip(
            message: entry.value
                .map(
                  (diff) =>
                      '${difficultyLabelForTest(diff.difficulty)}  '
                      '${diff.label.isEmpty ? '' : '${diff.label}  '}'
                      'NPS ${diff.nps.toStringAsFixed(1)}  '
                      '${difficultyStarsForTest(diff) <= 0 ? '' : '星 ${difficultyStarsForTest(diff).toStringAsFixed(2)}  '}'
                      '方块 ${diff.notes}  '
                      '炸弹 ${diff.bombs}  '
                      '墙 ${diff.obstacles}  '
                      '校验 错${diff.parityErrors}/警${diff.parityWarns}/重${diff.parityResets}',
                )
                .join('\n'),
            child: Chip(
              label: Text(
                '${characteristicLabelForTest(entry.key)}: '
                '${difficultyLabelsForTest(entry.value).join('/')}',
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

class MapBadges extends StatelessWidget {
  const MapBadges({super.key, required this.map});

  final BeatSaverMap map;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      if (map.uploadedAt != null) '上传 ${exportDateForTest(map.uploadedAt!)}',
      if (map.ranked) 'Ranked',
      if (map.qualified) 'Qualified',
      if (map.curatedAt != null) '精选 ${exportDateForTest(map.curatedAt!)}',
      if (map.declaredAi != null &&
          map.declaredAi!.isNotEmpty &&
          map.declaredAi != 'None')
        'AI: ${map.declaredAi}',
      ...map.tags.take(4),
    ];

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in badges)
          Chip(label: Text(badge), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

List<String> difficultyLabelsForTest(List<BeatSaverDifficulty> diffs) {
  final labels = diffs
      .map((diff) => difficultyLabelForTest(diff.difficulty))
      .toSet()
      .toList(growable: false);
  labels.sort(
    (a, b) => difficultyRankForTest(a).compareTo(difficultyRankForTest(b)),
  );
  return labels;
}
