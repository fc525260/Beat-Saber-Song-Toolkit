class BeatSaverSearchResponse {
  const BeatSaverSearchResponse({
    required this.maps,
    required this.metadata,
  });

  factory BeatSaverSearchResponse.fromJson(Map<String, dynamic> json) {
    final docs = json['docs'];
    return BeatSaverSearchResponse(
      maps: docs is List
          ? docs
              .whereType<Map<String, dynamic>>()
              .map(BeatSaverMap.fromJson)
              .toList(growable: false)
          : const [],
      metadata: SearchMetadata.fromJson(
        json['info'] is Map<String, dynamic>
            ? json['info'] as Map<String, dynamic>
            : json['metadata'] is Map<String, dynamic>
                ? json['metadata'] as Map<String, dynamic>
                : const {},
      ),
    );
  }

  final List<BeatSaverMap> maps;
  final SearchMetadata metadata;
}

class SearchMetadata {
  const SearchMetadata({
    required this.total,
    required this.page,
    required this.itemsPerPage,
  });

  factory SearchMetadata.fromJson(Map<String, dynamic> json) {
    return SearchMetadata(
      total: _intValue(json['total']),
      page: _intValue(json['page']),
      itemsPerPage: _intValue(json['itemsPerPage']),
    );
  }

  final int total;
  final int page;
  final int itemsPerPage;
}

class BeatSaverUser {
  const BeatSaverUser({
    required this.id,
    required this.name,
    required this.playlistUrl,
  });

  factory BeatSaverUser.fromJson(Map<String, dynamic> json) {
    return BeatSaverUser(
      id: _intValue(json['id']),
      name: _stringValue(json['name']),
      playlistUrl: _stringValue(json['playlistUrl']),
    );
  }

  final int id;
  final String name;
  final String playlistUrl;
}

class BeatSaverPlaylistPage {
  const BeatSaverPlaylistPage({
    required this.maps,
    required this.playlist,
  });

  factory BeatSaverPlaylistPage.fromJson(Map<String, dynamic> json) {
    final maps = json['maps'];
    return BeatSaverPlaylistPage(
      maps: maps is List
          ? maps
              .whereType<Map<String, dynamic>>()
              .map((entry) => entry['map'])
              .whereType<Map<String, dynamic>>()
              .map(BeatSaverMap.fromJson)
              .toList(growable: false)
          : const [],
      playlist: BeatSaverPlaylist.fromJson(
        json['playlist'] is Map<String, dynamic>
            ? json['playlist'] as Map<String, dynamic>
            : const {},
      ),
    );
  }

  final List<BeatSaverMap> maps;
  final BeatSaverPlaylist playlist;
}

class BeatSaverPlaylist {
  const BeatSaverPlaylist({
    required this.id,
    required this.name,
    required this.totalMaps,
  });

  factory BeatSaverPlaylist.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'];
    return BeatSaverPlaylist(
      id: _intValue(json['playlistId']),
      name: _stringValue(json['name']),
      totalMaps: stats is Map<String, dynamic>
          ? _intValue(stats['totalMaps'])
          : _intValue(json['totalMaps']),
    );
  }

  final int id;
  final String name;
  final int totalMaps;
}

class BeatSaverMap {
  const BeatSaverMap({
    required this.id,
    required this.name,
    required this.description,
    required this.metadata,
    required this.stats,
    required this.versions,
    this.uploaderId,
    this.uploaderName,
    this.uploadedAt,
    this.ranked = false,
    this.qualified = false,
    this.curatedAt,
    this.declaredAi,
    this.tags = const [],
  });

  factory BeatSaverMap.fromJson(Map<String, dynamic> json) {
    final versions = json['versions'];
    final uploader = json['uploader'];
    return BeatSaverMap(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      description: _stringValue(json['description']),
      uploaderId:
          uploader is Map<String, dynamic> ? _intValue(uploader['id']) : null,
      uploaderName: uploader is Map<String, dynamic>
          ? _stringValue(uploader['name'])
          : null,
      uploadedAt: DateTime.tryParse(_stringValue(json['uploaded'])),
      ranked: _boolValue(json['ranked']) || _boolValue(json['blRanked']),
      qualified:
          _boolValue(json['qualified']) || _boolValue(json['blQualified']),
      curatedAt: DateTime.tryParse(_stringValue(json['curatedAt'])),
      declaredAi: _stringValue(json['declaredAi']),
      tags: json['tags'] is List
          ? (json['tags'] as List)
              .map(_stringValue)
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false)
          : const [],
      metadata: BeatSaverMetadata.fromJson(
        json['metadata'] is Map<String, dynamic>
            ? json['metadata'] as Map<String, dynamic>
            : const {},
      ),
      stats: BeatSaverStats.fromJson(
        json['stats'] is Map<String, dynamic>
            ? json['stats'] as Map<String, dynamic>
            : const {},
      ),
      versions: versions is List
          ? versions
              .whereType<Map<String, dynamic>>()
              .map(BeatSaverVersion.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String name;
  final String description;
  final int? uploaderId;
  final String? uploaderName;
  final DateTime? uploadedAt;
  final bool ranked;
  final bool qualified;
  final DateTime? curatedAt;
  final String? declaredAi;
  final List<String> tags;
  final BeatSaverMetadata metadata;
  final BeatSaverStats stats;
  final List<BeatSaverVersion> versions;

  BeatSaverVersion? get latestVersion {
    if (versions.isEmpty) {
      return null;
    }
    return versions.first;
  }
}

class BeatSaverMetadata {
  const BeatSaverMetadata({
    required this.songName,
    required this.songSubName,
    required this.songAuthorName,
    required this.levelAuthorName,
    required this.bpm,
    required this.durationSeconds,
  });

  factory BeatSaverMetadata.fromJson(Map<String, dynamic> json) {
    return BeatSaverMetadata(
      songName: _stringValue(json['songName']),
      songSubName: _stringValue(json['songSubName']),
      songAuthorName: _stringValue(json['songAuthorName']),
      levelAuthorName: _stringValue(json['levelAuthorName']),
      bpm: _doubleValue(json['bpm']),
      durationSeconds: _intValue(json['duration']),
    );
  }

  final String songName;
  final String songSubName;
  final String songAuthorName;
  final String levelAuthorName;
  final double bpm;
  final int durationSeconds;
}

class BeatSaverStats {
  const BeatSaverStats({
    required this.downloads,
    required this.plays,
    required this.upvotes,
    required this.downvotes,
    required this.score,
    required this.reviews,
  });

  factory BeatSaverStats.fromJson(Map<String, dynamic> json) {
    return BeatSaverStats(
      downloads: _intValue(json['downloads']),
      plays: _intValue(json['plays']),
      upvotes: _intValue(json['upvotes']),
      downvotes: _intValue(json['downvotes']),
      score: _doubleValue(json['score']),
      reviews: _intValue(json['reviews']),
    );
  }

  final int downloads;
  final int plays;
  final int upvotes;
  final int downvotes;
  final double score;
  final int reviews;
}

class BeatSaverVersion {
  const BeatSaverVersion({
    required this.hash,
    required this.state,
    required this.createdAt,
    required this.downloadUrl,
    required this.coverUrl,
    required this.previewUrl,
    required this.sageScore,
    required this.diffs,
  });

  factory BeatSaverVersion.fromJson(Map<String, dynamic> json) {
    final diffs = json['diffs'];
    return BeatSaverVersion(
      hash: _stringValue(json['hash']),
      state: _stringValue(json['state']),
      createdAt: DateTime.tryParse(_stringValue(json['createdAt'])),
      downloadUrl: _stringValue(json['downloadURL']),
      coverUrl: _stringValue(json['coverURL']),
      previewUrl: _stringValue(json['previewURL']),
      sageScore: _intValue(json['sageScore']),
      diffs: diffs is List
          ? diffs
              .whereType<Map<String, dynamic>>()
              .map(BeatSaverDifficulty.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  final String hash;
  final String state;
  final DateTime? createdAt;
  final String downloadUrl;
  final String coverUrl;
  final String previewUrl;
  final int sageScore;
  final List<BeatSaverDifficulty> diffs;
}

class BeatSaverDifficulty {
  const BeatSaverDifficulty({
    required this.characteristic,
    required this.difficulty,
    required this.njs,
    required this.nps,
    required this.notes,
    required this.bombs,
    required this.obstacles,
    required this.events,
    required this.offset,
    required this.maxScore,
    required this.chroma,
    required this.cinema,
    required this.me,
    required this.ne,
    required this.vivify,
    required this.length,
    required this.seconds,
    required this.label,
    required this.stars,
    required this.blStars,
    required this.parityErrors,
    required this.parityWarns,
    required this.parityResets,
  });

  factory BeatSaverDifficulty.fromJson(Map<String, dynamic> json) {
    final parity = json['paritySummary'];
    return BeatSaverDifficulty(
      characteristic: _stringValue(json['characteristic']),
      difficulty: _stringValue(json['difficulty']),
      njs: _doubleValue(json['njs']),
      nps: _doubleValue(json['nps']),
      notes: _intValue(json['notes']),
      bombs: _intValue(json['bombs']),
      obstacles: _intValue(json['obstacles']),
      events: _intValue(json['events']),
      offset: _doubleValue(json['offset']),
      maxScore: _intValue(json['maxScore']),
      chroma: _boolValue(json['chroma']),
      cinema: _boolValue(json['cinema']),
      me: _boolValue(json['me']),
      ne: _boolValue(json['ne']),
      vivify: _boolValue(json['vivify']),
      length: _doubleValue(json['length']),
      seconds: _doubleValue(json['seconds']),
      label: _stringValue(json['label']),
      stars: _doubleValue(json['stars']),
      blStars: _doubleValue(json['blStars']),
      parityErrors:
          parity is Map<String, dynamic> ? _intValue(parity['errors']) : 0,
      parityWarns:
          parity is Map<String, dynamic> ? _intValue(parity['warns']) : 0,
      parityResets:
          parity is Map<String, dynamic> ? _intValue(parity['resets']) : 0,
    );
  }

  final String characteristic;
  final String difficulty;
  final double njs;
  final double nps;
  final int notes;
  final int bombs;
  final int obstacles;
  final int events;
  final double offset;
  final int maxScore;
  final bool chroma;
  final bool cinema;
  final bool me;
  final bool ne;
  final bool vivify;
  final double length;
  final double seconds;
  final String label;
  final double stars;
  final double blStars;
  final int parityErrors;
  final int parityWarns;
  final int parityResets;
}

String _stringValue(Object? value) => value?.toString() ?? '';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
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

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}
