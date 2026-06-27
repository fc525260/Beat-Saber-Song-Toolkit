import 'dart:io';

int? parseIntForTest(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return int.tryParse(trimmed);
}

double? parseDoubleForTest(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}

double? parseRatioForTest(String value) {
  final parsed = parseDoubleForTest(value);
  if (parsed == null) {
    return null;
  }
  final ratio = parsed > 1 ? parsed / 100 : parsed;
  return ratio.clamp(0, 1).toDouble();
}

DateTime? parseDateForTest(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (RegExp(r'^\d{10}$').hasMatch(trimmed)) {
    final seconds = int.tryParse(trimmed);
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
  final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) {
    return null;
  }
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

List<T> limitedItemsForTest<T>(List<T> items, int? limit) {
  if (limit == null || limit <= 0 || items.length <= limit) {
    return items;
  }
  return items.take(limit).toList(growable: false);
}

List<Directory> directoriesFromTextForTest(String value) {
  return value
      .split(RegExp(r'[\r\n;]+'))
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .map(Directory.new)
      .toList(growable: false);
}

Set<String> splitFilterTokensForTest(String value) {
  return value
      .split(RegExp(r'[\s,，;；]+'))
      .map((token) => token.trim().toLowerCase())
      .where((token) => token.isNotEmpty)
      .toSet();
}
