import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('reads and writes BeatSaver hash detail cache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_hash_cache_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file =
        File('${directory.path}${Platform.pathSeparator}hash_cache.json');
    var cache = BeatSaverHashCache.empty(now: DateTime(2026, 6, 10));
    cache = cache.put(
      'ABCDEF',
      const BeatSaverHashDetail(
        id: 'abc',
        name: 'Song',
        description: 'desc',
      ),
    );

    await writeBeatSaverHashCache(file, cache);
    final restored = await readBeatSaverHashCache(file);

    expect(restored.cacheDate, '2026-06-10');
    expect(restored.get('abcdef')?.id, 'abc');
    expect(restored.get('ABCDEF')?.name, 'Song');
    expect(restored.get('missing'), isNull);
  });

  test('returns an empty cache when hash cache file is missing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_missing_hash_cache_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final cache = await readBeatSaverHashCache(
      File('${directory.path}${Platform.pathSeparator}missing.json'),
    );

    expect(cache.data, isEmpty);
    expect(cache.cacheDate, isNotEmpty);
  });
}
