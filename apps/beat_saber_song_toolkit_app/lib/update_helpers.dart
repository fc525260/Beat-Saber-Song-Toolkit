class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.downloadUrl,
  });

  final String tagName;
  final String htmlUrl;
  final String downloadUrl;
}

ReleaseInfo releaseInfoFromJsonForTest(Object? decoded) {
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected GitHub release JSON object.');
  }
  final tagName = decoded['tag_name']?.toString().trim() ?? '';
  if (tagName.isEmpty) {
    throw const FormatException('GitHub release is missing tag_name.');
  }
  var downloadUrl = '';
  final assets = decoded['assets'];
  if (assets is List && assets.isNotEmpty) {
    final firstAsset = assets.first;
    if (firstAsset is Map) {
      downloadUrl = firstAsset['browser_download_url']?.toString().trim() ?? '';
    }
  }
  return ReleaseInfo(
    tagName: tagName,
    htmlUrl: decoded['html_url']?.toString().trim() ?? '',
    downloadUrl: downloadUrl,
  );
}

bool isRemoteVersionNewerForTest(String current, String remote) {
  final currentParts = _versionParts(current);
  final remoteParts = _versionParts(remote);
  final length = currentParts.length > remoteParts.length
      ? currentParts.length
      : remoteParts.length;
  for (var index = 0; index < length; index += 1) {
    final currentPart = index < currentParts.length ? currentParts[index] : 0;
    final remotePart = index < remoteParts.length ? remoteParts[index] : 0;
    if (remotePart > currentPart) {
      return true;
    }
    if (remotePart < currentPart) {
      return false;
    }
  }
  return false;
}

String updateAvailableMessageForTest({
  required String currentVersion,
  required ReleaseInfo release,
}) {
  return '发现新版 ${release.tagName}，当前版本 $currentVersion。'
      '${release.htmlUrl.isEmpty ? '' : ' 发布页：${release.htmlUrl}'}'
      '${release.downloadUrl.isEmpty ? '' : ' 下载地址：${release.downloadUrl}'}';
}

String updateLatestMessageForTest(String currentVersion) =>
    '当前已是最新版本：$currentVersion';

List<int> _versionParts(String version) {
  final normalized = version
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+\-]'))
      .first;
  return normalized
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'\D'), '')) ?? 0)
      .toList(growable: false);
}
