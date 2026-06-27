import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('inspects Beat Saber game directory and mod install status', () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_game_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    await Directory('${temp.path}/Plugins').create();
    await File('${temp.path}/Plugins/SongCore.dll').create();

    final status = inspectBeatSaberGameDirectory(temp);

    expect(status.isBeatSaberDirectory, isTrue);
    expect(status.isSongCoreInstalled, isTrue);
    expect(status.isPlaylistManagerInstalled, isFalse);
    expect(
      status.customLevelsDirectory.path,
      '${temp.path}\\Beat Saber_Data\\CustomLevels',
    );
    expect(
      status.songCoreFoldersFile.path,
      '${temp.path}\\UserData\\SongCore\\folders.xml',
    );
  });

  test('counts valid installed songs by info.dat presence', () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_count_');
    addTearDown(() => temp.delete(recursive: true));
    final validA = await Directory('${temp.path}/abc - A').create();
    await File('${validA.path}/Info.dat').writeAsString('{"_songName":"A"}');
    final broken = await Directory('${temp.path}/broken').create();
    await File('${broken.path}/song.egg').writeAsString('audio');
    final validB = await Directory('${temp.path}/def - B').create();
    await File('${validB.path}/info.dat').writeAsString('{"songName":"B"}');

    expect(await countValidInstalledSongs(temp), 2);
    final scanned = await scanInstalledLibrary(temp);
    expect(
        scanned
            .singleWhere((entry) => entry.directoryName == 'broken')
            .hasAudioFile,
        isTrue);
  });

  test('saves SongCore folders.xml entry for a song folder', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final songFolder = await Directory('${temp.path}/Packs/A & B').create(
      recursive: true,
    );
    final image = await File('${temp.path}/cover.png').create();

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: songFolder,
      name: 'A & B 包',
      imageFile: image,
    );

    expect(result.added, isTrue);
    expect(result.updated, isFalse);
    expect(result.backupFile, isNull);
    expect(await result.file.exists(), isTrue);
    final xml = await result.file.readAsString();
    expect(xml, contains('<Name>A &amp; B 包</Name>'));
    expect(xml, contains('<Pack>2</Pack>'));
    expect(xml, contains('<WIP>False</WIP>'));

    final entries = await readSongCoreFolderEntries(result.file);
    expect(entries, hasLength(1));
    expect(entries.single.name, 'A & B 包');
    expect(entries.single.path, p.normalize(p.absolute(songFolder.path)));
    expect(entries.single.imagePath, p.normalize(p.absolute(image.path)));
  });

  test('updates existing SongCore folder entry by path', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();

    await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Old',
    );
    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
      wip: true,
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    expect(result.backupFile, isNotNull);
    expect(await result.backupFile!.exists(), isTrue);
    expect(
        await result.backupFile!.readAsString(), contains('<Name>Old</Name>'));
    final entries = await readSongCoreFolderEntries(result.file);
    expect(entries, hasLength(1));
    expect(entries.single.name, 'New');
    expect(entries.single.wip, isTrue);
  });

  test('does not back up or rewrite unchanged SongCore folder entry', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_noop_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();

    final first = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Same',
    );
    final before = await first.file.readAsString();

    final second = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Same',
    );

    expect(second.added, isFalse);
    expect(second.updated, isFalse);
    expect(second.backupFile, isNull);
    expect(second.entries, hasLength(1));
    expect(await second.file.readAsString(), before);
    expect(
      await Directory('${temp.path}/UserData/SongCore/backups').exists(),
      isFalse,
    );
  });

  test('rewrites case-only SongCore path differences with same fields',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_case_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final caseVariant = normalizedPath.toUpperCase();
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Same</Name>
    <Path>$caseVariant</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Same',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    expect(await result.backupFile!.exists(), isTrue);
    final xml = await foldersFile.readAsString();
    expect(xml, contains('<Name>Same</Name>'));
    expect(xml, contains('<Path>$normalizedPath</Path>'));
    expect(xml, isNot(contains('<Path>$caseVariant</Path>')));
  });

  test('rewrites case-only SongCore image path differences', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_image_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final image = await File('${temp.path}/Cover.png').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final normalizedImagePath = p.normalize(p.absolute(image.path));
    final imageCaseVariant = normalizedImagePath.toUpperCase();
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Same</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <ImagePath>$imageCaseVariant</ImagePath>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Same',
      imageFile: image,
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    expect(await result.backupFile!.exists(), isTrue);
    final xml = await foldersFile.readAsString();
    expect(xml, contains('<ImagePath>$normalizedImagePath</ImagePath>'));
    expect(xml, isNot(contains('<ImagePath>$imageCaseVariant</ImagePath>')));
    expect(xml, contains('<CustomSort pinned="true">1</CustomSort>'));
  });

  test('clears existing SongCore image path when saving without image',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_image_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Same</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <ImagePath>C:\\Covers\\Old.png</ImagePath>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Same',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    expect(await result.backupFile!.exists(), isTrue);
    expect(await result.backupFile!.readAsString(),
        contains('<ImagePath>C:\\Covers\\Old.png</ImagePath>'));
    final xml = await foldersFile.readAsString();
    expect(xml, isNot(contains('<ImagePath>')));
    expect(xml, contains('<CustomSort pinned="true">1</CustomSort>'));
  });

  test('deduplicates SongCore folder entries with the same path when saving',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_dedupe_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Old A</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
  <folder>
    <Name>Old B</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">2</CustomSort>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    expect(result.entries, hasLength(1));
    expect(result.entries.single.name, 'New');
    final xml = await result.file.readAsString();
    expect('Old A'.allMatches(xml), isEmpty);
    expect('Old B'.allMatches(xml), isEmpty);
    expect(xml, contains('<CustomSort pinned="true">2</CustomSort>'));
  });

  test('deduplicates merged unknown SongCore fields when saving same path',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Old A</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">2</CustomSort>
  </folder>
  <folder>
    <Name>Old B</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">2</CustomSort>
    <CustomTag>keep</CustomTag>
  </folder>
</folders>
''');

    final first = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(first.added, isFalse);
    expect(first.updated, isTrue);
    var xml = await first.file.readAsString();
    expect('<CustomSort pinned="true">2</CustomSort>'.allMatches(xml),
        hasLength(1));
    expect(xml, contains('<CustomTag>keep</CustomTag>'));

    final second = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(second.added, isFalse);
    expect(second.updated, isFalse);
    expect(second.backupFile, isNull);
    xml = await second.file.readAsString();
    expect('<CustomSort pinned="true">2</CustomSort>'.allMatches(xml),
        hasLength(1));
    expect(xml, contains('<CustomTag>keep</CustomTag>'));
  });

  test('deduplicates self closing unknown SongCore fields when merging',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Old A</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomFlag />
  </folder>
  <folder>
    <Name>Old B</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomFlag/>
    <CustomTag>keep</CustomTag>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    final xml = await result.file.readAsString();
    expect('<CustomFlag />'.allMatches(xml), hasLength(1));
    expect('<CustomFlag/>'.allMatches(xml), isEmpty);
    expect(xml, contains('<CustomTag>keep</CustomTag>'));
  });

  test('deduplicates case-only unknown SongCore fields when merging', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Old A</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomFlag />
  </folder>
  <folder>
    <Name>Old B</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <customflag/>
    <CustomTag>keep</CustomTag>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    final xml = await result.file.readAsString();
    expect('<CustomFlag />'.allMatches(xml), hasLength(1));
    expect('<customflag/>'.allMatches(xml), isEmpty);
    expect(xml, contains('<CustomTag>keep</CustomTag>'));
  });

  test('deduplicates attribute-order unknown SongCore fields when merging',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Old A</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true" order="2">keep</CustomSort>
  </folder>
  <folder>
    <Name>Old B</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort order="2" pinned="true">keep</CustomSort>
    <CustomTag>keep</CustomTag>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    final xml = await result.file.readAsString();
    expect(
        '<CustomSort pinned="true" order="2">keep</CustomSort>'.allMatches(xml),
        hasLength(1));
    expect(
        '<CustomSort order="2" pinned="true">keep</CustomSort>'.allMatches(xml),
        isEmpty);
    expect(xml, contains('<CustomTag>keep</CustomTag>'));
  });

  test('deduplicates namespaced unknown SongCore fields when merging',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders xmlns:sc="urn:songcore">
  <folder>
    <Name>Old A</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <sc:CustomSort pinned="true" order="2">keep</sc:CustomSort>
  </folder>
  <folder>
    <Name>Old B</Name>
    <Path>$normalizedPath</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <SC:CustomSort order="2" pinned="true">keep</SC:CustomSort>
    <sc:CustomTag>keep</sc:CustomTag>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    final xml = await result.file.readAsString();
    expect(
      '<sc:CustomSort pinned="true" order="2">keep</sc:CustomSort>'
          .allMatches(xml),
      hasLength(1),
    );
    expect(
      '<SC:CustomSort order="2" pinned="true">keep</SC:CustomSort>'
          .allMatches(xml),
      isEmpty,
    );
    expect(xml, contains('<sc:CustomTag>keep</sc:CustomTag>'));
  });

  test('deduplicates SongCore folder entries with case-only path differences',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_case_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final caseVariant = normalizedPath.toUpperCase();
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Upper</Name>
    <Path>$caseVariant</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    expect(result.entries, hasLength(1));
    expect(result.entries.single.name, 'New');
    expect(result.entries.single.path, normalizedPath);
    final xml = await result.file.readAsString();
    expect(xml, contains('<Path>$normalizedPath</Path>'));
    expect(xml, isNot(contains('<Path>$caseVariant</Path>')));
  });

  test('keeps unknown SongCore folder fields when updating by path', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_update_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Old</Name>
    <Path>${normalizedPath.replaceAll('&', '&amp;')}</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">3</CustomSort>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
      wip: true,
    );

    expect(result.added, isFalse);
    expect(result.updated, isTrue);
    final xml = await result.file.readAsString();
    expect(xml, contains('<Name>New</Name>'));
    expect(xml, contains('<WIP>True</WIP>'));
    expect(xml, contains('<CustomSort pinned="true">3</CustomSort>'));
  });

  test('keeps SongCore root attributes when updating by path', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_root_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-16"?>
<folders version="2" source="songcore">
  <folder>
    <Name>Old</Name>
    <Path>$normalizedPath</Path>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    expect(result.backupFile, isNotNull);
    final backupXml = await result.backupFile!.readAsString();
    expect(backupXml, startsWith('<?xml version="1.0" encoding="utf-16"?>'));
    expect(backupXml, contains('<folders version="2" source="songcore">'));
    expect(backupXml, contains('<Name>Old</Name>'));
    expect(backupXml, isNot(contains('<Name>New</Name>')));
    final xml = await result.file.readAsString();
    expect(xml, startsWith('<?xml version="1.0" encoding="utf-16"?>'));
    expect(xml, contains('<folders version="2" source="songcore">'));
    expect(xml, contains('<Name>New</Name>'));
  });

  test('keeps SongCore folders root casing when updating by path', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_case_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final normalizedPath = p.normalize(p.absolute(folder.path));
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<Folders version="2">
  <Folder>
    <nAmE>Old</nAmE>
    <pAtH>$normalizedPath</pAtH>
    <pAcK>2</pAcK>
    <wIp>TRUE</wIp>
  </Folder>
</Folders>
''');

    final existing = await readSongCoreFolderEntries(foldersFile);
    expect(existing, hasLength(1));
    expect(existing.single.name, 'Old');
    expect(existing.single.path, normalizedPath);
    expect(existing.single.wip, isTrue);

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'New',
    );

    final xml = await result.file.readAsString();
    expect(xml, contains('<Folders version="2">'));
    expect(xml, contains('</Folders>'));
    expect(xml, isNot(contains('</folders>')));
    expect(xml, contains('<Name>New</Name>'));
  });

  test('creates separate SongCore backups for consecutive updates', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_backup_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();

    await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'First',
    );
    final second = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Second',
    );
    final third = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Third',
    );

    expect(second.backupFile, isNotNull);
    expect(third.backupFile, isNotNull);
    expect(second.backupFile!.path, isNot(third.backupFile!.path));
    expect(await second.backupFile!.exists(), isTrue);
    expect(await third.backupFile!.exists(), isTrue);
    expect(await second.backupFile!.readAsString(),
        contains('<Name>First</Name>'));
    expect(await third.backupFile!.readAsString(),
        contains('<Name>Second</Name>'));

    final backups = await Directory(
      '${temp.path}/UserData/SongCore/backups',
    ).list().where((entity) => entity is File).toList();
    expect(backups, hasLength(2));
  });

  test('rebuilds valid SongCore folders.xml when existing root is missing',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_rebuild_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final folder = await Directory('${temp.path}/Pack').create();
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString('not xml at all');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: folder,
      name: 'Recovered',
    );

    expect(result.backupFile, isNotNull);
    expect(await result.backupFile!.readAsString(), 'not xml at all');
    final xml = await result.file.readAsString();
    expect(xml, startsWith('<?xml version="1.0" encoding="utf-8"?>'));
    expect(xml, contains('<folders>'));
    expect(xml, contains('<Name>Recovered</Name>'));
    expect(xml, contains('</folders>'));

    final entries = await readSongCoreFolderEntries(result.file);
    expect(entries, hasLength(1));
    expect(entries.single.name, 'Recovered');
  });

  test('reads SongCore folders.xml entries with element attributes', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_xml_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name lang="zh">A &amp; B</Name>
    <PATH normalized="true">C:\\Beat Saber\\Songs\\A</PATH>
    <Pack source="songcore">2</Pack>
    <WIP value="manual">True</WIP>
    <ImagePath type="png">C:\\Beat Saber\\cover.png</ImagePath>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(1));
    expect(entries.single.name, 'A & B');
    expect(entries.single.path, r'C:\Beat Saber\Songs\A');
    expect(entries.single.pack, 2);
    expect(entries.single.wip, isTrue);
    expect(entries.single.imagePath, r'C:\Beat Saber\cover.png');
  });

  test('reads namespaced SongCore folders.xml entries', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_ns_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<sc:folders xmlns:sc="urn:songcore" version="2">
  <sc:folder>
    <sc:Name>Remove</sc:Name>
    <sc:Path>C:\Beat Saber\Remove</sc:Path>
    <sc:Pack>2</sc:Pack>
    <sc:WIP>False</sc:WIP>
  </sc:folder>
  <sc:folder>
    <sc:Name>Keep</sc:Name>
    <sc:Path>C:\Beat Saber\Keep</sc:Path>
    <sc:Pack>2</sc:Pack>
    <sc:WIP>True</sc:WIP>
    <sc:ImagePath>C:\Covers\Keep.png</sc:ImagePath>
    <sc:Custom>preserved</sc:Custom>
  </sc:folder>
</sc:folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.name, 'Keep');
    expect(entries.last.path, r'C:\Beat Saber\Keep');
    expect(entries.last.pack, 2);
    expect(entries.last.wip, isTrue);
    expect(entries.last.imagePath, r'C:\Covers\Keep.png');
    expect(entries.last.extraXmlElements, ['<sc:Custom>preserved</sc:Custom>']);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<sc:folders xmlns:sc="urn:songcore" version="2">'));
    expect(xml, contains('</sc:folders>'));
    expect(xml, contains('<Name>Keep</Name>'));
    expect(xml, contains('<ImagePath>C:\\Covers\\Keep.png</ImagePath>'));
    expect(xml, contains('<sc:Custom>preserved</sc:Custom>'));
    expect(xml, isNot(contains('<Name>Remove</Name>')));
    expect(xml, isNot(contains('<sc:Name>Keep</sc:Name>')));
  });

  test('ignores mismatched namespaced SongCore folder closing tags', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_bad_ns_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <sc:folder>
    <sc:Name>Broken</sc:Name>
    <sc:Path>C:\Beat Saber\Broken</sc:Path>
  </folder>
  <sc:folder>
    <sc:Name>Keep</sc:Name>
    <sc:Path>C:\Beat Saber\Keep</sc:Path>
  </sc:folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(1));
    expect(entries.single.name, 'Keep');
    expect(entries.single.path, r'C:\Beat Saber\Keep');
  });

  test('skips self closing SongCore folder tags when reading', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_empty_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder />
  <sc:folder/>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(1));
    expect(entries.single.name, 'Keep');
    expect(entries.single.path, r'C:\Beat Saber\Keep');
  });

  test('skips blank and example SongCore folder entries', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_skip_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Example</Name>
    <Path>C:\Beat Saber\Example</Path>
  </folder>
  <folder>
    <Name> example </Name>
    <Path>C:\Beat Saber\Example Lower</Path>
  </folder>
  <folder>
    <Name>Empty Path</Name>
    <Path>   </Path>
  </folder>
  <folder>
    <Name>   </Name>
    <Path>C:\Beat Saber\Blank Name</Path>
  </folder>
  <folder>
    <Name>Real Pack</Name>
    <Path>C:\Beat Saber\Real</Path>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(1));
    expect(entries.single.name, 'Real Pack');
    expect(entries.single.path, r'C:\Beat Saber\Real');
  });

  test('does not rewrite SongCore folders.xml with only placeholder entries',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_empty_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    const xml = r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Example</Name>
    <Path>C:\Beat Saber\Example</Path>
  </folder>
  <folder>
    <Name>Empty Path</Name>
    <Path>   </Path>
  </folder>
</folders>
''';
    await file.writeAsString(xml);

    final result = await removeSongCoreFolderEntries(
      file: file,
      keys: [
        songCoreFolderEntryKey(
          const SongCoreFolderEntry(name: 'Missing Pack', path: r'C:\Missing'),
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removed, 0);
    expect(result.entries, isEmpty);
    expect(result.backupFile, isNull);
    expect(await file.readAsString(), xml);
    expect(await Directory('${temp.path}/backups').exists(), isFalse);
  });

  test('drops blank and example SongCore entries when saving a real entry',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_save_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final songFolder = await Directory('${temp.path}/Packs/Real').create(
      recursive: true,
    );
    final foldersFile = File('${temp.path}/UserData/SongCore/folders.xml');
    await foldersFile.parent.create(recursive: true);
    await foldersFile.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Example</Name>
    <Path>C:\Beat Saber\Example</Path>
  </folder>
  <folder>
    <Name>Empty Path</Name>
    <Path>   </Path>
  </folder>
  <folder>
    <Name>Keep Pack</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');

    final result = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: songFolder,
      name: 'Real Pack',
    );

    expect(result.added, isTrue);
    expect(result.updated, isFalse);
    expect(result.entries.map((entry) => entry.name), [
      'Keep Pack',
      'Real Pack',
    ]);
    expect(await result.backupFile!.exists(), isTrue);
    final xml = await foldersFile.readAsString();
    expect(xml, isNot(contains('<Name>Example</Name>')));
    expect(xml, isNot(contains('<Name>Empty Path</Name>')));
    expect(xml, contains('<Name>Keep Pack</Name>'));
    expect(xml, contains('<CustomSort pinned="true">1</CustomSort>'));
    expect(xml, contains('<Name>Real Pack</Name>'));
  });

  test('uses first repeated SongCore fields and drops duplicate known fields',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_repeat_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>First Name</Name>
    <Name>Second Name</Name>
    <Path>C:\Beat Saber\First Path</Path>
    <Path>C:\Beat Saber\Second Path</Path>
    <Pack>2</Pack>
    <Pack>5</Pack>
    <WIP>False</WIP>
    <WIP>True</WIP>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.name, 'First Name');
    expect(entries.last.path, r'C:\Beat Saber\First Path');
    expect(entries.last.pack, 2);
    expect(entries.last.wip, isFalse);
    expect(entries.last.extraXmlElements, isEmpty);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<Name>First Name</Name>'));
    expect(xml, contains('<Path>C:\\Beat Saber\\First Path</Path>'));
    expect(xml, contains('<Pack>2</Pack>'));
    expect(xml, contains('<WIP>False</WIP>'));
    expect(xml, isNot(contains('Second Name')));
    expect(xml, isNot(contains('Second Path')));
    expect(xml, isNot(contains('<Pack>5</Pack>')));
    expect(xml, isNot(contains('<WIP>True</WIP>')));
  });

  test('defaults missing or invalid SongCore pack to folder pack', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_pack_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Missing Pack</Name>
    <Path>C:\Beat Saber\Missing Pack</Path>
    <WIP>False</WIP>
  </folder>
  <folder>
    <Name>Invalid Pack</Name>
    <Path>C:\Beat Saber\Invalid Pack</Path>
    <Pack>bad</Pack>
    <WIP>True</WIP>
  </folder>
  <folder>
    <Name>Custom Pack</Name>
    <Path>C:\Beat Saber\Custom Pack</Path>
    <Pack>5</Pack>
    <WIP>False</WIP>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries.map((entry) => entry.pack), [2, 2, 5]);
    expect(entries.map((entry) => entry.wip), [false, true, false]);
  });

  test('reads common SongCore WIP boolean variants', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_wip_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>True Text</Name>
    <Path>C:\Beat Saber\True Text</Path>
    <WIP> TRUE </WIP>
  </folder>
  <folder>
    <Name>One</Name>
    <Path>C:\Beat Saber\One</Path>
    <WIP>1</WIP>
  </folder>
  <folder>
    <Name>Yes</Name>
    <Path>C:\Beat Saber\Yes</Path>
    <WIP>yes</WIP>
  </folder>
  <folder>
    <Name>Y</Name>
    <Path>C:\Beat Saber\Y</Path>
    <WIP>Y</WIP>
  </folder>
  <folder>
    <Name>False Text</Name>
    <Path>C:\Beat Saber\False Text</Path>
    <WIP>false</WIP>
  </folder>
  <folder>
    <Name>Zero</Name>
    <Path>C:\Beat Saber\Zero</Path>
    <WIP>0</WIP>
  </folder>
  <folder>
    <Name>Missing</Name>
    <Path>C:\Beat Saber\Missing</Path>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(
      entries.map((entry) => entry.wip),
      [true, true, true, true, false, false, false],
    );
  });

  test('removes selected SongCore folder entries and keeps others', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_');
    addTearDown(() => temp.delete(recursive: true));
    await File('${temp.path}/Beat Saber.exe').create();
    await Directory('${temp.path}/Beat Saber_Data').create();
    final first = await Directory('${temp.path}/First').create();
    final second = await Directory('${temp.path}/Second').create();

    final firstResult = await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: first,
      name: 'First Pack',
    );
    await saveSongCoreFolderEntry(
      gameDirectory: temp,
      songFolder: second,
      name: 'Second Pack',
    );

    final result = await removeSongCoreFolderEntries(
      file: firstResult.file,
      keys: [
        songCoreFolderEntryKey(
          SongCoreFolderEntry(name: 'First Pack', path: first.path),
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removed, 1);
    expect(result.backupFile, isNotNull);
    expect(await result.backupFile!.exists(), isTrue);
    expect(await result.backupFile!.readAsString(), contains('First Pack'));
    expect(result.entries.map((entry) => entry.name), ['Second Pack']);
    final entries = await readSongCoreFolderEntries(firstResult.file);
    expect(entries.map((entry) => entry.name), ['Second Pack']);
    final xml = await firstResult.file.readAsString();
    expect(xml, isNot(contains('First Pack')));
    expect(xml, contains('Second Pack'));
  });

  test('removes SongCore entries by path without matching same-name folders',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_name_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    final first = p.normalize(p.absolute('${temp.path}/First'));
    final second = p.normalize(p.absolute('${temp.path}/Second'));
    await file.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Same Name</Name>
    <Path>$first</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
  <folder>
    <Name>Same Name</Name>
    <Path>$second</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
</folders>
''');

    final result = await removeSongCoreFolderEntries(
      file: file,
      keys: [
        songCoreFolderEntryKey(
            SongCoreFolderEntry(name: 'Same Name', path: first)),
      ],
    );

    expect(result.removed, 1);
    expect(result.entries, hasLength(1));
    expect(result.entries.single.name, 'Same Name');
    expect(result.entries.single.path, second);
    final xml = await file.readAsString();
    expect(xml, isNot(contains('<Path>$first</Path>')));
    expect(xml, contains('<Path>$second</Path>'));
  });

  test('does not rewrite SongCore folders.xml when no remove keys match',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_nomatch_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    final path = p.normalize(p.absolute('${temp.path}/Keep'));
    await file.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Keep Pack</Name>
    <Path>$path</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');
    final before = await file.readAsString();

    final result = await removeSongCoreFolderEntries(
      file: file,
      keys: [
        songCoreFolderEntryKey(
          const SongCoreFolderEntry(name: 'Missing Pack', path: r'C:\Missing'),
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removed, 0);
    expect(result.backupFile, isNull);
    expect(result.entries, hasLength(1));
    expect(await file.readAsString(), before);
    expect(await Directory('${temp.path}/backups').exists(), isFalse);
  });

  test('does not rewrite damaged SongCore folders.xml when removing', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_damaged_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString('not xml at all');

    final result = await removeSongCoreFolderEntries(
      file: file,
      keys: [
        songCoreFolderEntryKey(
          const SongCoreFolderEntry(name: 'Missing Pack', path: r'C:\Missing'),
        ),
      ],
    );

    expect(result.requested, 1);
    expect(result.removed, 0);
    expect(result.entries, isEmpty);
    expect(result.backupFile, isNull);
    expect(await file.readAsString(), 'not xml at all');
    expect(await Directory('${temp.path}/backups').exists(), isFalse);
  });

  test('keeps unknown SongCore folder fields when rewriting entries', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove Pack</Name>
    <Path>C:\\Beat Saber\\Remove</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort>10</CustomSort>
  </folder>
  <folder>
    <Name>Keep Pack</Name>
    <Path>C:\\Beat Saber\\Keep</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, [
      '<CustomSort pinned="true">1</CustomSort>',
    ]);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, isNot(contains('Remove Pack')));
    expect(xml, contains('Keep Pack'));
    expect(xml, contains('<CustomSort pinned="true">1</CustomSort>'));
  });

  test('keeps SongCore comments and self closing unknown fields', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_extra_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <!-- keep this marker -->
    <CustomFlag enabled="true" />
    <Path />
    <CustomSort>1</CustomSort>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, [
      '<!-- keep this marker -->',
      '<CustomFlag enabled="true" />',
      '<CustomSort>1</CustomSort>',
    ]);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<!-- keep this marker -->'));
    expect(xml, contains('<CustomFlag enabled="true" />'));
    expect(xml, contains('<CustomSort>1</CustomSort>'));
    expect(xml, isNot(contains('<Path />')));
  });

  test('keeps SongCore top-level CDATA unknown fields', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_cdata_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <![CDATA[custom <raw> data]]>
    <CustomSort>1</CustomSort>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, [
      '<![CDATA[custom <raw> data]]>',
      '<CustomSort>1</CustomSort>',
    ]);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<![CDATA[custom <raw> data]]>'));
    expect(xml, contains('<CustomSort>1</CustomSort>'));
  });

  test('keeps SongCore processing instruction unknown fields', () async {
    final temp = await Directory.systemTemp.createTemp(
      'song_manager_songcore_processing_instruction_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <?songcore custom="true"?>
    <CustomSort>1</CustomSort>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, [
      '<?songcore custom="true"?>',
      '<CustomSort>1</CustomSort>',
    ]);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<?songcore custom="true"?>'));
    expect(xml, contains('<CustomSort>1</CustomSort>'));
  });

  test('ignores declarations without losing later SongCore unknown fields',
      () async {
    final temp = await Directory.systemTemp.createTemp(
      'song_manager_songcore_declaration_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <!DOCTYPE ignored>
    <CustomSort>1</CustomSort>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, ['<CustomSort>1</CustomSort>']);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, isNot(contains('<!DOCTYPE ignored>')));
    expect(xml, contains('<CustomSort>1</CustomSort>'));
  });

  test('keeps nested unknown SongCore fields without duplicating children',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_nested_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <CustomGroup>
      <!-- child marker -->
      <Child enabled="true" />
    </CustomGroup>
    <AfterGroup />
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, [
      '<CustomGroup>\n'
          '      <!-- child marker -->\n'
          '      <Child enabled="true" />\n'
          '    </CustomGroup>',
      '<AfterGroup />',
    ]);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<CustomGroup>'));
    expect(xml, contains('<!-- child marker -->'));
    expect(xml, contains('<Child enabled="true" />'));
    expect(xml, contains('<AfterGroup />'));
    expect('<Child enabled="true" />'.allMatches(xml), hasLength(1));
  });

  test('keeps same-name nested unknown SongCore fields whole', () async {
    final temp = await Directory.systemTemp.createTemp(
      'song_manager_songcore_same_name_nested_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <CustomGroup>
      <CustomGroup nested="true">child</CustomGroup>
      <After>tail</After>
    </CustomGroup>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(
        entries.last.extraXmlElements.single, contains('<After>tail</After>'));

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<CustomGroup nested="true">child</CustomGroup>'));
    expect(xml, contains('<After>tail</After>'));
    expect('<CustomGroup'.allMatches(xml), hasLength(2));
    expect('</CustomGroup>'.allMatches(xml), hasLength(2));
  });

  test('keeps unknown SongCore fields in original order', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_order_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
    <First>1</First>
    <!-- second -->
    <Third />
    <Fourth>4</Fourth>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);

    expect(entries, hasLength(2));
    expect(entries.last.extraXmlElements, [
      '<First>1</First>',
      '<!-- second -->',
      '<Third />',
      '<Fourth>4</Fourth>',
    ]);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(
      xml.indexOf('<First>1</First>'),
      lessThan(xml.indexOf('<!-- second -->')),
    );
    expect(
      xml.indexOf('<!-- second -->'),
      lessThan(xml.indexOf('<Third />')),
    );
    expect(
      xml.indexOf('<Third />'),
      lessThan(xml.indexOf('<Fourth>4</Fourth>')),
    );
  });

  test('keeps SongCore xml declaration and folders attributes when removing',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_root_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-16"?>
<folders version="2" source="songcore">
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
  </folder>
</folders>
''');
    final entries = await readSongCoreFolderEntries(file);

    final result = await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    expect(result.backupFile, isNotNull);
    final backupXml = await result.backupFile!.readAsString();
    expect(backupXml, startsWith('<?xml version="1.0" encoding="utf-16"?>'));
    expect(backupXml, contains('<folders version="2" source="songcore">'));
    expect(backupXml, contains('<Name>Remove</Name>'));
    expect(backupXml, contains('<Name>Keep</Name>'));
    final xml = await file.readAsString();
    expect(xml, startsWith('<?xml version="1.0" encoding="utf-16"?>'));
    expect(xml, contains('<folders version="2" source="songcore">'));
    expect(xml, contains('<Name>Keep</Name>'));
    expect(xml, isNot(contains('<Name>Remove</Name>')));
  });

  test('keeps escaped SongCore text valid when rewriting entries', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_escape_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove &amp; Drop</Name>
    <Path>C:\Beat Saber\Remove &amp; Drop</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
  </folder>
  <folder>
    <Name>Keep &amp; Play &lt;Live&gt;</Name>
    <Path>C:\Beat Saber\Keep &amp; Play &lt;Live&gt;</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <ImagePath>C:\Beat Saber\Covers\Keep &amp; Play.png</ImagePath>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.name, 'Keep & Play <Live>');
    expect(entries.last.path, r'C:\Beat Saber\Keep & Play <Live>');
    expect(entries.last.imagePath, r'C:\Beat Saber\Covers\Keep & Play.png');

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, isNot(contains('Remove &amp; Drop')));
    expect(xml, contains('<Name>Keep &amp; Play &lt;Live&gt;</Name>'));
    expect(
      xml,
      contains('<Path>C:\\Beat Saber\\Keep &amp; Play &lt;Live&gt;</Path>'),
    );
    expect(
      xml,
      contains(
        '<ImagePath>C:\\Beat Saber\\Covers\\Keep &amp; Play.png</ImagePath>',
      ),
    );

    final reread = await readSongCoreFolderEntries(file);
    expect(reread, hasLength(1));
    expect(reread.single.name, 'Keep & Play <Live>');
    expect(reread.single.path, r'C:\Beat Saber\Keep & Play <Live>');
  });

  test('reads mixed case and numeric SongCore XML entities', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_entity_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep &AMP; Play &#x27;Live&#39; &QUOT;Mix&QUOT;</Name>
    <Path>C:\Beat Saber\Keep &AMP; Play &#x27;Live&#39;</Path>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.name, 'Keep & Play \'Live\' "Mix"');
    expect(entries.last.path, r"C:\Beat Saber\Keep & Play 'Live'");

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(
      xml,
      contains(
        '<Name>Keep &amp; Play &apos;Live&apos; &quot;Mix&quot;</Name>',
      ),
    );
    expect(
      xml,
      contains(
        '<Path>C:\\Beat Saber\\Keep &amp; Play &apos;Live&apos;</Path>',
      ),
    );
  });

  test('keeps invalid numeric SongCore XML entities readable', () async {
    final temp = await Directory.systemTemp.createTemp(
      'song_manager_songcore_invalid_entity_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep &#999999999999;</Name>
    <Path>C:\Beat Saber\Keep &#x999999;</Path>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.name, 'Keep &#999999999999;');
    expect(entries.last.path, r'C:\Beat Saber\Keep &#x999999;');

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<Name>Keep &amp;#999999999999;</Name>'));
    expect(
      xml,
      contains('<Path>C:\\Beat Saber\\Keep &amp;#x999999;</Path>'),
    );
  });

  test('keeps invalid XML code point entities escaped when rewriting',
      () async {
    final temp = await Directory.systemTemp.createTemp(
      'song_manager_songcore_invalid_codepoint_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
  </folder>
  <folder>
    <Name>Keep &#x1; &#xD800;</Name>
    <Path>C:\Beat Saber\Keep &#1;</Path>
  </folder>
</folders>
''');

    final entries = await readSongCoreFolderEntries(file);
    expect(entries, hasLength(2));
    expect(entries.last.name, 'Keep &#x1; &#xD800;');
    expect(entries.last.path, r'C:\Beat Saber\Keep &#1;');

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<Name>Keep &amp;#x1; &amp;#xD800;</Name>'));
    expect(xml, contains('<Path>C:\\Beat Saber\\Keep &amp;#1;</Path>'));
  });

  test('rewrites missing SongCore pack as folder pack', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_pack_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/folders.xml');
    await file.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<folders>
  <folder>
    <Name>Remove</Name>
    <Path>C:\Beat Saber\Remove</Path>
    <Pack>2</Pack>
  </folder>
  <folder>
    <Name>Keep</Name>
    <Path>C:\Beat Saber\Keep</Path>
  </folder>
</folders>
''');
    final entries = await readSongCoreFolderEntries(file);

    await removeSongCoreFolderEntries(
      file: file,
      keys: [songCoreFolderEntryKey(entries.first)],
    );

    final xml = await file.readAsString();
    expect(xml, contains('<Name>Keep</Name>'));
    expect(xml, contains('<Pack>2</Pack>'));
    expect(xml, isNot(contains('<Pack>0</Pack>')));
  });

  test('uses folder name as SongCore entry key when path is empty', () {
    expect(
      songCoreFolderEntryKey(
        const SongCoreFolderEntry(name: '  Fallback Pack  ', path: ''),
      ),
      'fallback pack',
    );
  });

  test('finds installed duplicate groups by id and fallback song name', () {
    final entries = [
      _entry(directoryName: 'abc - First', mapId: 'abc', songName: 'First'),
      _entry(directoryName: 'ABC - Copy', mapId: 'ABC', songName: 'First Copy'),
      _entry(directoryName: 'No Id A', songName: 'Same Song'),
      _entry(directoryName: 'No Id B', songName: 'SameSong'),
      _entry(directoryName: 'Unique', songName: 'Unique'),
    ];

    final groups = findInstalledDuplicateGroups(entries);

    expect(groups, hasLength(2));
    expect(groups[0].kind, InstalledDuplicateKind.mapId);
    expect(groups[0].value, 'abc');
    expect(groups[0].entries.map((entry) => entry.directoryName), [
      'abc - First',
      'ABC - Copy',
    ]);
    expect(groups[1].kind, InstalledDuplicateKind.songName);
    expect(groups[1].value, 'samesong');
    expect(groups[1].entries.map((entry) => entry.directoryName), [
      'No Id A',
      'No Id B',
    ]);
  });

  test('suggests installed path corrections from naming templates', () {
    final entries = [
      _entry(
        directoryName: 'Wrong',
        mapId: 'abc',
        songName: 'Song',
        artist: 'Artist',
        mapper: 'Mapper',
        bpm: 180,
      ),
      _entry(directoryName: 'def - Already', mapId: 'def', songName: 'Already'),
    ];

    final corrections = suggestInstalledPathCorrections(
      entries,
      template: '[id] - [歌名] - [作者] - [制作者] - [bpm]',
    );

    expect(corrections, hasLength(2));
    expect(
      corrections.first.expectedDirectoryName,
      'abc - Song - Artist - Mapper - 180',
    );
    expect(
      installedEntryDirectoryName(
        entries.first,
        template: '[id] - [歌名] - [作者]',
        asciiOnly: true,
      ),
      'abc - Song - Artist',
    );
  });

  test('applies installed path correction by renaming within the same parent',
      () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final source = await Directory('${temp.path}/Wrong').create();
    await File('${source.path}/info.dat').writeAsString('{}');
    final entry = _entryFromDirectory(source, mapId: 'abc', songName: 'Song');

    final renamed = await applyInstalledPathCorrection(
      InstalledPathCorrection(
        entry: entry,
        expectedDirectoryName: 'abc - Song',
      ),
    );

    expect(await source.exists(), isFalse);
    expect(renamed.path, '${temp.path}\\abc - Song');
    expect(await Directory('${temp.path}/abc - Song').exists(), isTrue);
    expect(await File('${temp.path}/abc - Song/info.dat').exists(), isTrue);
  });

  test('refuses installed path correction when target already exists',
      () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final source = await Directory('${temp.path}/Wrong').create();
    await Directory('${temp.path}/abc - Song').create();
    final entry = _entryFromDirectory(source, mapId: 'abc', songName: 'Song');

    expect(
      () => applyInstalledPathCorrection(
        InstalledPathCorrection(
          entry: entry,
          expectedDirectoryName: 'abc - Song',
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await source.exists(), isTrue);
    expect(await Directory('${temp.path}/abc - Song').exists(), isTrue);
  });

  test('refuses scanned path correction when target already exists', () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_scan_');
    addTearDown(() => temp.delete(recursive: true));

    final source = await Directory('${temp.path}/abc - Wrong').create();
    await File('${source.path}/Info.dat').writeAsString('{"_songName":"Song"}');
    final target = await Directory('${temp.path}/abc - Song').create();
    await File('${target.path}/info.dat')
        .writeAsString('{"_songName":"Existing"}');

    final scanned = await scanInstalledLibrary(temp);
    final corrections = suggestInstalledPathCorrections(
      scanned.where((entry) => entry.directoryName == 'abc - Wrong'),
      template: '[id] - [歌名]',
    );

    expect(corrections.single.expectedDirectoryName, 'abc - Song');
    await expectLater(
      applyInstalledPathCorrection(corrections.single),
      throwsA(isA<FileSystemException>()),
    );
    expect(await source.exists(), isTrue);
    expect(await target.exists(), isTrue);
  });

  test('applies path corrections in batches and keeps failed sources',
      () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final first = await Directory('${temp.path}/Wrong A').create();
    final second = await Directory('${temp.path}/Wrong B').create();
    await Directory('${temp.path}/def - Song B').create();

    final result = await applyInstalledPathCorrections([
      InstalledPathCorrection(
        entry: _entryFromDirectory(first, mapId: 'abc', songName: 'Song A'),
        expectedDirectoryName: 'abc - Song A',
      ),
      InstalledPathCorrection(
        entry: _entryFromDirectory(second, mapId: 'def', songName: 'Song B'),
        expectedDirectoryName: 'def - Song B',
      ),
    ]);

    expect(result.requested, 2);
    expect(result.renamed, 1);
    expect(result.failed, 1);
    expect(result.failures, hasLength(1));
    expect(
      p.equals(result.failures.single.sourcePath, p.absolute(second.path)),
      isTrue,
    );
    expect(result.failures.single.expectedDirectoryName, 'def - Song B');
    expect(result.failures.single.reason, 'Target directory already exists');
    expect(await Directory('${temp.path}/abc - Song A').exists(), isTrue);
    expect(await second.exists(), isTrue);
  });

  test('deduplicates batch path corrections by source directory', () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final source = await Directory('${temp.path}/Wrong').create();
    await File('${source.path}/info.dat').writeAsString('{}');
    final entry = _entryFromDirectory(source, mapId: 'abc', songName: 'Song');

    final result = await applyInstalledPathCorrections([
      InstalledPathCorrection(
        entry: entry,
        expectedDirectoryName: 'abc - Song',
      ),
      InstalledPathCorrection(
        entry: entry,
        expectedDirectoryName: 'abc - Song Copy',
      ),
    ]);

    expect(result.requested, 1);
    expect(result.renamed, 1);
    expect(result.failed, 0);
    expect(await source.exists(), isFalse);
    expect(await Directory('${temp.path}/abc - Song').exists(), isTrue);
    expect(await Directory('${temp.path}/abc - Song Copy').exists(), isFalse);
  });

  test('suggests duplicate removal candidates after the first sorted entry',
      () {
    final groups = findInstalledDuplicateGroups([
      _entry(directoryName: 'abc - Keep', mapId: 'abc', songName: 'Keep'),
      _entry(directoryName: 'abc - Remove', mapId: 'ABC', songName: 'Remove'),
      _entry(directoryName: 'same A', songName: 'Same'),
      _entry(directoryName: 'same B', songName: 'Same'),
    ]);

    final candidates = installedDuplicateRemovalCandidates(groups);

    expect(candidates.map((entry) => entry.directoryName), [
      'abc - Remove',
      'same B',
    ]);
  });

  test('backs up and deletes selected duplicate entries', () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final source = await Directory('${temp.path}/abc - Remove').create();
    await File('${source.path}/info.dat').writeAsString('{"_songName":"Song"}');

    final result = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [
        _entryFromDirectory(source, mapId: 'abc', songName: 'Song'),
      ],
      backupDirectory: Directory('${temp.path}/backup'),
    );

    expect(result.requested, 1);
    expect(result.deleted, 1);
    expect(result.backups, hasLength(1));
    expect(await source.exists(), isFalse);
    expect(
        await File('${result.backups.single.path}/info.dat').exists(), isTrue);
  });

  test('does not back up the same duplicate directory twice', () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final source = await Directory('${temp.path}/abc - Remove').create();
    await File('${source.path}/info.dat').writeAsString('{"_songName":"Song"}');
    final entry = _entryFromDirectory(source, mapId: 'abc', songName: 'Song');

    final result = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [entry, entry],
      backupDirectory: Directory('${temp.path}/backup'),
    );

    expect(result.requested, 2);
    expect(result.deleted, 1);
    expect(result.backups, hasLength(1));
    expect(await source.exists(), isFalse);
    expect(
        await File('${result.backups.single.path}/info.dat').exists(), isTrue);
  });

  test('counts missing duplicate directories skipped during backup delete',
      () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_');
    addTearDown(() => temp.delete(recursive: true));
    final existing = await Directory('${temp.path}/abc - Remove').create();
    final missing = Directory('${temp.path}/abc - Already Gone');
    await File('${existing.path}/info.dat')
        .writeAsString('{"_songName":"Song"}');

    final result = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [
        _entryFromDirectory(existing, mapId: 'abc', songName: 'Song'),
        _entryFromDirectory(missing, mapId: 'abc', songName: 'Song'),
      ],
      backupDirectory: Directory('${temp.path}/backup'),
    );

    expect(result.requested, 2);
    expect(result.deleted, 1);
    expect(result.backups, hasLength(1));
    expect(result.skippedMissing, 1);
    expect(await existing.exists(), isFalse);
    expect(await missing.exists(), isFalse);
  });

  test('creates separate duplicate backups for repeated same-name deletes',
      () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_backup_');
    addTearDown(() => temp.delete(recursive: true));
    final backupDirectory = Directory('${temp.path}/backup');

    final firstSource = await Directory('${temp.path}/abc - Remove').create();
    await File('${firstSource.path}/info.dat')
        .writeAsString('{"_songName":"First"}');
    final firstResult = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [
        _entryFromDirectory(firstSource, mapId: 'abc', songName: 'First'),
      ],
      backupDirectory: backupDirectory,
    );

    final secondSource = await Directory('${temp.path}/abc - Remove').create();
    await File('${secondSource.path}/info.dat')
        .writeAsString('{"_songName":"Second"}');
    final secondResult = await deleteInstalledDuplicateEntriesWithBackup(
      entries: [
        _entryFromDirectory(secondSource, mapId: 'abc', songName: 'Second'),
      ],
      backupDirectory: backupDirectory,
    );

    expect(firstResult.backups.single.path,
        isNot(secondResult.backups.single.path));
    expect(
      await File('${firstResult.backups.single.path}/info.dat').readAsString(),
      contains('First'),
    );
    expect(
      await File('${secondResult.backups.single.path}/info.dat').readAsString(),
      contains('Second'),
    );
    final backups = await backupDirectory
        .list()
        .where((entity) => entity is Directory)
        .toList();
    expect(backups, hasLength(2));
  });

  test('scans real library then renames paths and deletes duplicate backups',
      () async {
    final temp = await Directory.systemTemp.createTemp('song_manager_scan_');
    addTearDown(() => temp.delete(recursive: true));

    final wrong = await Directory('${temp.path}/abc - Wrong').create();
    await File('${wrong.path}/Info.dat').writeAsString('''
{
  "_songName": "Correct Song",
  "_songAuthorName": "Artist",
  "_levelAuthorName": "Mapper",
  "_beatsPerMinute": 128
}
''');
    final keep = await Directory('${temp.path}/def - Keep').create();
    await File('${keep.path}/info.dat').writeAsString('{"_songName":"Keep"}');
    final duplicate = await Directory('${temp.path}/DEF - Remove').create();
    await File('${duplicate.path}/info.dat')
        .writeAsString('{"_songName":"Keep Copy"}');
    await File('${duplicate.path}/song.egg').writeAsString('audio');

    final scanned = await scanInstalledLibrary(temp);
    final corrections = suggestInstalledPathCorrections(
      scanned.where((entry) => entry.mapId?.toLowerCase() == 'abc'),
      template: '[id] - [歌名] - [作者] - [制作者] - [bpm]',
    );
    expect(corrections.single.expectedDirectoryName,
        'abc - Correct Song - Artist - Mapper - 128');

    final renameResult = await applyInstalledPathCorrections(corrections);
    expect(renameResult.requested, 1);
    expect(renameResult.renamed, 1);
    expect(
      await Directory('${temp.path}/abc - Correct Song - Artist - Mapper - 128')
          .exists(),
      isTrue,
    );
    expect(await wrong.exists(), isFalse);

    final rescanned = await scanInstalledLibrary(temp);
    final groups = findInstalledDuplicateGroups(rescanned);
    final candidates = installedDuplicateRemovalCandidates(groups);
    expect(candidates.map((entry) => entry.directoryName), ['DEF - Remove']);

    final deleteResult = await deleteInstalledDuplicateEntriesWithBackup(
      entries: candidates,
      backupDirectory: Directory('${temp.path}/backup/duplicates'),
    );
    expect(deleteResult.requested, 1);
    expect(deleteResult.deleted, 1);
    expect(await keep.exists(), isTrue);
    expect(await duplicate.exists(), isFalse);
    expect(
      await File('${deleteResult.backups.single.path}/info.dat').exists(),
      isTrue,
    );
  });

  test('runs real-like Beat Saber SongCore folder lifecycle', () async {
    final temp =
        await Directory.systemTemp.createTemp('song_manager_songcore_real_');
    addTearDown(() => temp.delete(recursive: true));
    final game = await Directory('${temp.path}/Beat Saber').create();
    await File('${game.path}/Beat Saber.exe').create();
    await Directory('${game.path}/Beat Saber_Data').create();
    final customLevels =
        await Directory('${game.path}/Beat Saber_Data/CustomLevels').create();
    final plugins = await Directory('${game.path}/Plugins').create();
    await File('${plugins.path}/SongCore.dll').create();
    await File('${plugins.path}/PlaylistManager.dll').create();

    final firstSong = await Directory('${customLevels.path}/abc - First')
        .create(recursive: true);
    await File('${firstSong.path}/Info.dat')
        .writeAsString('{"_songName":"First"}');
    final secondSong = await Directory('${customLevels.path}/def - Second')
        .create(recursive: true);
    await File('${secondSong.path}/info.dat')
        .writeAsString('{"songName":"Second"}');
    await Directory('${customLevels.path}/broken').create();

    final status = inspectBeatSaberGameDirectory(game);
    expect(status.isBeatSaberDirectory, isTrue);
    expect(status.isSongCoreInstalled, isTrue);
    expect(status.isPlaylistManagerInstalled, isTrue);
    expect(await countValidInstalledSongs(status.customLevelsDirectory), 2);

    final foldersFile = status.songCoreFoldersFile;
    await foldersFile.parent.create(recursive: true);
    final normalizedCustomLevels = p.normalize(p.absolute(customLevels.path));
    await foldersFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<folders version="2">
  <folder>
    <Name>CustomLevels</Name>
    <Path>$normalizedCustomLevels</Path>
    <Pack>2</Pack>
    <WIP>False</WIP>
    <CustomSort pinned="true">1</CustomSort>
  </folder>
</folders>
''');

    final externalPack =
        await Directory('${temp.path}/External Packs/Favorites & Ranked')
            .create(recursive: true);
    final cover = await File('${temp.path}/External Packs/cover.png').create();
    final saveResult = await saveSongCoreFolderEntry(
      gameDirectory: game,
      songFolder: externalPack,
      name: 'Favorites & Ranked',
      imageFile: cover,
    );

    expect(saveResult.added, isTrue);
    expect(saveResult.updated, isFalse);
    expect(saveResult.backupFile, isNotNull);
    expect(await saveResult.backupFile!.exists(), isTrue);
    expect(
      await saveResult.backupFile!.readAsString(),
      isNot(contains('Favorites &amp; Ranked')),
    );
    var xml = await foldersFile.readAsString();
    expect(xml, contains('<folders version="2">'));
    expect(xml, contains('<Name>Favorites &amp; Ranked</Name>'));
    expect(xml, contains('<ImagePath>${p.normalize(p.absolute(cover.path))}'));

    final savedEntries = await readSongCoreFolderEntries(foldersFile);
    expect(savedEntries.map((entry) => entry.name), [
      'CustomLevels',
      'Favorites & Ranked',
    ]);
    expect(savedEntries.first.extraXmlElements, [
      '<CustomSort pinned="true">1</CustomSort>',
    ]);

    final removeResult = await removeSongCoreFolderEntries(
      file: foldersFile,
      keys: [songCoreFolderEntryKey(savedEntries.last)],
    );

    expect(removeResult.requested, 1);
    expect(removeResult.removed, 1);
    expect(removeResult.backupFile, isNotNull);
    expect(await removeResult.backupFile!.exists(), isTrue);
    expect(
      await removeResult.backupFile!.readAsString(),
      contains('<Name>Favorites &amp; Ranked</Name>'),
    );
    expect(await externalPack.exists(), isTrue);
    xml = await foldersFile.readAsString();
    expect(xml, contains('<Name>CustomLevels</Name>'));
    expect(xml, contains('<CustomSort pinned="true">1</CustomSort>'));
    expect(xml, isNot(contains('Favorites &amp; Ranked')));
    expect(await readSongCoreFolderEntries(foldersFile), hasLength(1));
  });
}

InstalledSongEntry _entry({
  required String directoryName,
  String? mapId,
  String songName = '',
  String artist = '',
  String mapper = '',
  double bpm = 0,
}) {
  return InstalledSongEntry(
    directory: Directory('installed/$directoryName'),
    directoryName: directoryName,
    hasInfoDat: true,
    info: InstalledSongInfo(
      songName: songName,
      songSubName: '',
      songAuthorName: artist,
      levelAuthorName: mapper,
      beatsPerMinute: bpm,
    ),
    mapId: mapId,
    title: songName,
  );
}

InstalledSongEntry _entryFromDirectory(
  Directory directory, {
  String? mapId,
  String songName = '',
}) {
  return InstalledSongEntry(
    directory: directory,
    directoryName: directory.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last
        .replaceAll('/', ''),
    hasInfoDat: true,
    info: InstalledSongInfo(
      songName: songName,
      songSubName: '',
      songAuthorName: '',
      levelAuthorName: '',
      beatsPerMinute: 0,
    ),
    mapId: mapId,
    title: songName,
  );
}
