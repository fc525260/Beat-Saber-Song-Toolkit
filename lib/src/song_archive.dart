import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'installed_library.dart';

Future<File> exportInstalledSongsZip({
  required Directory libraryDirectory,
  required File outputFile,
}) async {
  final entries = await scanInstalledLibrary(libraryDirectory);
  final archive = Archive();

  for (final entry in entries.where((entry) => entry.hasInfoDat)) {
    final rootName = _safeZipPathSegment(entry.directoryName);
    await _addDirectoryToArchive(
      archive: archive,
      directory: entry.directory,
      rootPath: entry.directory.path,
      archiveRoot: rootName,
    );
  }

  await outputFile.parent.create(recursive: true);
  final bytes = ZipEncoder().encode(archive);
  await outputFile.writeAsBytes(bytes, flush: true);
  return outputFile;
}

Future<void> _addDirectoryToArchive({
  required Archive archive,
  required Directory directory,
  required String rootPath,
  required String archiveRoot,
}) async {
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is Directory) {
      await _addDirectoryToArchive(
        archive: archive,
        directory: entity,
        rootPath: rootPath,
        archiveRoot: archiveRoot,
      );
      continue;
    }
    if (entity is! File) {
      continue;
    }

    final relative = p.relative(entity.path, from: rootPath);
    final archivePath = p.url.join(
      archiveRoot,
      p.split(relative).map(_safeZipPathSegment).join('/'),
    );
    final bytes = await entity.readAsBytes();
    archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
  }
}

String _safeZipPathSegment(String value) {
  final sanitized =
      value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  return sanitized.isEmpty ? 'Untitled' : sanitized;
}
