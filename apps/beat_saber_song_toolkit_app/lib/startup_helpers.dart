import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';

import 'settings_helpers.dart';
import 'status_helpers.dart';

class StartupOptions {
  const StartupOptions({
    this.profileName = '',
    this.autoStart = false,
    this.autoExtract = false,
    this.readLocal = false,
    this.autoPack = false,
    this.autoExit = false,
    this.startMinimized = false,
    this.fastLog = false,
  });

  final String profileName;
  final bool autoStart;
  final bool autoExtract;
  final bool readLocal;
  final bool autoPack;
  final bool autoExit;
  final bool startMinimized;
  final bool fastLog;
}

StartupOptions startupOptionsFromArgs(List<String> args) {
  var profileName = '';
  var autoStart = false;
  var autoExtract = false;
  var readLocal = false;
  var autoPack = false;
  var autoExit = false;
  var startMinimized = false;
  var fastLog = false;
  var skipNext = false;

  for (var index = 0; index < args.length; index += 1) {
    if (skipNext) {
      skipNext = false;
      continue;
    }
    final arg = args[index];
    final trimmed = arg.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    const prefixes = [
      '--profile=',
      '-profile=',
      '/profile=',
      '--config=',
      '-config=',
      '/config=',
      '-c=',
      '/c=',
    ];
    for (final prefix in prefixes) {
      if (trimmed.startsWith(prefix)) {
        profileName = trimmed.substring(prefix.length).trim();
        break;
      }
    }
    if (profileName.isNotEmpty && prefixes.any(trimmed.startsWith)) {
      continue;
    }
    final lower = trimmed.toLowerCase();
    if (lower == '-config' || lower == '--config' || lower == '-c') {
      if (index + 1 < args.length &&
          !looksLikeStartupOptionForTest(args[index + 1])) {
        profileName = args[index + 1].trim();
        skipNext = true;
      }
      continue;
    }
    if (lower == '-start' || lower == '--start' || lower == '-s') {
      autoStart = true;
      continue;
    }
    if (lower == '-unzip' || lower == '--unzip' || lower == '-u') {
      autoExtract = true;
      continue;
    }
    if (lower == '-local' || lower == '--local' || lower == '-l') {
      readLocal = true;
      continue;
    }
    if (lower == '-zip' || lower == '--zip' || lower == '-z') {
      autoPack = true;
      continue;
    }
    if (lower == '-exit' || lower == '--exit' || lower == '-e') {
      autoExit = true;
      continue;
    }
    if (lower == '-minimize' || lower == '--minimize' || lower == '-m') {
      startMinimized = true;
      continue;
    }
    if (lower == '-fastlog' || lower == '--fastlog' || lower == '-f') {
      fastLog = true;
      continue;
    }
    if (!trimmed.startsWith('-') && !trimmed.startsWith('/')) {
      profileName = trimmed;
    }
  }
  return StartupOptions(
    profileName: profileName,
    autoStart: autoStart,
    autoExtract: autoExtract,
    readLocal: readLocal,
    autoPack: autoPack,
    autoExit: autoExit,
    startMinimized: startMinimized,
    fastLog: fastLog,
  );
}

bool looksLikeStartupOptionForTest(String value) {
  final lower = value.trim().toLowerCase();
  return const {
    '-config',
    '--config',
    '-c',
    '-start',
    '--start',
    '-s',
    '-unzip',
    '--unzip',
    '-u',
    '-local',
    '--local',
    '-l',
    '-zip',
    '--zip',
    '-z',
    '-exit',
    '--exit',
    '-e',
    '-minimize',
    '--minimize',
    '-m',
    '-fastlog',
    '--fastlog',
    '-f',
  }.contains(lower);
}

bool startupMinimizeNeedsRetryForTest({
  required bool isMinimizedAfterFirstAttempt,
}) => !isMinimizedAfterFirstAttempt;

Map<String, Map<String, dynamic>> profilesFromSettingsForTest(
  Map<String, dynamic> json,
) {
  final value = json['profiles'];
  if (value is! Map) {
    return const {};
  }
  return value.map((key, profile) {
    if (profile is Map<String, dynamic>) {
      return MapEntry(key.toString(), profile);
    }
    if (profile is Map) {
      return MapEntry(key.toString(), Map<String, dynamic>.from(profile));
    }
    return MapEntry(key.toString(), <String, dynamic>{});
  })..removeWhere((key, profile) => key.trim().isEmpty || profile.isEmpty);
}

String selectedStartupProfileForTest({
  required Map<String, Map<String, dynamic>> profiles,
  required String activeProfile,
  required String requestedProfile,
}) {
  final requested = requestedProfile.trim();
  if (requested.isNotEmpty && profiles.containsKey(requested)) {
    return requested;
  }
  final active = activeProfile.trim();
  return profiles.containsKey(active) ? active : '';
}

enum StartupActionForTest { readLocal, fastLog, installSelected }

enum StartupReadLocalActionForTest { scanInstalledLibrary, scanPlaylistSync }

String startupAutoStartModeForTest({required bool autoStart}) =>
    autoStart ? 'installSelected' : 'none';

List<StartupActionForTest> startupActionsForTest({
  required bool readLocal,
  required bool fastLog,
  required bool autoStart,
  required bool busy,
  required bool hasTargetMaps,
}) {
  return [
    if (readLocal) StartupActionForTest.readLocal,
    if (!busy && fastLog) StartupActionForTest.fastLog,
    if (!busy && autoStart && hasTargetMaps)
      StartupActionForTest.installSelected,
  ];
}

StartupReadLocalActionForTest startupReadLocalActionForTest(
  WorkspaceForTest workspace,
) {
  return workspace == WorkspaceForTest.playlistSync
      ? StartupReadLocalActionForTest.scanPlaylistSync
      : StartupReadLocalActionForTest.scanInstalledLibrary;
}

class AutoGameDirectoryInspectionForTest {
  const AutoGameDirectoryInspectionForTest({
    required this.status,
    required this.entries,
    required this.backupDirectory,
    required this.statusText,
  });

  final BeatSaberGameDirectoryStatus status;
  final List<SongCoreFolderEntry> entries;
  final String backupDirectory;
  final String statusText;
}

Future<AutoGameDirectoryInspectionForTest?>
autoInspectConfiguredGameDirectoryForTest(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final status = inspectBeatSaberGameDirectory(Directory(trimmed));
  List<SongCoreFolderEntry> entries;
  try {
    entries = await readSongCoreFolderEntries(status.songCoreFoldersFile);
  } catch (_) {
    entries = const [];
  }
  return AutoGameDirectoryInspectionForTest(
    status: status,
    entries: entries,
    backupDirectory: songCoreBackupDirectoryForTest(
      foldersFilePath: status.songCoreFoldersFile.path,
    ),
    statusText: gameDirectoryInspectStatusForTest(
      isBeatSaberDirectory: status.isBeatSaberDirectory,
      songCoreInstalled: status.isSongCoreInstalled,
      playlistManagerInstalled: status.isPlaylistManagerInstalled,
      path: status.gameDirectory.path,
    ),
  );
}
