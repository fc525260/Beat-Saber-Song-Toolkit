class BeatSaverSearchOptions {
  const BeatSaverSearchOptions({
    required this.query,
    this.page = 0,
    this.pageSize = 20,
    this.order = BeatSaverSearchOrder.relevance,
    this.minRating,
    this.maxDurationSeconds,
    this.noodle,
    this.chroma,
    this.cinema,
    this.curated,
  });

  final String query;
  final int page;
  final int pageSize;
  final BeatSaverSearchOrder order;
  final double? minRating;
  final int? maxDurationSeconds;
  final bool? noodle;
  final bool? chroma;
  final bool? cinema;
  final bool? curated;

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'q': query,
      'pageSize': pageSize.toString(),
      'order': order.apiValue,
    };

    void add(String key, Object? value) {
      if (value != null) {
        params[key] = value.toString();
      }
    }

    add('minRating', minRating);
    add('maxDuration', maxDurationSeconds);
    add('noodle', noodle);
    add('chroma', chroma);
    add('cinema', cinema);
    add('curated', curated);
    return params;
  }
}

enum BeatSaverSearchOrder {
  latest('Latest'),
  relevance('Relevance'),
  rating('Rating'),
  curated('Curated'),
  random('Random'),
  duration('Duration');

  const BeatSaverSearchOrder(this.apiValue);

  final String apiValue;
}

BeatSaverSearchOrder parseBeatSaverSearchOrder(String value) {
  final normalized = value.trim().toLowerCase();
  return BeatSaverSearchOrder.values.firstWhere(
    (order) =>
        order.name.toLowerCase() == normalized ||
        order.apiValue.toLowerCase() == normalized,
    orElse: () => BeatSaverSearchOrder.relevance,
  );
}
