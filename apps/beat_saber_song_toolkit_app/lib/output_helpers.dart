const defaultLogExportFilenameForTest = 'beat_saber_song_toolkit_logs.txt';
const defaultTargetListExportFilenameForTest =
    'beat_saber_song_toolkit_targets.txt';

String outputPathFromTemplateForTest(
  String rawPath, {
  required String extension,
  required String profileName,
  DateTime? now,
}) {
  final safeProfileName = safeOutputProfileNameForTest(profileName);
  final path = rawPath.trim().isEmpty ? '$safeProfileName.$extension' : rawPath;
  return path
      .replaceAll('[日期]', outputDateForTest(now ?? DateTime.now()))
      .replaceAll('[配置名称]', safeProfileName)
      .replaceAll('[配置]', safeProfileName);
}

String safeOutputProfileNameForTest(String raw) {
  final fallback = raw.trim().isEmpty ? 'songs' : raw.trim();
  final normalizedWhitespace = fallback.replaceAll(RegExp(r'\s+'), ' ').trim();
  final safe = normalizedWhitespace
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .trim()
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  return safe.isEmpty ? 'songs' : safe;
}

String outputDateForTest(DateTime now) {
  return '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
}

String exportDateForTest(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatBytesForTest(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  final mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(1)} MB';
  }
  return '${(mib / 1024).toStringAsFixed(1)} GB';
}
