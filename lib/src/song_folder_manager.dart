import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_helpers.dart';
import 'installed_library.dart';

class BeatSaberGameDirectoryStatus {
  const BeatSaberGameDirectoryStatus({
    required this.gameDirectory,
    required this.hasExecutable,
    required this.hasDataDirectory,
    required this.customLevelsDirectory,
    required this.songCoreUserDataDirectory,
    required this.songCoreFoldersFile,
    required this.songCorePluginFile,
    required this.playlistManagerPluginFile,
  });

  final Directory gameDirectory;
  final bool hasExecutable;
  final bool hasDataDirectory;
  final Directory customLevelsDirectory;
  final Directory songCoreUserDataDirectory;
  final File songCoreFoldersFile;
  final File songCorePluginFile;
  final File playlistManagerPluginFile;

  bool get isBeatSaberDirectory => hasExecutable && hasDataDirectory;

  bool get isSongCoreInstalled => songCorePluginFile.existsSync();

  bool get isPlaylistManagerInstalled => playlistManagerPluginFile.existsSync();
}

class SongCoreFolderEntry {
  const SongCoreFolderEntry({
    required this.name,
    required this.path,
    this.pack = 2,
    this.wip = false,
    this.imagePath = '',
    this.extraXmlElements = const [],
  });

  final String name;
  final String path;
  final int pack;
  final bool wip;
  final String imagePath;
  final List<String> extraXmlElements;
}

class SongCoreFolderSaveResult {
  const SongCoreFolderSaveResult({
    required this.file,
    required this.entries,
    required this.added,
    required this.updated,
    this.backupFile,
  });

  final File file;
  final List<SongCoreFolderEntry> entries;
  final bool added;
  final bool updated;
  final File? backupFile;
}

class SongCoreFolderRemoveResult {
  const SongCoreFolderRemoveResult({
    required this.file,
    required this.requested,
    required this.removed,
    required this.entries,
    this.backupFile,
  });

  final File file;
  final int requested;
  final int removed;
  final List<SongCoreFolderEntry> entries;
  final File? backupFile;
}

class InstalledDuplicateGroup {
  const InstalledDuplicateGroup({
    required this.kind,
    required this.value,
    required this.entries,
  });

  final InstalledDuplicateKind kind;
  final String value;
  final List<InstalledSongEntry> entries;
}

enum InstalledDuplicateKind { mapId, songName }

class InstalledPathCorrection {
  const InstalledPathCorrection({
    required this.entry,
    required this.expectedDirectoryName,
  });

  final InstalledSongEntry entry;
  final String expectedDirectoryName;
}

class InstalledPathCorrectionFailure {
  const InstalledPathCorrectionFailure({
    required this.sourcePath,
    required this.expectedDirectoryName,
    required this.reason,
  });

  final String sourcePath;
  final String expectedDirectoryName;
  final String reason;
}

class InstalledPathCorrectionBatchResult {
  const InstalledPathCorrectionBatchResult({
    required this.requested,
    required this.renamed,
    required this.failed,
    this.failures = const [],
  });

  final int requested;
  final int renamed;
  final int failed;
  final List<InstalledPathCorrectionFailure> failures;
}

class InstalledDuplicateDeleteResult {
  const InstalledDuplicateDeleteResult({
    required this.requested,
    required this.deleted,
    required this.backups,
    required this.skippedMissing,
  });

  final int requested;
  final int deleted;
  final List<Directory> backups;
  final int skippedMissing;
}

BeatSaberGameDirectoryStatus inspectBeatSaberGameDirectory(
  Directory gameDirectory,
) {
  final root = p.normalize(gameDirectory.path);
  return BeatSaberGameDirectoryStatus(
    gameDirectory: Directory(root),
    hasExecutable: File(p.join(root, 'Beat Saber.exe')).existsSync(),
    hasDataDirectory: Directory(p.join(root, 'Beat Saber_Data')).existsSync(),
    customLevelsDirectory:
        Directory(p.join(root, 'Beat Saber_Data', 'CustomLevels')),
    songCoreUserDataDirectory: Directory(p.join(root, 'UserData', 'SongCore')),
    songCoreFoldersFile: File(
      p.join(root, 'UserData', 'SongCore', 'folders.xml'),
    ),
    songCorePluginFile: File(p.join(root, 'Plugins', 'SongCore.dll')),
    playlistManagerPluginFile:
        File(p.join(root, 'Plugins', 'PlaylistManager.dll')),
  );
}

Future<int> countValidInstalledSongs(Directory directory) async {
  final entries = await scanInstalledLibrary(directory);
  return entries.where((entry) => entry.hasInfoDat).length;
}

Future<SongCoreFolderSaveResult> saveSongCoreFolderEntry({
  required Directory gameDirectory,
  required Directory songFolder,
  String? name,
  File? imageFile,
  bool wip = false,
}) async {
  final status = inspectBeatSaberGameDirectory(gameDirectory);
  if (!status.isBeatSaberDirectory) {
    throw FileSystemException(
      'Not a Beat Saber game directory',
      gameDirectory.path,
    );
  }
  if (!await songFolder.exists()) {
    throw FileSystemException('Song folder does not exist', songFolder.path);
  }

  await status.songCoreUserDataDirectory.create(recursive: true);
  final existing = await readSongCoreFolderEntries(status.songCoreFoldersFile);
  final normalizedPath = p.normalize(p.absolute(songFolder.path));
  final entryName = _songCoreEntryName(name, songFolder);
  final imagePath =
      imageFile == null ? '' : p.normalize(p.absolute(imageFile.path));
  final nextEntry = SongCoreFolderEntry(
    name: entryName,
    path: normalizedPath,
    pack: 2,
    wip: wip,
    imagePath: imagePath,
  );

  var added = false;
  var updated = false;
  final next = <SongCoreFolderEntry>[];
  var replacementIndex = -1;
  var replaced = false;
  for (final entry in existing) {
    if (p.equals(p.normalize(p.absolute(entry.path)), normalizedPath)) {
      if (!replaced) {
        replacementIndex = next.length;
        next.add(
          SongCoreFolderEntry(
            name: nextEntry.name,
            path: nextEntry.path,
            pack: nextEntry.pack,
            wip: nextEntry.wip,
            imagePath: nextEntry.imagePath,
            extraXmlElements: entry.extraXmlElements,
          ),
        );
        replaced = true;
      } else {
        final replacement = next[replacementIndex];
        next[replacementIndex] = SongCoreFolderEntry(
          name: replacement.name,
          path: replacement.path,
          pack: replacement.pack,
          wip: replacement.wip,
          imagePath: replacement.imagePath,
          extraXmlElements: _mergeXmlElements(
            replacement.extraXmlElements,
            entry.extraXmlElements,
          ),
        );
        updated = true;
      }
      updated = entry.name != nextEntry.name ||
          p.normalize(p.absolute(entry.path)) != nextEntry.path ||
          entry.pack != nextEntry.pack ||
          entry.wip != nextEntry.wip ||
          _normalizedOptionalPath(entry.imagePath) != nextEntry.imagePath ||
          updated;
    } else {
      next.add(entry);
    }
  }
  if (!replaced) {
    next.add(nextEntry);
    added = true;
  }

  if (!added && !updated) {
    return SongCoreFolderSaveResult(
      file: status.songCoreFoldersFile,
      entries: List.unmodifiable(next),
      added: false,
      updated: false,
    );
  }

  final backupFile = await backupSongCoreFoldersFile(
    status.songCoreFoldersFile,
  );
  await status.songCoreFoldersFile.writeAsString(
    await _songCoreFoldersXmlForFile(status.songCoreFoldersFile, next),
    flush: true,
  );
  return SongCoreFolderSaveResult(
    file: status.songCoreFoldersFile,
    entries: List.unmodifiable(next),
    added: added,
    updated: updated,
    backupFile: backupFile,
  );
}

Future<List<SongCoreFolderEntry>> readSongCoreFolderEntries(File file) async {
  if (!await file.exists()) {
    return const [];
  }
  final text = await file.readAsString();
  final entries = <SongCoreFolderEntry>[];
  for (final block in _songCoreFolderBlocks(text)) {
    final entry = SongCoreFolderEntry(
      name: _xmlElementText(block, 'Name'),
      path: _xmlElementText(block, 'Path'),
      pack: _songCorePack(_xmlElementText(block, 'Pack')),
      wip: _songCoreBool(_xmlElementText(block, 'WIP')),
      imagePath: _xmlElementText(block, 'ImagePath'),
      extraXmlElements: _unknownXmlElements(block),
    );
    if (_isPlaceholderSongCoreEntry(entry)) {
      continue;
    }
    entries.add(entry);
  }
  return entries;
}

Iterable<String> _songCoreFolderBlocks(String text) sync* {
  final tagPattern = RegExp(
    r'<(/?)((?:[A-Za-z_][\w.-]*:)?folder)\b[^>]*>',
    caseSensitive: false,
  );
  String? openTag;
  var contentStart = -1;
  for (final match in tagPattern.allMatches(text)) {
    final closing = match.group(1) == '/';
    final tagName = match.group(2);
    if (tagName == null) {
      continue;
    }
    if (!closing) {
      final fullTag = match.group(0) ?? '';
      if (fullTag.endsWith('/>')) {
        continue;
      }
      openTag = tagName.toLowerCase();
      contentStart = match.end;
      continue;
    }
    if (openTag == tagName.toLowerCase() && contentStart >= 0) {
      yield text.substring(contentStart, match.start);
      openTag = null;
      contentStart = -1;
    }
  }
}

Future<SongCoreFolderRemoveResult> removeSongCoreFolderEntries({
  required File file,
  required Iterable<String> keys,
}) async {
  final requestedKeys = keys
      .map((key) => key.trim().toLowerCase())
      .where((key) => key.isNotEmpty)
      .toSet();
  if (requestedKeys.isEmpty) {
    throw ArgumentError('No SongCore folder entries selected.');
  }
  final existing = await readSongCoreFolderEntries(file);
  final next = <SongCoreFolderEntry>[];
  var removed = 0;
  for (final entry in existing) {
    if (requestedKeys.contains(songCoreFolderEntryKey(entry))) {
      removed += 1;
    } else {
      next.add(entry);
    }
  }
  if (removed == 0) {
    return SongCoreFolderRemoveResult(
      file: file,
      requested: requestedKeys.length,
      removed: 0,
      entries: List.unmodifiable(existing),
    );
  }
  await file.parent.create(recursive: true);
  final backupFile = await backupSongCoreFoldersFile(file);
  await file.writeAsString(
    await _songCoreFoldersXmlForFile(file, next),
    flush: true,
  );
  return SongCoreFolderRemoveResult(
    file: file,
    requested: requestedKeys.length,
    removed: removed,
    entries: List.unmodifiable(next),
    backupFile: backupFile,
  );
}

Future<File?> backupSongCoreFoldersFile(File file) async {
  if (!await file.exists()) {
    return null;
  }
  final backupDirectory = Directory(p.join(file.parent.path, 'backups'));
  return backupFileToDirectory(file, backupDirectory);
}

String songCoreFolderEntryKey(SongCoreFolderEntry entry) {
  final rawPath = entry.path.trim();
  if (rawPath.isNotEmpty) {
    return p.normalize(p.absolute(rawPath)).toLowerCase();
  }
  return entry.name.trim().toLowerCase();
}

String songCoreFoldersXml(
  Iterable<SongCoreFolderEntry> entries, {
  String? existingXml,
}) {
  final xmlDeclaration = _xmlDeclaration(existingXml);
  final foldersTag = _foldersOpeningTag(existingXml);
  final foldersElement = _foldersElementName(existingXml);
  final buffer = StringBuffer()
    ..writeln(xmlDeclaration)
    ..writeln(foldersTag);
  for (final entry in entries) {
    buffer
      ..writeln('  <folder>')
      ..writeln('    <Name>${_xmlEscape(entry.name)}</Name>')
      ..writeln('    <Path>${_xmlEscape(entry.path)}</Path>')
      ..writeln('    <Pack>${entry.pack}</Pack>')
      ..writeln('    <WIP>${entry.wip ? 'True' : 'False'}</WIP>');
    if (entry.imagePath.trim().isNotEmpty) {
      buffer
          .writeln('    <ImagePath>${_xmlEscape(entry.imagePath)}</ImagePath>');
    }
    for (final extra in entry.extraXmlElements) {
      final trimmed = extra.trim();
      if (trimmed.isNotEmpty) {
        buffer.writeln('    $trimmed');
      }
    }
    buffer.writeln('  </folder>');
  }
  buffer.writeln('</$foldersElement>');
  return buffer.toString();
}

Future<String> _songCoreFoldersXmlForFile(
  File file,
  Iterable<SongCoreFolderEntry> entries,
) async {
  final existingXml = await file.exists() ? await file.readAsString() : null;
  return songCoreFoldersXml(entries, existingXml: existingXml);
}

String _xmlDeclaration(String? existingXml) {
  final match = RegExp(r'^\s*(<\?xml\b[^>]*\?>)', caseSensitive: false)
      .firstMatch(existingXml ?? '');
  return match?.group(1) ?? '<?xml version="1.0" encoding="utf-8"?>';
}

String _foldersOpeningTag(String? existingXml) {
  final match = RegExp(
    r'<(?:[A-Za-z_][\w.-]*:)?folders\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(existingXml ?? '');
  return match?.group(0) ?? '<folders>';
}

String _foldersElementName(String? existingXml) {
  final match = RegExp(
    r'<((?:[A-Za-z_][\w.-]*:)?folders)\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(existingXml ?? '');
  return match?.group(1) ?? 'folders';
}

List<String> _mergeXmlElements(List<String> first, List<String> second) {
  final seen = <String>{};
  final merged = <String>[];
  for (final element in [...first, ...second]) {
    final trimmed = element.trim();
    if (trimmed.isEmpty || !seen.add(_xmlElementMergeKey(trimmed))) {
      continue;
    }
    merged.add(trimmed);
  }
  return merged;
}

String _xmlElementMergeKey(String element) {
  final normalized = element.replaceFirst(RegExp(r'\s*/>$'), '/>');
  final match = RegExp(
    r'^<([A-Za-z_][\w:.-]*)([^<>]*?)(/?>)',
    dotAll: true,
  ).firstMatch(normalized);
  if (match == null) {
    return normalized.toLowerCase();
  }

  final name = match.group(1) ?? '';
  final attrs = _xmlAttributeMergeKeys(match.group(2) ?? '');
  final close = match.group(3) ?? '>';
  final attrText = attrs.isEmpty ? '' : ' ${attrs.join(' ')}';
  return '<$name$attrText$close${normalized.substring(match.end)}'
      .toLowerCase();
}

List<String> _xmlAttributeMergeKeys(String text) {
  final attrs = <String>[];
  for (final match in RegExp(
    r'''([A-Za-z_][\w:.-]*)\s*=\s*("[^"]*"|'[^']*')''',
    dotAll: true,
  ).allMatches(text)) {
    attrs.add('${match.group(1) ?? ''}=${match.group(2) ?? ''}');
  }
  attrs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return attrs;
}

Future<Directory> applyInstalledPathCorrection(
  InstalledPathCorrection correction,
) async {
  final source = correction.entry.directory;
  final sourcePath = p.normalize(p.absolute(source.path));
  final parentPath = p.dirname(sourcePath);
  final expectedName = correction.expectedDirectoryName.trim();
  if (expectedName.isEmpty || p.basename(expectedName) != expectedName) {
    throw ArgumentError.value(
      correction.expectedDirectoryName,
      'expectedDirectoryName',
      'must be a single directory name',
    );
  }

  if (!await source.exists()) {
    throw FileSystemException('Source directory does not exist', sourcePath);
  }

  final targetPath = p.normalize(p.join(parentPath, expectedName));
  if (p.equals(sourcePath, targetPath)) {
    return source;
  }
  if (await Directory(targetPath).exists()) {
    throw FileSystemException('Target directory already exists', targetPath);
  }

  return source.rename(targetPath);
}

Future<InstalledPathCorrectionBatchResult> applyInstalledPathCorrections(
  Iterable<InstalledPathCorrection> corrections,
) async {
  final requestedSourcePaths = <String>{};
  final failures = <InstalledPathCorrectionFailure>[];
  var requested = 0;
  var renamed = 0;
  var failed = 0;
  for (final correction in corrections) {
    final sourcePath =
        _normalizedFileSystemPath(correction.entry.directory.path);
    if (!requestedSourcePaths.add(
      sourcePath,
    )) {
      continue;
    }
    requested += 1;
    try {
      await applyInstalledPathCorrection(correction);
      renamed += 1;
    } catch (error) {
      failed += 1;
      failures.add(
        InstalledPathCorrectionFailure(
          sourcePath: sourcePath,
          expectedDirectoryName: correction.expectedDirectoryName,
          reason: _pathCorrectionFailureReason(error),
        ),
      );
    }
  }
  return InstalledPathCorrectionBatchResult(
    requested: requested,
    renamed: renamed,
    failed: failed,
    failures: failures,
  );
}

String _pathCorrectionFailureReason(Object error) {
  if (error is FileSystemException) {
    return error.message;
  }
  if (error is ArgumentError) {
    final message = error.message;
    if (message != null) {
      return message.toString();
    }
  }
  return error.toString();
}

Future<InstalledDuplicateDeleteResult>
    deleteInstalledDuplicateEntriesWithBackup({
  required Iterable<InstalledSongEntry> entries,
  required Directory backupDirectory,
}) async {
  final selected = entries.toList(growable: false);
  if (selected.isEmpty) {
    throw ArgumentError('No duplicate installed entries selected.');
  }

  final backups = <Directory>[];
  final deletedSourcePaths = <String>{};
  var deleted = 0;
  var skippedMissing = 0;
  for (final entry in selected) {
    final source = entry.directory;
    if (!deletedSourcePaths.add(_normalizedFileSystemPath(source.path))) {
      continue;
    }
    if (!await source.exists()) {
      skippedMissing += 1;
      continue;
    }
    final backup = await backupDirectoryToDirectory(source, backupDirectory);
    backups.add(backup);
    await source.delete(recursive: true);
    deleted += 1;
  }
  return InstalledDuplicateDeleteResult(
    requested: selected.length,
    deleted: deleted,
    backups: backups,
    skippedMissing: skippedMissing,
  );
}

List<InstalledSongEntry> installedDuplicateRemovalCandidates(
  Iterable<InstalledDuplicateGroup> groups,
) {
  final seen = <String>{};
  final candidates = <InstalledSongEntry>[];
  for (final group in groups) {
    final sorted = [...group.entries]..sort((a, b) {
        final byLower = a.directoryName
            .toLowerCase()
            .compareTo(b.directoryName.toLowerCase());
        return byLower == 0
            ? a.directoryName.compareTo(b.directoryName)
            : byLower;
      });
    for (final entry in sorted.skip(1)) {
      final key = p.normalize(p.absolute(entry.directory.path)).toLowerCase();
      if (seen.add(key)) {
        candidates.add(entry);
      }
    }
  }
  return candidates;
}

String _normalizedFileSystemPath(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

String _normalizedOptionalPath(String path) {
  final trimmed = path.trim();
  return trimmed.isEmpty ? '' : p.normalize(p.absolute(trimmed));
}

List<InstalledDuplicateGroup> findInstalledDuplicateGroups(
  Iterable<InstalledSongEntry> entries,
) {
  final byId = <String, List<InstalledSongEntry>>{};
  final byName = <String, List<InstalledSongEntry>>{};
  for (final entry in entries) {
    final id = entry.mapId?.trim().toLowerCase();
    if (id != null && id.isNotEmpty) {
      byId.putIfAbsent(id, () => []).add(entry);
      continue;
    }
    final name = _normalizedSongName(entry.info?.songName ?? entry.title ?? '');
    if (name.isNotEmpty) {
      byName.putIfAbsent(name, () => []).add(entry);
    }
  }

  final groups = <InstalledDuplicateGroup>[
    for (final item in byId.entries)
      if (item.value.length > 1)
        InstalledDuplicateGroup(
          kind: InstalledDuplicateKind.mapId,
          value: item.key,
          entries: item.value,
        ),
    for (final item in byName.entries)
      if (item.value.length > 1)
        InstalledDuplicateGroup(
          kind: InstalledDuplicateKind.songName,
          value: item.key,
          entries: item.value,
        ),
  ];
  groups.sort((a, b) {
    final kindCompare = a.kind.name.compareTo(b.kind.name);
    return kindCompare == 0 ? a.value.compareTo(b.value) : kindCompare;
  });
  return groups;
}

List<InstalledPathCorrection> suggestInstalledPathCorrections(
  Iterable<InstalledSongEntry> entries, {
  String template = '[id] - [歌名]',
  bool asciiOnly = false,
}) {
  final corrections = <InstalledPathCorrection>[];
  for (final entry in entries) {
    final expected = installedEntryDirectoryName(
      entry,
      template: template,
      asciiOnly: asciiOnly,
    );
    if (expected.isEmpty || expected == entry.directoryName) {
      continue;
    }
    corrections.add(
      InstalledPathCorrection(
        entry: entry,
        expectedDirectoryName: expected,
      ),
    );
  }
  return corrections;
}

String installedEntryDirectoryName(
  InstalledSongEntry entry, {
  String template = '[id] - [歌名]',
  bool asciiOnly = false,
}) {
  final mapId = entry.mapId?.trim() ?? '';
  final title = _bestTitle(entry);
  final info = entry.info;
  final rawName = (template.trim().isEmpty ? '[id] - [歌名]' : template)
      .replaceAll('[id]', mapId)
      .replaceAll('[bsr]', mapId)
      .replaceAll('[歌名]', title)
      .replaceAll('[song]', title)
      .replaceAll('[歌曲]', title)
      .replaceAll('[作者]', info?.songAuthorName ?? '')
      .replaceAll('[artist]', info?.songAuthorName ?? '')
      .replaceAll('[制作者]', info?.levelAuthorName ?? '')
      .replaceAll('[mapper]', info?.levelAuthorName ?? '')
      .replaceAll('[bpm]', _formatBpm(info?.beatsPerMinute ?? 0));
  final asciiName =
      asciiOnly ? rawName.replaceAll(RegExp(r'[^\x20-\x7E]'), '_') : rawName;
  final safeName =
      asciiName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  return safeName.isEmpty ? p.basename(entry.directory.path) : safeName;
}

String _bestTitle(InstalledSongEntry entry) {
  final infoTitle = entry.info?.songName.trim();
  if (infoTitle != null && infoTitle.isNotEmpty) {
    return infoTitle;
  }
  final title = entry.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return entry.directoryName;
}

String _normalizedSongName(String value) {
  return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

String _formatBpm(double bpm) {
  if (bpm <= 0) {
    return '';
  }
  return bpm == bpm.roundToDouble() ? bpm.toInt().toString() : bpm.toString();
}

String _songCoreEntryName(String? name, Directory songFolder) {
  final trimmed = name?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  return p.basename(p.normalize(songFolder.path));
}

bool _isPlaceholderSongCoreEntry(SongCoreFolderEntry entry) {
  final name = entry.name.trim();
  return name.isEmpty ||
      name.toLowerCase() == 'example' ||
      entry.path.trim().isEmpty;
}

int _songCorePack(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed ?? 2;
}

bool _songCoreBool(String value) {
  return {'true', '1', 'yes', 'y'}.contains(value.trim().toLowerCase());
}

String _xmlElementText(String block, String element) {
  final match = RegExp(
    '<((?:[A-Za-z_][\\w.-]*:)?$element)\\b[^>]*>(.*?)</\\1>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(block);
  if (match == null) {
    return '';
  }
  return _xmlUnescape(match.group(2)?.trim() ?? '');
}

List<String> _unknownXmlElements(String block) {
  const known = {'name', 'path', 'pack', 'wip', 'imagepath'};
  final fragments = <_XmlFragment>[];
  final pairedRanges = <_XmlRange>[];

  final specialRanges = _xmlSpecialSectionRanges(block);
  for (final element in _topLevelXmlElements(block, specialRanges)) {
    final name = _xmlLocalName(element.name);
    if (name != null && !known.contains(name)) {
      pairedRanges.add(_XmlRange(element.start, element.end));
      fragments.add(_XmlFragment(element.start, element.text.trim()));
    }
  }
  for (final range in specialRanges) {
    final element = block.substring(range.start, range.end).trim();
    if (element.isNotEmpty && !_rangeInsideAnyRange(range, pairedRanges)) {
      fragments.add(_XmlFragment(range.start, element));
    }
  }
  for (final match in RegExp(
    r'<([A-Za-z_][\w:.-]*)\b[^>]*/>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(block)) {
    final name = _xmlLocalName(match.group(1));
    final element = match.group(0)?.trim() ?? '';
    if (name != null &&
        !known.contains(name) &&
        element.isNotEmpty &&
        !_insideAnyRange(match, pairedRanges)) {
      fragments.add(_XmlFragment(match.start, element));
    }
  }
  fragments.sort((a, b) => a.start.compareTo(b.start));
  return fragments.map((fragment) => fragment.text).toList(growable: false);
}

List<_XmlRange> _xmlSpecialSectionRanges(String block) {
  final ranges = <_XmlRange>[];
  for (final match in RegExp(r'<!--.*?-->', dotAll: true).allMatches(block)) {
    ranges.add(_XmlRange(match.start, match.end));
  }
  for (final match
      in RegExp(r'<!\[CDATA\[.*?\]\]>', dotAll: true).allMatches(block)) {
    ranges.add(_XmlRange(match.start, match.end));
  }
  for (final match
      in RegExp(r'<\?(?!xml\b).*?\?>', caseSensitive: false, dotAll: true)
          .allMatches(block)) {
    ranges.add(_XmlRange(match.start, match.end));
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  return ranges;
}

List<_XmlElementFragment> _topLevelXmlElements(
  String block,
  Iterable<_XmlRange> ignoredRanges,
) {
  final tags = RegExp(
    r'<(/?)([A-Za-z_][\w:.-]*)\b[^>]*>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(block);
  final stack = <_OpenXmlTag>[];
  final elements = <_XmlElementFragment>[];
  for (final match in tags) {
    if (_insideAnyRange(match, ignoredRanges)) {
      continue;
    }
    final fullTag = match.group(0) ?? '';
    if (fullTag.startsWith('<!--') || fullTag.endsWith('/>')) {
      continue;
    }
    final closing = match.group(1) == '/';
    final name = match.group(2);
    if (name == null) {
      continue;
    }
    final normalized = name.toLowerCase();
    if (!closing) {
      stack.add(_OpenXmlTag(name, normalized, match.start));
      continue;
    }
    if (stack.isEmpty || stack.last.normalizedName != normalized) {
      continue;
    }
    final opened = stack.removeLast();
    if (stack.isEmpty) {
      elements.add(
        _XmlElementFragment(
          opened.name,
          opened.start,
          match.end,
          block.substring(opened.start, match.end),
        ),
      );
    }
  }
  return elements;
}

String? _xmlLocalName(String? name) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.split(':').last.toLowerCase();
}

bool _insideAnyRange(RegExpMatch match, Iterable<_XmlRange> ranges) {
  return ranges
      .any((range) => match.start > range.start && match.end < range.end);
}

bool _rangeInsideAnyRange(_XmlRange target, Iterable<_XmlRange> ranges) {
  return ranges
      .any((range) => target.start > range.start && target.end < range.end);
}

class _XmlFragment {
  const _XmlFragment(this.start, this.text);

  final int start;
  final String text;
}

class _XmlRange {
  const _XmlRange(this.start, this.end);

  final int start;
  final int end;
}

class _OpenXmlTag {
  const _OpenXmlTag(this.name, this.normalizedName, this.start);

  final String name;
  final String normalizedName;
  final int start;
}

class _XmlElementFragment {
  const _XmlElementFragment(this.name, this.start, this.end, this.text);

  final String name;
  final int start;
  final int end;
  final String text;
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _xmlUnescape(String value) {
  return value.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'),
    (match) {
      final entity = match.group(1) ?? '';
      final lower = entity.toLowerCase();
      switch (lower) {
        case 'apos':
          return "'";
        case 'quot':
          return '"';
        case 'gt':
          return '>';
        case 'lt':
          return '<';
        case 'amp':
          return '&';
      }
      if (lower.startsWith('#x')) {
        final codePoint = int.tryParse(entity.substring(2), radix: 16);
        if (codePoint != null && _validXmlCodePoint(codePoint)) {
          return String.fromCharCode(codePoint);
        }
      } else if (lower.startsWith('#')) {
        final codePoint = int.tryParse(entity.substring(1));
        if (codePoint != null && _validXmlCodePoint(codePoint)) {
          return String.fromCharCode(codePoint);
        }
      }
      return match.group(0) ?? '';
    },
  );
}

bool _validXmlCodePoint(int codePoint) {
  return codePoint == 0x9 ||
      codePoint == 0xA ||
      codePoint == 0xD ||
      (codePoint >= 0x20 && codePoint <= 0xD7FF) ||
      (codePoint >= 0xE000 && codePoint <= 0xFFFD) ||
      (codePoint >= 0x10000 && codePoint <= 0x10FFFF);
}
