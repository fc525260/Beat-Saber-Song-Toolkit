import 'dart:io';

import 'package:path/path.dart' as p;

Future<File> backupFileToDirectory(
  File source,
  Directory backupDirectory,
) async {
  await backupDirectory.create(recursive: true);
  final target = await uniqueBackupFile(
    backupDirectory,
    p.basename(source.path),
  );
  return source.copy(target.path);
}

Future<Directory> backupDirectoryToDirectory(
  Directory source,
  Directory backupDirectory,
) async {
  final target = await uniqueBackupDirectory(
    backupDirectory,
    p.basename(source.path),
  );
  await copyDirectoryRecursive(source, target);
  return target;
}

Future<File> uniqueBackupFile(Directory directory, String name) async {
  final baseName = uniqueBackupName(name);
  var candidate = File(p.join(directory.path, baseName));
  var suffix = 1;
  while (await pathExists(candidate.path)) {
    candidate = File(p.join(directory.path, '${baseName}_$suffix'));
    suffix += 1;
  }
  return candidate;
}

Future<Directory> uniqueBackupDirectory(
    Directory directory, String name) async {
  final baseName = uniqueBackupName(name);
  var candidate = Directory(p.join(directory.path, baseName));
  var suffix = 1;
  while (await pathExists(candidate.path)) {
    candidate = Directory(p.join(directory.path, '${baseName}_$suffix'));
    suffix += 1;
  }
  return candidate;
}

Future<bool> pathExists(String path) async {
  return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
}

Future<void> copyDirectoryRecursive(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final targetPath = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await copyDirectoryRecursive(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}

String uniqueBackupName(String name) {
  final now = DateTime.now();
  final stamp = '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}'
      '_${now.microsecond.toString().padLeft(6, '0')}';
  return '${stamp}_$name';
}
