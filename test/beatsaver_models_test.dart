import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('parses a minimal BeatSaver search response', () {
    final response = BeatSaverSearchResponse.fromJson({
      'docs': [
        {
          'id': 'abc',
          'name': 'Song - Artist',
          'description': 'Example map',
          'uploader': {'id': 42, 'name': 'mapper'},
          'metadata': {
            'songName': 'Song',
            'songSubName': '',
            'songAuthorName': 'Artist',
            'levelAuthorName': 'Mapper',
            'bpm': 180,
            'duration': 123,
          },
          'stats': {
            'downloads': 10,
            'plays': 20,
            'upvotes': 8,
            'downvotes': 1,
            'score': 0.88,
            'reviews': 2,
          },
          'uploaded': '2025-01-02T00:00:00Z',
          'ranked': true,
          'qualified': false,
          'tags': ['electronic', 'speed'],
          'versions': [
            {
              'hash': 'ABCDEF',
              'state': 'Published',
              'createdAt': '2025-01-01T00:00:00Z',
              'downloadURL': 'https://example.com/map.zip',
              'coverURL': 'https://example.com/cover.jpg',
              'previewURL': 'https://example.com/preview.mp3',
              'sageScore': 79,
              'diffs': [
                {
                  'characteristic': 'Standard',
                  'difficulty': 'ExpertPlus',
                  'njs': 20,
                  'nps': 5.2,
                  'notes': 1000,
                  'bombs': 3,
                  'obstacles': 12,
                  'events': 456,
                  'offset': 0.35,
                  'maxScore': 987654,
                  'chroma': true,
                  'cinema': false,
                  'me': true,
                  'ne': true,
                  'vivify': false,
                  'length': 200,
                  'seconds': 120.5,
                  'label': 'Challenge',
                  'stars': 8.12,
                  'blStars': 8.34,
                  'paritySummary': {
                    'errors': 1,
                    'warns': 2,
                    'resets': 3,
                  },
                }
              ],
            }
          ],
        }
      ],
      'info': {
        'total': 1,
        'page': 0,
        'itemsPerPage': 20,
      },
    });

    expect(response.metadata.total, 1);
    expect(response.maps.single.id, 'abc');
    expect(response.maps.single.metadata.songName, 'Song');
    expect(response.maps.single.uploaderId, 42);
    expect(response.maps.single.uploadedAt, DateTime.utc(2025, 1, 2));
    expect(response.maps.single.ranked, isTrue);
    expect(response.maps.single.stats.reviews, 2);
    expect(response.maps.single.tags, ['electronic', 'speed']);
    expect(response.maps.single.latestVersion?.hash, 'ABCDEF');
    expect(
      response.maps.single.latestVersion?.diffs.single.difficulty,
      'ExpertPlus',
    );
    expect(response.maps.single.latestVersion?.diffs.single.parityErrors, 1);
    expect(response.maps.single.latestVersion?.sageScore, 79);
    expect(response.maps.single.latestVersion?.diffs.single.events, 456);
    expect(response.maps.single.latestVersion?.diffs.single.offset, 0.35);
    expect(response.maps.single.latestVersion?.diffs.single.maxScore, 987654);
    expect(response.maps.single.latestVersion?.diffs.single.chroma, isTrue);
    expect(response.maps.single.latestVersion?.diffs.single.cinema, isFalse);
    expect(response.maps.single.latestVersion?.diffs.single.me, isTrue);
    expect(response.maps.single.latestVersion?.diffs.single.ne, isTrue);
    expect(response.maps.single.latestVersion?.diffs.single.vivify, isFalse);
    expect(response.maps.single.latestVersion?.diffs.single.stars, 8.12);
    expect(response.maps.single.latestVersion?.diffs.single.blStars, 8.34);
  });

  test('parses BeatSaver map id lookup response object', () {
    final maps = {
      'abc': {
        'id': 'abc',
        'name': 'Song - Artist',
        'description': '',
        'metadata': {
          'songName': 'Song',
          'songAuthorName': 'Artist',
          'levelAuthorName': 'Mapper',
        },
        'stats': {},
        'versions': [],
      },
    }.values.map(BeatSaverMap.fromJson).toList(growable: false);

    expect(maps.single.id, 'abc');
    expect(maps.single.metadata.levelAuthorName, 'Mapper');
  });

  test('parses BeatSaver user detail response', () {
    final user = BeatSaverUser.fromJson({
      'id': 42,
      'name': 'mapper',
      'playlistUrl': 'https://beatsaver.com/playlists/id/42',
    });

    expect(user.id, 42);
    expect(user.name, 'mapper');
    expect(user.playlistUrl, 'https://beatsaver.com/playlists/id/42');
  });

  test('parses BeatSaver playlist page response', () {
    final page = BeatSaverPlaylistPage.fromJson({
      'playlist': {
        'playlistId': 7,
        'name': 'Featured',
        'stats': {'totalMaps': 1},
      },
      'maps': [
        {
          'order': 1,
          'map': {
            'id': 'abc',
            'name': 'Song - Artist',
            'description': '',
            'metadata': {
              'songName': 'Song',
              'songAuthorName': 'Artist',
              'levelAuthorName': 'Mapper',
            },
            'stats': {},
            'versions': [],
          },
        },
      ],
    });

    expect(page.playlist.id, 7);
    expect(page.playlist.name, 'Featured');
    expect(page.playlist.totalMaps, 1);
    expect(page.maps.single.id, 'abc');
  });

  test('serializes text search options into BeatSaver query parameters', () {
    const options = BeatSaverSearchOptions(
      query: 'camellia',
      pageSize: 50,
      order: BeatSaverSearchOrder.rating,
      minRating: 0.75,
      noodle: false,
    );

    expect(options.toQueryParameters(), {
      'q': 'camellia',
      'pageSize': '50',
      'order': 'Rating',
      'minRating': '0.75',
      'noodle': 'false',
    });
  });

  test('parses search order from CLI-friendly values', () {
    expect(parseBeatSaverSearchOrder('rating'), BeatSaverSearchOrder.rating);
    expect(parseBeatSaverSearchOrder('Rating'), BeatSaverSearchOrder.rating);
    expect(
        parseBeatSaverSearchOrder('unknown'), BeatSaverSearchOrder.relevance);
  });
}
