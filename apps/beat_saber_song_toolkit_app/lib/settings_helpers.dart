String settingStringForTest(
  Map<String, dynamic> json,
  String key,
  String fallback,
) {
  final value = json[key];
  return value is String ? value : fallback;
}

List<String> settingStringListForTest(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

bool settingBoolForTest(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}

int settingIntForTest(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double settingDoubleForTest(
  Map<String, dynamic> json,
  String key,
  double fallback,
) {
  final value = json[key];
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

enum WorkspaceForTest { search, library, playlistSync }

WorkspaceForTest workspaceFromSettingForTest(
  String? value, {
  required WorkspaceForTest fallback,
}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  for (final workspace in WorkspaceForTest.values) {
    if (workspace.name == normalized) {
      return workspace;
    }
  }
  return fallback;
}
