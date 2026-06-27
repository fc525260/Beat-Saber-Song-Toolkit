import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'android_storage_channel.dart';
import 'app_info_helpers.dart';
import 'cover_label_helpers.dart';
import 'data_source_helpers.dart';
import 'difficulty_helpers.dart';
import 'download_helpers.dart';
import 'installed_library_helpers.dart';
import 'input_parsing_helpers.dart';
import 'local_cache_helpers.dart';
import 'log_panel.dart';
import 'map_result_widgets.dart';
import 'output_helpers.dart';
import 'playlist_image_helpers.dart';
import 'playlist_sync_helpers.dart';
import 'queue_panel.dart';
import 'queue_helpers.dart';
import 'search_filter_helpers.dart';
import 'settings_helpers.dart';
import 'startup_helpers.dart';
import 'status_helpers.dart';
import 'update_helpers.dart';
import 'workspace_help_helpers.dart';
import 'zip_cache_panel.dart';
import 'zip_cache_helpers.dart';

export 'data_source_helpers.dart';
export 'app_info_helpers.dart';
export 'cover_label_helpers.dart';
export 'difficulty_helpers.dart';
export 'download_helpers.dart';
export 'installed_library_helpers.dart';
export 'input_parsing_helpers.dart';
export 'local_cache_helpers.dart';
export 'log_panel.dart';
export 'map_result_widgets.dart';
export 'output_helpers.dart';
export 'playlist_image_helpers.dart';
export 'playlist_sync_helpers.dart';
export 'queue_panel.dart';
export 'queue_helpers.dart';
export 'search_filter_helpers.dart';
export 'settings_helpers.dart';
export 'startup_helpers.dart';
export 'status_helpers.dart';
export 'update_helpers.dart';
export 'workspace_help_helpers.dart';
export 'zip_cache_panel.dart';
export 'zip_cache_helpers.dart';

part 'form_controls.dart';
part 'panel_primitives.dart';

const _localCacheDataSourceTabIndex = 4;
Future<ReleaseInfo> Function(Uri releaseUrl)? releaseFetcherOverrideForTest;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupOptions = startupOptionsFromArgs(args);
  if (_windowManagerSupported) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: 'Beat Saber Song Toolkit v$appVersionForTest',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      if (startupOptions.startMinimized) {
        await _minimizeStartupWindow();
      } else {
        await windowManager.focus();
      }
    });
  }
  runApp(BeatSaberSongToolkitApp(startupOptions: startupOptions));
}

class BeatSaberSongToolkitApp extends StatelessWidget {
  const BeatSaberSongToolkitApp({
    super.key,
    this.startupProfileName = '',
    this.startupOptions = const StartupOptions(),
  });

  final String startupProfileName;
  final StartupOptions startupOptions;

  @override
  Widget build(BuildContext context) {
    final options = startupProfileName.isEmpty
        ? startupOptions
        : StartupOptions(profileName: startupProfileName);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beat Saber Song Toolkit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        fontFamily: 'Microsoft YaHei',
        fontFamilyFallback: const [
          'Microsoft YaHei UI',
          'SimSun',
          'Noto Sans CJK SC',
          'Source Han Sans SC',
          'Arial Unicode MS',
        ],
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        ),
        visualDensity: VisualDensity.compact,
        scaffoldBackgroundColor: const Color(0xfff8fafc),
        useMaterial3: true,
      ),
      home: HomeScreen(startupOptions: options),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.startupProfileName = '',
    this.startupOptions = const StartupOptions(),
  });

  final String startupProfileName;
  final StartupOptions startupOptions;

  StartupOptions get effectiveStartupOptions {
    return startupProfileName.isEmpty
        ? startupOptions
        : StartupOptions(profileName: startupProfileName);
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _androidStorage = const AndroidStorageChannel();
  BeatSaverClient get _client => _apiClient();
  final _scoreSaberClient = ScoreSaberClient();
  final _coverLabelClient = CoverLabelClient();
  final _queryController = TextEditingController(text: 'camellia');
  final _libraryController = TextEditingController(text: 'installed');
  final _localSongsDirectoryController = TextEditingController();
  final _gameDirectoryController = TextEditingController();
  final _skipExistingDirectoryController = TextEditingController();
  final _downloadController = TextEditingController(text: 'downloads');
  final _playlistController = TextEditingController(
    text: 'exported_playlists/camellia.bplist',
  );
  final _onlinePlaylistController = TextEditingController();
  final _playlistTitleController = TextEditingController(text: 'Beat Saber 歌单');
  final _playlistImageController = TextEditingController();
  final _archiveController = TextEditingController(
    text: 'exported_playlists/songs.zip',
  );
  final _profileNameController = TextEditingController(text: '常用配置');
  final _directoryNameTemplateController = TextEditingController(
    text: '[id] - [歌名]',
  );
  final _installedFilterController = TextEditingController();
  final _manualMapsController = TextEditingController();
  final _skipMapsController = TextEditingController();
  final _beastSaberUrlController = TextEditingController();
  final _beastSaberStartPageController = TextEditingController(text: '1');
  final _scoreSaberMinStarController = TextEditingController(text: '0');
  final _scoreSaberMaxStarController = TextEditingController(text: '50');
  final _uploaderController = TextEditingController();
  final _filterTextController = TextEditingController();
  final _requiredComponentsController = TextEditingController();
  final _excludedComponentsController = TextEditingController();
  final _difficultyFilterController = TextEditingController();
  final _characteristicFilterController = TextEditingController();
  final _includeTagsController = TextEditingController();
  final _excludeTagsController = TextEditingController();
  final _coverTokenController = TextEditingController();
  final _coverIncludeTagsController = TextEditingController();
  final _coverExcludeTagsController = TextEditingController();
  final _coverIncludeConfidenceController = TextEditingController(text: '0.7');
  final _coverExcludeConfidenceController = TextEditingController(text: '0.7');
  final _minDownloadsController = TextEditingController();
  final _minPlaysController = TextEditingController();
  final _maxPlaysController = TextEditingController();
  final _minUpvotesController = TextEditingController();
  final _minUpvoteRatioController = TextEditingController();
  final _maxUpvoteRatioController = TextEditingController();
  final _maxDownvotesController = TextEditingController();
  final _minDownvoteRatioController = TextEditingController();
  final _maxDownvoteRatioController = TextEditingController();
  final _minScoreController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _minBpmController = TextEditingController();
  final _maxBpmController = TextEditingController();
  final _uploadedAfterController = TextEditingController();
  final _uploadedBeforeController = TextEditingController();
  final _minNotesController = TextEditingController();
  final _maxNotesController = TextEditingController();
  final _minBombsController = TextEditingController();
  final _maxBombsController = TextEditingController();
  final _minObstaclesController = TextEditingController();
  final _maxObstaclesController = TextEditingController();
  final _minMapSecondsController = TextEditingController();
  final _maxMapSecondsController = TextEditingController();
  final _minNjsController = TextEditingController();
  final _maxNjsController = TextEditingController();
  final _minNpsController = TextEditingController();
  final _maxNpsController = TextEditingController();
  final _minOffsetController = TextEditingController();
  final _maxOffsetController = TextEditingController();
  final _minEventsController = TextEditingController();
  final _maxEventsController = TextEditingController();
  final _minSageScoreController = TextEditingController();
  final _maxSageScoreController = TextEditingController();
  final _minStarsController = TextEditingController();
  final _maxStarsController = TextEditingController();
  final _minMaxScoreController = TextEditingController();
  final _maxMaxScoreController = TextEditingController();
  final _maxParityErrorsController = TextEditingController();
  final _maxParityWarnsController = TextEditingController();
  final _maxParityResetsController = TextEditingController();
  final _downloadLimitController = TextEditingController();
  final _downloadRetryController = TextEditingController();
  final _downloadTimeoutController = TextEditingController();
  final _maxDownloadThreadsController = TextEditingController(text: '3');
  final _apiBaseUrlController = TextEditingController();
  final _releaseApiController = TextEditingController();
  final _requestRetryController = TextEditingController();
  final _requestTimeoutController = TextEditingController();
  final _userAgentController = TextEditingController();
  final _localCacheSaverController = TextEditingController();

  List<BeatSaverMap> _results = const [];
  List<InstalledSongEntry> _installed = const [];
  BeatSaberGameDirectoryStatus? _gameDirectoryStatus;
  List<SongCoreFolderEntry> _songCoreFolderEntries = const [];
  String? _songCoreLastBackupDirectory;
  List<ZipCacheEntryUiModel> _zipCache = const [];
  List<PlaylistSyncEntry> _playlistSyncEntries = const [];
  List<InstalledSongEntry> _playlistSyncLocalOnlyInstalledEntries = const [];
  Set<String> _selectedPlaylistSyncEntryKeys = const {};
  Set<String> _selectedInstalledPathCorrectionKeys = const {};
  Set<String> _selectedInstalledDuplicateKeys = const {};
  List<BeatSaverMap> _localCacheMaps = const [];
  Map<String, BeatSaverMap> _localCacheHashIndex = const {};
  _LocalCacheFilterCache? _localCacheFilterCache;
  _LocalCacheStatus? _localCacheStatus;
  _LocalCacheDeletedAuditState? _localCacheDeletedAudit;
  LocalCacheSnapshotProgress? _localCacheSnapshotProgress;
  _HashCacheStatus? _hashCacheStatus;
  BeatSaverSearchOrder _searchOrder = BeatSaverSearchOrder.rating;
  int _dataSourceTabIndex = 0;
  int _searchPage = 0;
  int _pageSize = 20;
  int _totalResults = 0;
  int _totalPages = 0;
  double _minRating = 0.0;
  int _maxDurationSeconds = 0;
  bool _curatedOnly = false;
  bool _noodleOnly = false;
  bool _chromaOnly = false;
  bool _cinemaOnly = false;
  bool _rankedOnly = false;
  bool _qualifiedOnly = false;
  bool _hideAi = false;
  bool _regexSearchMode = false;
  bool _filterTitle = false;
  bool _filterSongName = false;
  bool _filterSongAuthor = false;
  bool _filterMapper = false;
  bool _filterDescription = false;
  bool _filterTags = false;
  bool _filterRegexMode = false;
  bool _tagFilterEnabled = false;
  bool _untaggedOnly = false;
  bool _chinesePresetOnly = false;
  bool _coverTagFilterEnabled = false;
  bool _coverAcgPresetEnabled = false;
  bool _coverWaitOnFailure = false;
  bool _coverIncludeMatchAll = false;
  bool _coverExcludeMatchAll = false;
  bool _difficultyMatchAll = false;
  _ResultSource _resultSource = _ResultSource.textSearch;
  bool _requireAllDifficulties = false;
  bool _asciiDirectoryNames = false;
  bool _saveSongListEnabled = true;
  bool _saveSongFilesEnabled = true;
  bool _skipExistingMaps = false;
  bool _multiThreadDownload = false;
  bool _readLocalDataOnStartup = false;
  bool _autoPackOnComplete = false;
  bool _autoExtractOnComplete = false;
  bool _autoStartOnStartup = false;
  bool _autoExitOnComplete = false;
  _DownloadMode _downloadMode = _DownloadMode.localCache;
  _Workspace _workspace = _Workspace.search;
  InstalledFilterModeForTest _installedFilterMode =
      InstalledFilterModeForTest.all;
  PlaylistSyncFilterModeForTest _playlistSyncFilterMode =
      PlaylistSyncFilterModeForTest.all;
  List<String> _profileNames = const [];
  String _activeProfile = '';
  Map<String, BeatSaverMap> _targetMaps = const {};
  final Map<String, List<CoverLabel>> _coverLabelCache = {};
  List<String> _logs = const [];
  List<String> _cachedLogs = const [];
  List<_QueueEntry> _queue = const [];
  String _status = '就绪';
  String _busyDetail = '';
  String? _androidTreeUri;
  bool _busy = false;
  bool _stopRequested = false;
  bool _pauseLogOutput = false;
  bool _playlistSyncTableExpanded = false;
  bool _localCacheSnapshotPauseRequested = false;

  @override
  void initState() {
    super.initState();
    _loadCoverLabelCache();
    _loadHashCacheStatus();
    _loadSettings().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runStartupActions();
      });
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _libraryController.dispose();
    _localSongsDirectoryController.dispose();
    _gameDirectoryController.dispose();
    _skipExistingDirectoryController.dispose();
    _downloadController.dispose();
    _playlistController.dispose();
    _onlinePlaylistController.dispose();
    _playlistTitleController.dispose();
    _playlistImageController.dispose();
    _archiveController.dispose();
    _profileNameController.dispose();
    _directoryNameTemplateController.dispose();
    _installedFilterController.dispose();
    _manualMapsController.dispose();
    _skipMapsController.dispose();
    _beastSaberUrlController.dispose();
    _beastSaberStartPageController.dispose();
    _scoreSaberMinStarController.dispose();
    _scoreSaberMaxStarController.dispose();
    _uploaderController.dispose();
    _filterTextController.dispose();
    _requiredComponentsController.dispose();
    _excludedComponentsController.dispose();
    _difficultyFilterController.dispose();
    _characteristicFilterController.dispose();
    _includeTagsController.dispose();
    _excludeTagsController.dispose();
    _coverTokenController.dispose();
    _coverIncludeTagsController.dispose();
    _coverExcludeTagsController.dispose();
    _coverIncludeConfidenceController.dispose();
    _coverExcludeConfidenceController.dispose();
    _minDownloadsController.dispose();
    _minPlaysController.dispose();
    _maxPlaysController.dispose();
    _minUpvotesController.dispose();
    _minUpvoteRatioController.dispose();
    _maxUpvoteRatioController.dispose();
    _maxDownvotesController.dispose();
    _minDownvoteRatioController.dispose();
    _maxDownvoteRatioController.dispose();
    _minScoreController.dispose();
    _maxScoreController.dispose();
    _minBpmController.dispose();
    _maxBpmController.dispose();
    _uploadedAfterController.dispose();
    _uploadedBeforeController.dispose();
    _minNotesController.dispose();
    _maxNotesController.dispose();
    _minBombsController.dispose();
    _maxBombsController.dispose();
    _minObstaclesController.dispose();
    _maxObstaclesController.dispose();
    _minMapSecondsController.dispose();
    _maxMapSecondsController.dispose();
    _minNjsController.dispose();
    _maxNjsController.dispose();
    _minNpsController.dispose();
    _maxNpsController.dispose();
    _minOffsetController.dispose();
    _maxOffsetController.dispose();
    _minEventsController.dispose();
    _maxEventsController.dispose();
    _minSageScoreController.dispose();
    _maxSageScoreController.dispose();
    _minStarsController.dispose();
    _maxStarsController.dispose();
    _minMaxScoreController.dispose();
    _maxMaxScoreController.dispose();
    _maxParityErrorsController.dispose();
    _maxParityWarnsController.dispose();
    _maxParityResetsController.dispose();
    _downloadLimitController.dispose();
    _downloadRetryController.dispose();
    _downloadTimeoutController.dispose();
    _maxDownloadThreadsController.dispose();
    _apiBaseUrlController.dispose();
    _releaseApiController.dispose();
    _requestRetryController.dispose();
    _requestTimeoutController.dispose();
    _userAgentController.dispose();
    _localCacheSaverController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final entry = '$time  $message';
    setState(() {
      if (_pauseLogOutput) {
        _cachedLogs = [entry, ..._cachedLogs].take(200).toList(growable: false);
      } else {
        _logs = [entry, ..._logs].take(80).toList(growable: false);
      }
    });
  }

  void _toggleLogPause() {
    setState(() {
      if (_pauseLogOutput) {
        _logs = [..._cachedLogs, ..._logs].take(80).toList(growable: false);
        _cachedLogs = const [];
        _pauseLogOutput = false;
        _status = logOutputStatusForTest(paused: false);
      } else {
        _pauseLogOutput = true;
        _status = logOutputStatusForTest(paused: true);
      }
    });
  }

  void _setStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  Future<void> _run(String status, Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _busyDetail = '';
      _status = status;
    });
    _addLog(status);
    try {
      await task();
    } catch (error) {
      setState(() {
        _status = errorStatusForTest(error);
      });
      _addLog(errorStatusForTest(error));
    } finally {
      setState(() {
        _busy = false;
        _busyDetail = '';
      });
    }
  }

  void _requestStopQueue() {
    setState(() {
      _stopRequested = true;
      _status = '已请求停止，当前歌曲完成后停止队列';
    });
    _addLog('已请求停止队列');
  }

  void _clearFinishedQueueItems() {
    setState(() {
      final remainingIds = queueIdsAfterClearingFinishedForTest(
        _queue.map(_queueEntrySnapshotForTest),
      ).toSet();
      _queue = _queue
          .where((entry) => remainingIds.contains(entry.id))
          .toList(growable: false);
      _status = clearedStatusForTest('完成/跳过的队列项', prefix: true);
    });
  }

  void _clearQueue() {
    setState(() {
      _queue = const [];
      _stopRequested = false;
      _status = clearedStatusForTest('队列');
    });
  }

  void _clearLogs() {
    setState(() {
      _logs = const [];
      _cachedLogs = const [];
      _status = clearedStatusForTest('日志');
    });
  }

  Future<void> _exportLogs() async {
    if (_logs.isEmpty && _cachedLogs.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('日志');
      });
      return;
    }

    await _run('正在导出日志...', () async {
      final path = await getSaveLocation(
        suggestedName: defaultLogExportFilenameForTest,
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本日志', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '日志', path: null);
        });
        return;
      }
      final logs = [..._cachedLogs.reversed, ..._logs.reversed];
      await File(path.path).writeAsString(logs.join('\n'), flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: '日志', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '日志', path: path.path));
    });
  }

  Future<void> _checkForUpdates() async {
    final releaseUrl = Uri.tryParse(_releaseApiController.text.trim());
    if (releaseUrl == null ||
        !releaseUrl.hasScheme ||
        releaseUrl.host.isEmpty) {
      const message = '检查更新地址未配置';
      setState(() {
        _status = message;
      });
      _addLog(message);
      return;
    }
    await _run('正在检查更新...', () async {
      final release = await _fetchLatestRelease(releaseUrl);
      final latestVersion = release.tagName;
      if (isRemoteVersionNewerForTest(appVersionForTest, latestVersion)) {
        final message = updateAvailableMessageForTest(
          currentVersion: appVersionForTest,
          release: release,
        );
        setState(() {
          _status = message;
        });
        _addLog(message);
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('发现新版'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      } else {
        final message = updateLatestMessageForTest(appVersionForTest);
        setState(() {
          _status = message;
        });
        _addLog(message);
      }
    });
  }

  Future<void> _showDonateAuthor() async {
    final message = donateAuthorMessageForTest();
    _addLog('打开捐助作者说明');
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('捐助作者'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 260,
                      maxHeight: 360,
                    ),
                    child: Image.asset(
                      'assets/images/sponsor_qr.jpg',
                      fit: BoxFit.contain,
                      semanticLabel: '赞助收款码',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkspaceHelp() async {
    final title = _workspaceHelpTitle(_workspace);
    final sections = _workspaceHelpSections(_workspace);
    _addLog('打开帮助：$title');
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in sections) ...[
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(section.body),
                  if (section != sections.last) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryFailedQueueItems() async {
    final failedEntryIds = retryQueueEntriesForTest(
      _queue.map(_queueEntrySnapshotForTest),
    ).map((entry) => entry.id).toSet();
    final failedEntries = _queue
        .where((entry) => failedEntryIds.contains(entry.id))
        .toList(growable: false);
    if (failedEntries.isEmpty) {
      setState(() {
        _status = noRetryFailedStatusForTest();
      });
      return;
    }

    _stopRequested = false;
    await _run('正在重试 ${failedEntries.length} 个失败项...', () async {
      var installedCount = 0;
      var downloadedCount = 0;
      var skippedCount = 0;
      var failedCount = 0;
      var stoppedCount = 0;
      for (var index = 0; index < failedEntries.length; index += 1) {
        if (_stopRequested) {
          stoppedCount += _markRemainingQueueSkipped(
            failedEntries.skip(index).map((entry) => entry.id),
          );
          break;
        }
        final entry = failedEntries[index];
        _updateQueueEntry(
          entry.id,
          status: _QueueStatus.running,
          clearMessage: true,
        );
        try {
          final map = await _client.getMapById(entry.id);
          _updateQueueEntry(
            entry.id,
            title: _mapTitle(map),
            status: _QueueStatus.running,
            clearMessage: true,
          );
          if (entry.task == _QueueTask.downloadZip) {
            final file = await _downloadZipOne(map);
            downloadedCount += 1;
            _updateQueueEntry(
              entry.id,
              status: _QueueStatus.completed,
              message: file.path,
            );
          } else {
            final installed = await _installOne(map);
            if (installed) {
              installedCount += 1;
              _updateQueueEntry(
                entry.id,
                status: _QueueStatus.completed,
                clearMessage: true,
              );
            } else {
              skippedCount += 1;
              _updateQueueEntry(
                entry.id,
                status: _QueueStatus.skipped,
                clearMessage: true,
              );
            }
          }
        } catch (error) {
          failedCount += 1;
          _updateQueueEntry(
            entry.id,
            status: _QueueStatus.failed,
            message: error.toString(),
          );
          _addLog('重试失败：${entry.id}，$error');
        }
      }
      _setStatus('正在刷新已安装列表...');
      final installed = await scanInstalledLibrary(_libraryDirectory);
      final status =
          '重试完成：安装 $installedCount，下载 $downloadedCount，'
          '跳过 $skippedCount，'
          '停止 $stoppedCount，失败 $failedCount';
      setState(() {
        _installed = installed;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _loadSettings() async {
    try {
      final file = _settingsFile;
      if (!await file.exists()) {
        _applyStartupOptionOverrides();
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        _applyStartupOptionOverrides();
        return;
      }
      final profiles = _profilesFromSettings(decoded);
      final activeProfile = _stringSetting(decoded, 'activeProfile', '');
      final startupOptions = widget.effectiveStartupOptions;
      final requestedProfile = startupOptions.profileName.trim();
      final selectedProfile = selectedStartupProfileForTest(
        profiles: profiles,
        activeProfile: activeProfile,
        requestedProfile: requestedProfile,
      );
      final activeSettings = selectedProfile.isEmpty
          ? null
          : profiles[selectedProfile];
      final settings = activeSettings is Map<String, dynamic>
          ? activeSettings
          : decoded;
      setState(() {
        _profileNames = profiles.keys.toList(growable: false)..sort();
        _activeProfile = activeSettings == null ? '' : selectedProfile;
        _profileNameController.text = activeSettings == null
            ? _profileNameController.text
            : selectedProfile;
      });
      _applySettings(settings);
      _applyStartupOptionOverrides();
      _addLog('已读取配置：${file.path}');
      if (requestedProfile.isNotEmpty) {
        _addLog(
          activeSettings == null
              ? '启动参数配置未找到：$requestedProfile'
              : '启动参数配置已应用：$requestedProfile',
        );
      }
      await _restoreTargetMapsFromSettings(settings);
      await _autoInspectConfiguredGameDirectory();
    } catch (error) {
      _addLog('读取配置失败：$error');
    }
  }

  void _applyStartupOptionOverrides() {
    final options = widget.effectiveStartupOptions;
    final messages = <String>[];
    setState(() {
      if (options.readLocal) {
        _readLocalDataOnStartup = true;
        messages.add('通过启动参数读入：读入本地数据');
      }
      if (options.autoStart) {
        _autoStartOnStartup = true;
        messages.add('通过启动参数读入：启动后自动开始');
      }
      if (options.autoPack) {
        _autoPackOnComplete = true;
        messages.add('通过启动参数读入：完成后自动打包');
      }
      if (options.autoExtract) {
        _autoExtractOnComplete = true;
        messages.add('通过启动参数读入：完成后自动解压');
      }
      if (options.autoExit) {
        _autoExitOnComplete = true;
        messages.add('通过启动参数读入：完成后自动退出');
      }
      if (options.fastLog) {
        messages.add('已识别启动参数：快速输出');
      }
    });
    for (final message in messages) {
      _addLog(message);
    }
  }

  Future<void> _runStartupActions() async {
    if (!mounted) {
      return;
    }
    await _applyStartupWindowOptions();
    if (!mounted) {
      return;
    }
    if (startupActionsForTest(
      readLocal: _readLocalDataOnStartup,
      fastLog: false,
      autoStart: false,
      busy: _busy,
      hasTargetMaps: _targetMaps.isNotEmpty,
    ).contains(StartupActionForTest.readLocal)) {
      switch (startupReadLocalActionForTest(_workspace.toWorkspaceForTest())) {
        case StartupReadLocalActionForTest.scanInstalledLibrary:
          await _refreshInstalled();
          break;
        case StartupReadLocalActionForTest.scanPlaylistSync:
          await _scanPlaylistSync();
          break;
      }
    }
    if (!mounted) {
      return;
    }
    final remainingActions = startupActionsForTest(
      readLocal: false,
      fastLog: widget.effectiveStartupOptions.fastLog,
      autoStart: _autoStartOnStartup,
      busy: _busy,
      hasTargetMaps: _targetMaps.isNotEmpty,
    );
    if (remainingActions.contains(StartupActionForTest.fastLog)) {
      await _runFastLogStartup();
    }
    if (!mounted) {
      return;
    }
    if (startupActionsForTest(
      readLocal: false,
      fastLog: false,
      autoStart: _autoStartOnStartup,
      busy: _busy,
      hasTargetMaps: _targetMaps.isNotEmpty,
    ).contains(StartupActionForTest.installSelected)) {
      await _installSelected();
    }
  }

  Future<void> _runFastLogStartup() async {
    final problem = await fastLogStartupProblemForTest(
      _localCacheSaverController.text,
    );
    if (problem != null) {
      setState(() {
        _status = problem;
      });
      _addLog(problem);
      return;
    }
    _addLog('通过启动参数读入：快速输出（LocalCache.saver）');
    await _readLocalCacheFromFirstPage();
  }

  Future<void> _applyStartupWindowOptions() async {
    if (!widget.effectiveStartupOptions.startMinimized) {
      return;
    }
    if (!_windowManagerSupported) {
      _addLog('已识别启动参数：窗口最小化（当前平台不支持）');
      return;
    }
    try {
      await windowManager.minimize();
      _addLog('通过启动参数读入：窗口最小化');
    } catch (error) {
      _addLog('窗口最小化失败：$error');
    }
  }

  Future<void> _loadCoverLabelCache() async {
    try {
      final file = _coverLabelCacheFile;
      if (!await file.exists()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      _coverLabelCache
        ..clear()
        ..addAll(
          decoded.map((url, value) {
            final labels = value is List
                ? value
                      .whereType<Map<String, dynamic>>()
                      .map(CoverLabel.fromJson)
                      .toList(growable: false)
                : const <CoverLabel>[];
            return MapEntry(url, labels);
          }),
        );
      _addLog('已读取封面标签缓存：${_coverLabelCache.length} 项');
    } catch (error) {
      _addLog('读取封面标签缓存失败：$error');
    }
  }

  Future<void> _saveCoverLabelCache() async {
    try {
      final file = _coverLabelCacheFile;
      await file.parent.create(recursive: true);
      await file.writeAsString(
        coverLabelCacheJsonForTest(_coverLabelCache),
        flush: true,
      );
    } catch (error) {
      _addLog('保存封面标签缓存失败：$error');
    }
  }

  Future<void> _exportCoverLabelCache() async {
    if (_coverLabelCache.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('封面标签缓存');
      });
      return;
    }

    await _run('正在导出封面标签缓存...', () async {
      final path = await getSaveLocation(
        suggestedName: 'cover_label_cache.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '封面标签缓存', path: null);
        });
        return;
      }
      await File(path.path).writeAsString(
        coverLabelCacheJsonForTest(_coverLabelCache),
        flush: true,
      );
      setState(() {
        _status = exportFileStatusForTest(label: '封面标签缓存', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '封面标签缓存', path: path.path));
    });
  }

  Future<void> _clearCoverLabelCache() async {
    final file = _coverLabelCacheFile;
    if (!await _confirmClearCacheFile(
      label: '封面标签',
      path: file.path,
      preserved: '歌曲、ZIP、歌单或 LocalCache.saver',
    )) {
      setState(() {
        _status = '已取消清空封面标签缓存';
      });
      return;
    }
    await _run('正在清空封面标签缓存...', () async {
      _coverLabelCache.clear();
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        _status = '封面标签缓存已清空';
      });
      _addLog('封面标签缓存已清空');
    });
  }

  Future<void> _loadHashCacheStatus() async {
    try {
      final file = _beatSaverHashCacheFile;
      final cache = await readBeatSaverHashCache(file);
      if (!mounted) {
        return;
      }
      setState(() {
        _hashCacheStatus = _HashCacheStatus(
          path: file.path,
          entries: cache.data.length,
          cacheDate: cache.cacheDate,
        );
      });
    } catch (error) {
      _addLog('读取 BeatSaver hash 缓存状态失败：$error');
    }
  }

  Future<void> _exportHashCache() async {
    final file = _beatSaverHashCacheFile;
    if (!await file.exists()) {
      setState(() {
        _status = emptyExportStatusForTest('BeatSaver hash 缓存');
      });
      return;
    }

    await _run('正在导出 BeatSaver hash 缓存...', () async {
      final path = await getSaveLocation(
        suggestedName: 'beatsaver_hash_cache.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(
            label: 'BeatSaver hash 缓存',
            path: null,
          );
        });
        return;
      }
      await file.copy(path.path);
      setState(() {
        _status = exportFileStatusForTest(
          label: 'BeatSaver hash 缓存',
          path: path.path,
        );
      });
      _addLog(
        exportFileStatusForTest(label: 'BeatSaver hash 缓存', path: path.path),
      );
    });
  }

  Future<void> _clearHashCache() async {
    final file = _beatSaverHashCacheFile;
    if (!await _confirmClearCacheFile(
      label: 'BeatSaver hash',
      path: file.path,
      preserved: 'LocalCache.saver、歌曲、ZIP 或歌单',
    )) {
      setState(() {
        _status = '已取消清空 BeatSaver hash 缓存';
      });
      return;
    }
    await _run('正在清空 BeatSaver hash 缓存...', () async {
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        _hashCacheStatus = _HashCacheStatus(
          path: file.path,
          entries: 0,
          cacheDate: '',
        );
        _status = 'BeatSaver hash 缓存已清空';
      });
      _addLog('BeatSaver hash 缓存已清空');
    });
  }

  Future<bool> _confirmClearCacheFile({
    required String label,
    required String path,
    required String preserved,
  }) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认清空$label缓存'),
        content: Text(
          cacheFileClearConfirmTextForTest(
            label: label,
            path: path,
            preserved: preserved,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('清空缓存'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Map<String, Map<String, dynamic>> _profilesFromSettings(
    Map<String, dynamic> json,
  ) {
    return profilesFromSettingsForTest(json);
  }

  Future<void> _restoreTargetMapsFromSettings(Map<String, dynamic> json) async {
    final ids = _stringListSetting(json, 'targetMapIds');
    if (ids.isEmpty) {
      return;
    }

    final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
    var restored = 0;
    var failed = 0;
    for (final id in ids) {
      if (targetMaps.containsKey(id)) {
        continue;
      }
      try {
        final map = await _client.getMapById(id);
        targetMaps[map.id] = map;
        restored += 1;
      } catch (error) {
        failed += 1;
        _addLog('恢复本次歌曲失败：$id，$error');
      }
    }
    if (!mounted) {
      return;
    }
    final status = restoredTargetsStatusForTest(
      restored: restored,
      failed: failed,
    );
    setState(() {
      _targetMaps = targetMaps;
      _status = status;
    });
    _addLog(status);
  }

  Future<void> _saveSettings() async {
    await _run('正在保存配置...', () async {
      final file = _settingsFile;
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert(await _settingsFileJson()),
        flush: true,
      );
      setState(() {
        final profileName = _profileNameController.text.trim();
        if (profileName.isNotEmpty) {
          _activeProfile = profileName;
          _profileNames = {
            ..._profileNames,
            profileName,
          }.toList(growable: false)..sort();
        }
        _status = savedFileStatusForTest(label: '配置', path: file.path);
      });
      _addLog(savedFileStatusForTest(label: '配置', path: file.path));
    });
  }

  Future<void> _saveSettingsSilently() async {
    try {
      final file = _settingsFile;
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert(await _settingsFileJson()),
        flush: true,
      );
    } catch (error) {
      _addLog('静默保存配置失败：$error');
    }
  }

  Future<void> _switchProfile(String profileName) async {
    await _run('正在切换配置：$profileName...', () async {
      final file = _settingsFile;
      if (!await file.exists()) {
        setState(() {
          _status = configFileProblemStatusForTest(
            ConfigFileProblemForTest.missing,
          );
        });
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _status = configFileProblemStatusForTest(
            ConfigFileProblemForTest.invalid,
          );
        });
        return;
      }
      final profiles = _profilesFromSettings(decoded);
      final profile = profiles[profileName];
      if (profile == null) {
        setState(() {
          _status = profileDeleteStatusForTest(
            removed: false,
            profileName: profileName,
          );
        });
        return;
      }
      setState(() {
        _activeProfile = profileName;
        _profileNameController.text = profileName;
        _profileNames = profiles.keys.toList(growable: false)..sort();
      });
      _applySettings(profile);
      await _restoreTargetMapsFromSettings(profile);
      await _autoInspectConfiguredGameDirectory();
      _addLog('已切换配置：$profileName');
    });
  }

  Future<void> _deleteCurrentProfile() async {
    final profileName = _activeProfile.isNotEmpty
        ? _activeProfile
        : _profileNameController.text.trim();
    if (profileName.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('可删除的配置');
      });
      return;
    }
    if (!await _confirmDeleteProfile(profileName)) {
      setState(() {
        _status = '已取消删除配置';
      });
      return;
    }

    await _run('正在删除配置：$profileName...', () async {
      final file = _settingsFile;
      if (!await file.exists()) {
        setState(() {
          _status = configFileProblemStatusForTest(
            ConfigFileProblemForTest.missing,
          );
        });
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _status = configFileProblemStatusForTest(
            ConfigFileProblemForTest.invalid,
          );
        });
        return;
      }
      final profiles = _profilesFromSettings(decoded);
      final removed = profiles.remove(profileName) != null;
      const encoder = JsonEncoder.withIndent('  ');
      final payload = _settingsPayloadJson();
      await file.writeAsString(
        encoder.convert({
          ...payload,
          if (profiles.isNotEmpty) 'profiles': profiles,
        }),
        flush: true,
      );
      setState(() {
        _activeProfile = '';
        _profileNameController.clear();
        _profileNames = profiles.keys.toList(growable: false)..sort();
        _status = profileDeleteStatusForTest(
          removed: removed,
          profileName: profileName,
        );
      });
      _addLog(
        profileDeleteStatusForTest(removed: removed, profileName: profileName),
      );
    });
  }

  Future<bool> _confirmDeleteProfile(String profileName) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除配置'),
        content: Text(profileDeleteConfirmTextForTest(profileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除配置'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<Map<String, Object?>> _settingsFileJson() async {
    final file = _settingsFile;
    final profiles = <String, Map<String, dynamic>>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          profiles.addAll(_profilesFromSettings(decoded));
        }
      } catch (_) {
        // Ignore malformed old settings; saving will replace them.
      }
    }

    final profileName = _profileNameController.text.trim();
    final payload = _settingsPayloadJson();
    if (profileName.isNotEmpty) {
      profiles[profileName] = Map<String, dynamic>.from(payload);
    }
    return {
      ...payload,
      if (profiles.isNotEmpty) 'profiles': profiles,
      if (profileName.isNotEmpty) 'activeProfile': profileName,
    };
  }

  void _applySettings(Map<String, dynamic> json) {
    _queryController.text = _stringSetting(
      json,
      'query',
      _queryController.text,
    );
    _libraryController.text = _stringSetting(
      json,
      'libraryDirectory',
      _libraryController.text,
    );
    _localSongsDirectoryController.text = _stringSetting(
      json,
      'localSongsDirectory',
      '',
    );
    _gameDirectoryController.text = _stringSetting(json, 'gameDirectory', '');
    _skipExistingDirectoryController.text = _stringSetting(
      json,
      'skipExistingDirectory',
      '',
    );
    _downloadController.text = _stringSetting(
      json,
      'downloadDirectory',
      _downloadController.text,
    );
    _playlistController.text = _stringSetting(
      json,
      'playlistPath',
      _playlistController.text,
    );
    _onlinePlaylistController.text = _stringSetting(json, 'onlinePlaylist', '');
    _playlistTitleController.text = _stringSetting(
      json,
      'playlistTitle',
      _playlistTitleController.text,
    );
    _playlistImageController.text = _stringSetting(
      json,
      'playlistImagePath',
      _playlistImageController.text,
    );
    _archiveController.text = _stringSetting(
      json,
      'archivePath',
      _archiveController.text,
    );
    _directoryNameTemplateController.text = _stringSetting(
      json,
      'directoryNameTemplate',
      _directoryNameTemplateController.text,
    );
    _manualMapsController.text = _stringSetting(json, 'manualMaps', '');
    _skipMapsController.text = _stringSetting(json, 'skipMaps', '');
    _beastSaberUrlController.text = _stringSetting(json, 'beastSaberUrl', '');
    _beastSaberStartPageController.text = _stringSetting(
      json,
      'beastSaberStartPage',
      '1',
    );
    _localCacheSaverController.text = _stringSetting(
      json,
      'localCacheSaverPath',
      _localCacheSaverController.text,
    );
    _releaseApiController.text = _stringSetting(
      json,
      'releaseApiUrl',
      _releaseApiController.text,
    );
    _scoreSaberMinStarController.text = _stringSetting(
      json,
      'scoreSaberMinStar',
      '0',
    );
    _scoreSaberMaxStarController.text = _stringSetting(
      json,
      'scoreSaberMaxStar',
      '50',
    );
    _uploaderController.text = _stringSetting(json, 'uploader', '');
    _filterTextController.text = _stringSetting(json, 'filterText', '');
    _requiredComponentsController.text = _stringSetting(
      json,
      'requiredComponents',
      '',
    );
    _excludedComponentsController.text = _stringSetting(
      json,
      'excludedComponents',
      '',
    );
    _difficultyFilterController.text = _stringSetting(
      json,
      'difficultyFilter',
      '',
    );
    _characteristicFilterController.text = _stringSetting(
      json,
      'characteristicFilter',
      '',
    );
    _includeTagsController.text = _stringSetting(json, 'includeTags', '');
    _excludeTagsController.text = _stringSetting(json, 'excludeTags', '');
    _coverTokenController.text = _stringSetting(json, 'coverGcpToken', '');
    _coverIncludeTagsController.text = _stringSetting(
      json,
      'coverIncludeTags',
      '',
    );
    _coverExcludeTagsController.text = _stringSetting(
      json,
      'coverExcludeTags',
      '',
    );
    _coverIncludeConfidenceController.text = _stringSetting(
      json,
      'coverIncludeConfidence',
      '0.7',
    );
    _coverExcludeConfidenceController.text = _stringSetting(
      json,
      'coverExcludeConfidence',
      '0.7',
    );
    _minDownloadsController.text = _stringSetting(json, 'minDownloads', '');
    _minPlaysController.text = _stringSetting(json, 'minPlays', '');
    _maxPlaysController.text = _stringSetting(json, 'maxPlays', '');
    _minUpvotesController.text = _stringSetting(json, 'minUpvotes', '');
    _minUpvoteRatioController.text = _stringSetting(json, 'minUpvoteRatio', '');
    _maxUpvoteRatioController.text = _stringSetting(json, 'maxUpvoteRatio', '');
    _maxDownvotesController.text = _stringSetting(json, 'maxDownvotes', '');
    _minDownvoteRatioController.text = _stringSetting(
      json,
      'minDownvoteRatio',
      '',
    );
    _maxDownvoteRatioController.text = _stringSetting(
      json,
      'maxDownvoteRatio',
      '',
    );
    _minScoreController.text = _stringSetting(json, 'minScore', '');
    _maxScoreController.text = _stringSetting(json, 'maxScore', '');
    _minBpmController.text = _stringSetting(json, 'minBpm', '');
    _maxBpmController.text = _stringSetting(json, 'maxBpm', '');
    _uploadedAfterController.text = _stringSetting(json, 'uploadedAfter', '');
    _uploadedBeforeController.text = _stringSetting(json, 'uploadedBefore', '');
    _minNotesController.text = _stringSetting(json, 'minNotes', '');
    _maxNotesController.text = _stringSetting(json, 'maxNotes', '');
    _minBombsController.text = _stringSetting(json, 'minBombs', '');
    _maxBombsController.text = _stringSetting(json, 'maxBombs', '');
    _minObstaclesController.text = _stringSetting(json, 'minObstacles', '');
    _maxObstaclesController.text = _stringSetting(json, 'maxObstacles', '');
    _minMapSecondsController.text = _stringSetting(json, 'minMapSeconds', '');
    _maxMapSecondsController.text = _stringSetting(json, 'maxMapSeconds', '');
    _minNjsController.text = _stringSetting(json, 'minNjs', '');
    _maxNjsController.text = _stringSetting(json, 'maxNjs', '');
    _minNpsController.text = _stringSetting(json, 'minNps', '');
    _maxNpsController.text = _stringSetting(json, 'maxNps', '');
    _minOffsetController.text = _stringSetting(json, 'minOffset', '');
    _maxOffsetController.text = _stringSetting(json, 'maxOffset', '');
    _minEventsController.text = _stringSetting(json, 'minEvents', '');
    _maxEventsController.text = _stringSetting(json, 'maxEvents', '');
    _minSageScoreController.text = _stringSetting(json, 'minSageScore', '');
    _maxSageScoreController.text = _stringSetting(json, 'maxSageScore', '');
    _minStarsController.text = _stringSetting(json, 'minStars', '');
    _maxStarsController.text = _stringSetting(json, 'maxStars', '');
    _minMaxScoreController.text = _stringSetting(json, 'minMaxScore', '');
    _maxMaxScoreController.text = _stringSetting(json, 'maxMaxScore', '');
    _maxParityErrorsController.text = _stringSetting(
      json,
      'maxParityErrors',
      '',
    );
    _maxParityWarnsController.text = _stringSetting(json, 'maxParityWarns', '');
    _maxParityResetsController.text = _stringSetting(
      json,
      'maxParityResets',
      '',
    );
    _downloadLimitController.text = _stringSetting(json, 'downloadLimit', '');
    _downloadRetryController.text = _stringSetting(json, 'downloadRetry', '');
    _downloadTimeoutController.text = _stringSetting(
      json,
      'downloadTimeoutSeconds',
      '',
    );
    _maxDownloadThreadsController.text = _stringSetting(
      json,
      'maxDownloadThreads',
      _maxDownloadThreadsController.text,
    );
    _apiBaseUrlController.text = _stringSetting(json, 'apiBaseUrl', '');
    _requestRetryController.text = _stringSetting(json, 'requestRetry', '');
    _requestTimeoutController.text = _stringSetting(
      json,
      'requestTimeoutSeconds',
      '',
    );
    _userAgentController.text = _stringSetting(json, 'userAgent', '');

    setState(() {
      _searchOrder = parseBeatSaverSearchOrder(
        _stringSetting(json, 'searchOrder', _searchOrder.apiValue),
      );
      _pageSize = _intSetting(json, 'pageSize', _pageSize);
      _minRating = _doubleSetting(json, 'minRating', _minRating);
      _maxDurationSeconds = _intSetting(
        json,
        'maxDurationSeconds',
        _maxDurationSeconds,
      );
      _curatedOnly = _boolSetting(json, 'curatedOnly', _curatedOnly);
      _noodleOnly = _boolSetting(json, 'noodleOnly', _noodleOnly);
      _chromaOnly = _boolSetting(json, 'chromaOnly', _chromaOnly);
      _cinemaOnly = _boolSetting(json, 'cinemaOnly', _cinemaOnly);
      _rankedOnly = _boolSetting(json, 'rankedOnly', _rankedOnly);
      _qualifiedOnly = _boolSetting(json, 'qualifiedOnly', _qualifiedOnly);
      _hideAi = _boolSetting(json, 'hideAi', _hideAi);
      _regexSearchMode = _boolSetting(
        json,
        'regexSearchMode',
        _regexSearchMode,
      );
      _filterTitle = _boolSetting(json, 'filterTitle', _filterTitle);
      _filterSongName = _boolSetting(json, 'filterSongName', _filterSongName);
      _filterSongAuthor = _boolSetting(
        json,
        'filterSongAuthor',
        _filterSongAuthor,
      );
      _filterMapper = _boolSetting(json, 'filterMapper', _filterMapper);
      _filterDescription = _boolSetting(
        json,
        'filterDescription',
        _filterDescription,
      );
      _filterTags = _boolSetting(json, 'filterTags', _filterTags);
      _filterRegexMode = _boolSetting(
        json,
        'filterRegexMode',
        _filterRegexMode,
      );
      _tagFilterEnabled = _boolSetting(
        json,
        'tagFilterEnabled',
        _tagFilterEnabled,
      );
      _untaggedOnly = _boolSetting(json, 'untaggedOnly', _untaggedOnly);
      _chinesePresetOnly = _boolSetting(
        json,
        'chinesePresetOnly',
        _chinesePresetOnly,
      );
      _coverTagFilterEnabled = _boolSetting(
        json,
        'coverTagFilterEnabled',
        _coverTagFilterEnabled,
      );
      _coverAcgPresetEnabled = _boolSetting(
        json,
        'coverAcgPresetEnabled',
        _coverAcgPresetEnabled,
      );
      _coverWaitOnFailure = _boolSetting(
        json,
        'coverWaitOnFailure',
        _coverWaitOnFailure,
      );
      _coverIncludeMatchAll = _boolSetting(
        json,
        'coverIncludeMatchAll',
        _coverIncludeMatchAll,
      );
      _coverExcludeMatchAll = _boolSetting(
        json,
        'coverExcludeMatchAll',
        _coverExcludeMatchAll,
      );
      _asciiDirectoryNames = _boolSetting(
        json,
        'asciiDirectoryNames',
        _asciiDirectoryNames,
      );
      _saveSongListEnabled = _boolSetting(
        json,
        'saveSongListEnabled',
        _saveSongListEnabled,
      );
      _saveSongFilesEnabled = _boolSetting(
        json,
        'saveSongFilesEnabled',
        _saveSongFilesEnabled,
      );
      _skipExistingMaps = _boolSetting(
        json,
        'skipExistingMaps',
        _skipExistingMaps,
      );
      _multiThreadDownload = _boolSetting(
        json,
        'multiThreadDownload',
        _multiThreadDownload,
      );
      _readLocalDataOnStartup = _boolSetting(
        json,
        'readLocalDataOnStartup',
        _readLocalDataOnStartup,
      );
      _autoPackOnComplete = _boolSetting(
        json,
        'autoPackOnComplete',
        _autoPackOnComplete,
      );
      _autoExtractOnComplete = _boolSetting(
        json,
        'autoExtractOnComplete',
        _autoExtractOnComplete,
      );
      _autoStartOnStartup = _boolSetting(
        json,
        'autoStartOnStartup',
        _autoStartOnStartup,
      );
      _autoExitOnComplete = _boolSetting(
        json,
        'autoExitOnComplete',
        _autoExitOnComplete,
      );
      _workspace = _workspaceSetting(json, _workspace);
      _downloadMode = _downloadModeSetting(json, _downloadMode);
      _requireAllDifficulties = _boolSetting(
        json,
        'requireAllDifficulties',
        _requireAllDifficulties,
      );
      _difficultyMatchAll = _boolSetting(
        json,
        'difficultyMatchAll',
        _difficultyMatchAll,
      );
      _status = configLoadedStatusForTest();
    });
  }

  Map<String, Object?> _settingsPayloadJson() {
    return {
      'query': _queryController.text,
      'libraryDirectory': _libraryController.text,
      'localSongsDirectory': _localSongsDirectoryController.text,
      'gameDirectory': _gameDirectoryController.text,
      'skipExistingDirectory': _skipExistingDirectoryController.text,
      'downloadDirectory': _downloadController.text,
      'playlistPath': _playlistController.text,
      'onlinePlaylist': _onlinePlaylistController.text,
      'playlistTitle': _playlistTitleController.text,
      'playlistImagePath': _playlistImageController.text,
      'archivePath': _archiveController.text,
      'directoryNameTemplate': _directoryNameTemplateController.text,
      'manualMaps': _manualMapsController.text,
      'skipMaps': _skipMapsController.text,
      'beastSaberUrl': _beastSaberUrlController.text,
      'beastSaberStartPage': _beastSaberStartPageController.text,
      'localCacheSaverPath': _localCacheSaverController.text,
      'releaseApiUrl': _releaseApiController.text,
      'scoreSaberMinStar': _scoreSaberMinStarController.text,
      'scoreSaberMaxStar': _scoreSaberMaxStarController.text,
      'filterText': _filterTextController.text,
      'requiredComponents': _requiredComponentsController.text,
      'excludedComponents': _excludedComponentsController.text,
      'includeTags': _includeTagsController.text,
      'excludeTags': _excludeTagsController.text,
      'coverGcpToken': _coverTokenController.text,
      'coverIncludeTags': _coverIncludeTagsController.text,
      'coverExcludeTags': _coverExcludeTagsController.text,
      'coverIncludeConfidence': _coverIncludeConfidenceController.text,
      'coverExcludeConfidence': _coverExcludeConfidenceController.text,
      'targetMapIds': _targetMaps.keys.toList(growable: false),
      'searchOrder': _searchOrder.apiValue,
      'pageSize': _pageSize,
      'minRating': _minRating,
      'maxDurationSeconds': _maxDurationSeconds,
      'curatedOnly': _curatedOnly,
      'noodleOnly': _noodleOnly,
      'chromaOnly': _chromaOnly,
      'cinemaOnly': _cinemaOnly,
      'rankedOnly': _rankedOnly,
      'qualifiedOnly': _qualifiedOnly,
      'hideAi': _hideAi,
      'regexSearchMode': _regexSearchMode,
      'filterTitle': _filterTitle,
      'filterSongName': _filterSongName,
      'filterSongAuthor': _filterSongAuthor,
      'filterMapper': _filterMapper,
      'filterDescription': _filterDescription,
      'filterTags': _filterTags,
      'filterRegexMode': _filterRegexMode,
      'tagFilterEnabled': _tagFilterEnabled,
      'untaggedOnly': _untaggedOnly,
      'chinesePresetOnly': _chinesePresetOnly,
      'coverTagFilterEnabled': _coverTagFilterEnabled,
      'coverAcgPresetEnabled': _coverAcgPresetEnabled,
      'coverWaitOnFailure': _coverWaitOnFailure,
      'coverIncludeMatchAll': _coverIncludeMatchAll,
      'coverExcludeMatchAll': _coverExcludeMatchAll,
      'asciiDirectoryNames': _asciiDirectoryNames,
      'saveSongListEnabled': _saveSongListEnabled,
      'saveSongFilesEnabled': _saveSongFilesEnabled,
      'skipExistingMaps': _skipExistingMaps,
      'downloadMode': _downloadMode.name,
      'requireAllDifficulties': _requireAllDifficulties,
      'difficultyMatchAll': _difficultyMatchAll,
      'difficultyFilter': _difficultyFilterController.text,
      'characteristicFilter': _characteristicFilterController.text,
      'uploader': _uploaderController.text,
      'minDownloads': _minDownloadsController.text,
      'minPlays': _minPlaysController.text,
      'maxPlays': _maxPlaysController.text,
      'minUpvotes': _minUpvotesController.text,
      'minUpvoteRatio': _minUpvoteRatioController.text,
      'maxUpvoteRatio': _maxUpvoteRatioController.text,
      'maxDownvotes': _maxDownvotesController.text,
      'minDownvoteRatio': _minDownvoteRatioController.text,
      'maxDownvoteRatio': _maxDownvoteRatioController.text,
      'minScore': _minScoreController.text,
      'maxScore': _maxScoreController.text,
      'minBpm': _minBpmController.text,
      'maxBpm': _maxBpmController.text,
      'uploadedAfter': _uploadedAfterController.text,
      'uploadedBefore': _uploadedBeforeController.text,
      'minNotes': _minNotesController.text,
      'maxNotes': _maxNotesController.text,
      'minBombs': _minBombsController.text,
      'maxBombs': _maxBombsController.text,
      'minObstacles': _minObstaclesController.text,
      'maxObstacles': _maxObstaclesController.text,
      'minMapSeconds': _minMapSecondsController.text,
      'maxMapSeconds': _maxMapSecondsController.text,
      'minNjs': _minNjsController.text,
      'maxNjs': _maxNjsController.text,
      'minNps': _minNpsController.text,
      'maxNps': _maxNpsController.text,
      'minOffset': _minOffsetController.text,
      'maxOffset': _maxOffsetController.text,
      'minEvents': _minEventsController.text,
      'maxEvents': _maxEventsController.text,
      'minSageScore': _minSageScoreController.text,
      'maxSageScore': _maxSageScoreController.text,
      'minStars': _minStarsController.text,
      'maxStars': _maxStarsController.text,
      'minMaxScore': _minMaxScoreController.text,
      'maxMaxScore': _maxMaxScoreController.text,
      'maxParityErrors': _maxParityErrorsController.text,
      'maxParityWarns': _maxParityWarnsController.text,
      'maxParityResets': _maxParityResetsController.text,
      'downloadLimit': _downloadLimitController.text,
      'downloadRetry': _downloadRetryController.text,
      'downloadTimeoutSeconds': _downloadTimeoutController.text,
      'multiThreadDownload': _multiThreadDownload,
      'maxDownloadThreads': _maxDownloadThreadsController.text,
      'apiBaseUrl': _apiBaseUrlController.text,
      'requestRetry': _requestRetryController.text,
      'requestTimeoutSeconds': _requestTimeoutController.text,
      'userAgent': _userAgentController.text,
      'readLocalDataOnStartup': _readLocalDataOnStartup,
      'autoPackOnComplete': _autoPackOnComplete,
      'autoExtractOnComplete': _autoExtractOnComplete,
      'autoStartOnStartup': _autoStartOnStartup,
      'autoExitOnComplete': _autoExitOnComplete,
      'workspace': _workspace.name,
    };
  }

  Future<void> _search() async {
    await _run('正在搜索 BeatSaver...', () async {
      final response = await _client.searchText(
        BeatSaverSearchOptions(
          query: _queryController.text.trim(),
          page: _searchPage,
          pageSize: _pageSize,
          order: _searchOrder,
          minRating: _minRating <= 0 ? null : _minRating,
          maxDurationSeconds: _maxDurationSeconds <= 0
              ? null
              : _maxDurationSeconds,
          curated: _curatedOnly ? true : null,
          noodle: _noodleOnly ? true : null,
          chroma: _chromaOnly ? true : null,
          cinema: _cinemaOnly ? true : null,
        ),
      );
      final filtered = await _filterSearchResults(response.maps);
      setState(() {
        _resultSource = _ResultSource.textSearch;
        _results = filtered;
        _totalResults = response.metadata.total;
        _totalPages = _pageSize <= 0
            ? 0
            : (response.metadata.total / _pageSize).ceil();
        _status = resultPageStatusForTest(
          pageNumber: _searchPage + 1,
          returnedCount: response.maps.length,
          filteredCount: filtered.length,
        );
      });
      _addLog(
        '搜索完成：第 ${_searchPage + 1} 页，'
        '总数 ${response.metadata.total}，显示 ${filtered.length} 张',
      );
    });
  }

  Future<void> _searchFromFirstPage() async {
    setState(() {
      _searchPage = 0;
    });
    await _search();
  }

  Future<void> _searchUploaderFromFirstPage() async {
    setState(() {
      _searchPage = 0;
    });
    await _searchUploaderMaps();
  }

  Future<void> _searchScoreSaberFromFirstPage() async {
    setState(() {
      _searchPage = 0;
    });
    await _searchScoreSaberMaps();
  }

  Future<void> _searchBeastSaberFromStartPage() async {
    final startPage =
        int.tryParse(_beastSaberStartPageController.text.trim()) ?? 1;
    setState(() {
      _searchPage = startPage <= 1 ? 0 : startPage - 1;
    });
    await _searchBeastSaberMaps();
  }

  Future<void> _readLocalCacheFromFirstPage() async {
    setState(() {
      _dataSourceTabIndex = _localCacheDataSourceTabIndex;
      _searchPage = 0;
    });
    await _readLocalCacheMaps();
  }

  Future<void> _searchUploaderMaps() async {
    final uploaderText = _uploaderController.text.trim();
    if (uploaderText.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('填写上传者 ID 或谱师名');
      });
      return;
    }

    await _run('正在读取谱师 $uploaderText 的谱面...', () async {
      final user = await _resolveUploaderUser(uploaderText);
      final uploaderId = user?.id ?? int.parse(uploaderText);
      final uploaderLabel = user == null
          ? uploaderId.toString()
          : '${user.name} #$uploaderId';
      final response = await _client.searchUploaderMaps(
        uploaderId: uploaderId,
        page: _searchPage,
        pageSize: _pageSize,
      );
      final filtered = await _filterSearchResults(response.maps);
      setState(() {
        _resultSource = _ResultSource.uploader;
        _results = filtered;
        _totalResults = response.metadata.total;
        _totalPages = _pageSize <= 0
            ? 0
            : (response.metadata.total / _pageSize).ceil();
        _status = resultPageStatusForTest(
          prefix: '谱师 $uploaderLabel ',
          pageNumber: _searchPage + 1,
          returnedCount: response.maps.length,
          filteredCount: filtered.length,
        );
      });
      _addLog(
        '谱师数据源完成：$uploaderLabel，第 ${_searchPage + 1} 页，'
        '总数 ${response.metadata.total}，显示 ${filtered.length} 张',
      );
    });
  }

  Future<BeatSaverUser?> _resolveUploaderUser(String input) async {
    final query = uploaderQueryForTest(input);
    if (query.uploaderId != null) {
      return null;
    }
    return _client.getUserByName(query.name);
  }

  Future<void> _searchScoreSaberMaps() async {
    await _run('正在读取 ScoreSaber 谱面...', () async {
      final response = await _scoreSaberClient.maps(
        page: _searchPage + 1,
        minStar: _parseDouble(_scoreSaberMinStarController.text) ?? 0,
        maxStar: _parseDouble(_scoreSaberMaxStarController.text) ?? 50,
        ranked: true,
      );
      final result = await _getMapsByIdsWithFailures(
        response.beatSaverIds,
        logPrefix: 'ScoreSaber 谱面详情获取失败',
      );
      final maps = result.maps;
      final failed = result.failed;
      final filtered = await _filterSearchResults(maps);
      setState(() {
        _resultSource = _ResultSource.scoreSaber;
        _results = filtered;
        _totalResults = response.total <= 0
            ? response.beatSaverIds.length
            : response.total;
        _totalPages = _pageSize <= 0 ? 0 : (_totalResults / _pageSize).ceil();
        _status = sourcePageStatusForTest(
          sourceName: 'ScoreSaber',
          pageNumber: _searchPage + 1,
          visibleCount: filtered.length,
          failed: failed,
        );
      });
      _addLog(
        'ScoreSaber 数据源完成：第 ${_searchPage + 1} 页，'
        'BeatSaver ID ${response.beatSaverIds.length}，显示 ${filtered.length}，失败 $failed',
      );
    });
  }

  Future<void> _searchBeastSaberMaps() async {
    final firstPageUrl = _beastSaberUrlController.text.trim();
    if (firstPageUrl.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('输入 BEASTSABER 第一页地址');
      });
      return;
    }

    final pageNumber = _searchPage + 1;
    final pageUrl = _beastSaberPageUrl(firstPageUrl, pageNumber);
    await _run('正在读取 BEASTSABER 第 $pageNumber 页...', () async {
      final html = await _readTextFromUrl(pageUrl);
      final hashes = _parseBeastSaberPreviewHashes(html);
      final maps = <BeatSaverMap>[];
      var failed = 0;
      for (final hash in hashes) {
        try {
          maps.add(await _client.getMapByHash(hash));
        } catch (error) {
          failed += 1;
          _addLog('BEASTSABER 谱面详情获取失败：$hash，$error');
        }
      }
      final filtered = await _filterSearchResults(maps);
      setState(() {
        _resultSource = _ResultSource.beastSaber;
        _results = filtered;
        _totalResults = maps.length;
        _totalPages = pageNumber + (hashes.isEmpty ? 0 : 1);
        _status = sourcePageStatusForTest(
          sourceName: 'BEASTSABER',
          pageNumber: pageNumber,
          visibleCount: filtered.length,
          failed: failed,
        );
      });
      _addLog(
        'BEASTSABER 数据源完成：第 $pageNumber 页，'
        'hash ${hashes.length}，显示 ${filtered.length}，失败 $failed',
      );
    });
  }

  Future<void> _pickLocalCacheSaverFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LocalCache.saver 数据缓存', extensions: ['saver']),
        XTypeGroup(label: 'JSON', extensions: ['json']),
        XTypeGroup(label: '所有文件', extensions: ['*']),
      ],
    );
    if (file == null) {
      setState(() {
        _status = pathSelectionStatusForTest(
          label: 'LocalCache.saver',
          path: null,
        );
      });
      return;
    }
    _localCacheSaverController.text = file.path;
    await _readLocalCacheFromFirstPage();
  }

  Future<void> _readLocalCacheMaps() async {
    final cachePath = _localCacheSaverController.text.trim();
    if (cachePath.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择 LocalCache.saver');
      });
      return;
    }

    await _run('正在读取 LocalCache.saver...', () async {
      final cacheFile = File(cachePath);
      final stat = await cacheFile.stat();
      final generatedAt = await readLocalCacheTime(
        File(
          '${cacheFile.parent.path}${Platform.pathSeparator}LocalCache.time',
        ),
      );
      final cacheInfo = await readLocalCacheSaverInfo(cacheFile);
      final response = await readLocalCacheSaver(cacheFile);
      _localCacheMaps = response.maps;
      _localCacheHashIndex = localCacheHashIndexForTest(response.maps);
      _localCacheFilterCache = null;
      await _writeLocalCacheIndex(cacheFile, stat, response.maps);
      _localCacheStatus = _LocalCacheStatus(
        path: cachePath,
        bytes: stat.size,
        modified: stat.modified,
        generatedAt: generatedAt ?? cacheInfo.generatedAt,
        incrementalUpdatedAt: cacheInfo.incrementalUpdatedAt,
        incrementalAdded: cacheInfo.incrementalAdded,
        incrementalUpdated: cacheInfo.incrementalUpdated,
        maps: response.maps.length,
      );
      final page = await _localCachePage();
      setState(() {
        _resultSource = _ResultSource.localCache;
        _results = page.maps;
        _totalResults = page.total;
        _totalPages = page.totalPages;
        _status = localCacheReadStatusForTest(
          mapCount: _localCacheMaps.length,
          filteredCount: page.total,
          pageNumber: _searchPage + 1,
          totalPages: _totalPages,
        );
      });
      _addLog(
        localCacheReadLogForTest(
          mapCount: _localCacheMaps.length,
          filteredCount: page.total,
          visibleCount: page.maps.length,
          bytes: stat.size,
          modified: stat.modified,
          generatedAt: generatedAt,
        ),
      );
    });
  }

  Future<void> _buildLocalCacheSnapshot({required bool reset}) async {
    var cachePath = _localCacheSaverController.text.trim();
    if (cachePath.isEmpty) {
      cachePath = _defaultLocalCacheSaverFile.path;
      _localCacheSaverController.text = cachePath;
    }
    final outputFile = File(cachePath);
    final stateFile = File('${outputFile.path}.snapshot_state.json');
    final partialFile = File('${outputFile.path}.partial.ndjson');
    final hasResumeState =
        await stateFile.exists() || await partialFile.exists();
    final shouldRefresh = await shouldRefreshLocalCacheSnapshot(
      outputFile,
      refreshAfter: const Duration(days: 15),
    );
    if (!reset && !hasResumeState && !shouldRefresh) {
      setState(() {
        _status = 'LocalCache.saver 未超过 15 天，继续使用本地快照：$cachePath';
      });
      _addLog(_status);
      return;
    }

    _localCacheSnapshotPauseRequested = false;
    await _run(
      reset || !hasResumeState
          ? '正在重建 BeatSaver 本地快照...'
          : '正在继续 BeatSaver 本地快照...',
      () async {
        final result = await buildLocalCacheSnapshot(
          outputFile: outputFile,
          client: _client,
          reset: reset,
          options: const LocalCacheSnapshotOptions(
            pageSize: 100,
            delayBetweenRequests: Duration(milliseconds: 750),
            refreshAfter: Duration(days: 15),
          ),
          shouldPause: () => _localCacheSnapshotPauseRequested,
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _localCacheSnapshotProgress = progress;
              _busyDetail =
                  '本地快照：${progress.pagesFetched} 页，${progress.fetchedMaps} 张'
                  '${progress.nextBefore == null ? '' : '，游标 ${progress.nextBefore}'}';
            });
          },
        );
        if (result.completed) {
          final timeFile = File(
            '${outputFile.parent.path}${Platform.pathSeparator}LocalCache.time',
          );
          await timeFile.writeAsString(
            DateTime.now().toUtc().toIso8601String(),
            flush: true,
          );
          setState(() {
            _status =
                'BeatSaver 本地快照构建完成：${result.fetchedMaps} 张，${outputFile.path}';
          });
          _addLog(_status);
          await _readLocalCacheMaps();
        } else if (result.paused) {
          setState(() {
            _status =
                'BeatSaver 本地快照已暂停：${result.pagesFetched} 页，${result.fetchedMaps} 张';
          });
          _addLog(_status);
        }
      },
    );
  }

  Future<void> _updateLocalCacheSnapshot() async {
    var cachePath = _localCacheSaverController.text.trim();
    if (cachePath.isEmpty) {
      cachePath = _defaultLocalCacheSaverFile.path;
      _localCacheSaverController.text = cachePath;
    }
    final outputFile = File(cachePath);
    if (!await outputFile.exists()) {
      setState(() {
        _status = missingLocalCacheForIncrementalUpdateStatusForTest();
      });
      _addLog(_status);
      return;
    }

    _localCacheSnapshotPauseRequested = false;
    await _run('正在增量更新 BeatSaver 本地快照...', () async {
      final result = await updateLocalCacheSnapshot(
        outputFile: outputFile,
        client: _client,
        options: const LocalCacheSnapshotOptions(
          pageSize: 100,
          delayBetweenRequests: Duration(milliseconds: 750),
          refreshAfter: Duration(days: 15),
        ),
        shouldPause: () => _localCacheSnapshotPauseRequested,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _localCacheSnapshotProgress = progress;
            _busyDetail =
                '增量快照：${progress.pagesFetched} 页，${progress.fetchedMaps} 张'
                '${progress.nextBefore == null ? '' : '，游标 ${progress.nextBefore}'}';
          });
        },
      );
      if (result.completed) {
        final timeFile = File(
          '${outputFile.parent.path}${Platform.pathSeparator}LocalCache.time',
        );
        await timeFile.writeAsString(
          DateTime.now().toUtc().toIso8601String(),
          flush: true,
        );
        setState(() {
          _status =
              'BeatSaver 本地快照增量更新完成：新增 ${result.addedMaps} 张，'
              '更新 ${result.updatedMaps} 张，总计 ${result.totalMaps} 张';
        });
        _addLog(_status);
        await _readLocalCacheMaps();
      } else if (result.paused) {
        setState(() {
          _status =
              'BeatSaver 本地快照增量更新已暂停：${result.pagesFetched} 页，${result.fetchedMaps} 张';
        });
        _addLog(_status);
      }
    });
  }

  Future<void> _auditLocalCacheDeleted() async {
    var cachePath = _localCacheSaverController.text.trim();
    if (cachePath.isEmpty) {
      cachePath = _defaultLocalCacheSaverFile.path;
      _localCacheSaverController.text = cachePath;
    }
    final outputFile = File(cachePath);
    if (!await outputFile.exists()) {
      setState(() {
        _status = '请先选择或生成 LocalCache.saver 后再审计删除候选';
      });
      _addLog(_status);
      return;
    }

    await _run('正在审计 BeatSaver 删除候选...', () async {
      final result = await auditLocalCacheDeletedCandidates(
        outputFile: outputFile,
        client: _client,
        options: const LocalCacheSnapshotOptions(
          pageSize: 100,
          maxPages: 1,
          delayBetweenRequests: Duration.zero,
        ),
      );
      final localMatches = result.candidates
          .where((candidate) => candidate.inLocalCache)
          .length;
      setState(() {
        _localCacheDeletedAudit = _LocalCacheDeletedAuditState(
          cachePath: outputFile.absolute.path,
          result: result,
        );
        _status =
            'BeatSaver 删除候选审计完成：删除记录 ${result.deletedMaps.length} 条，'
            '命中本地缓存 $localMatches 条；未修改 LocalCache.saver';
      });
      _addLog(_status);
    });
  }

  Future<void> _exportLocalCacheDeletedAudit() async {
    final auditState = _localCacheDeletedAudit;
    if (auditState == null) {
      setState(() {
        _status = '请先执行审计删除，再导出删除候选报告';
      });
      _addLog(_status);
      return;
    }
    if (auditState.cachePath.toLowerCase() !=
        _currentLocalCacheSaverFile.absolute.path.toLowerCase()) {
      setState(() {
        _status = '当前 LocalCache.saver 路径已变化，请重新审计删除候选';
      });
      _addLog(_status);
      return;
    }
    await _run('正在导出删除候选报告...', () async {
      final path = await getSaveLocation(
        suggestedName: 'local_cache_deleted_candidates.tsv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'TSV', extensions: ['tsv']),
          XTypeGroup(label: '文本', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '删除候选报告', path: null);
        });
        return;
      }
      final lines = localCacheDeletedAuditExportRowsForTest(auditState.result);
      await File(path.path).writeAsString(lines.join('\n'), flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: '删除候选报告', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '删除候选报告', path: path.path));
    });
  }

  void _pauseLocalCacheSnapshot() {
    _localCacheSnapshotPauseRequested = true;
    setState(() {
      _status = '已请求暂停 BeatSaver 本地快照，当前页完成后暂停';
    });
    _addLog(_status);
  }

  Future<void> _showLocalCachePage() async {
    if (_localCacheMaps.isEmpty) {
      await _readLocalCacheMaps();
      return;
    }
    final page = await _localCachePage();
    setState(() {
      _results = page.maps;
      _totalResults = page.total;
      _totalPages = page.totalPages;
      _status =
          '本地数据缓存：筛选后 ${page.total} 张，'
          '第 ${_searchPage + 1}/${_totalPages == 0 ? 1 : _totalPages} 页';
    });
  }

  Future<_LocalCachePage> _localCachePage() async {
    final filtered = await _filteredLocalCacheMaps();
    final pageMaps = _pageLocalCacheMaps(filtered);
    final totalPages = localCacheTotalPagesForTest(
      itemCount: filtered.length,
      pageSize: _pageSize,
    );
    return _LocalCachePage(
      maps: pageMaps,
      total: filtered.length,
      totalPages: totalPages,
    );
  }

  List<BeatSaverMap> _pageLocalCacheMaps(List<BeatSaverMap> maps) {
    return pagedLocalCacheItemsForTest(
      maps,
      page: _searchPage,
      pageSize: _pageSize,
    );
  }

  Future<List<BeatSaverMap>> _filteredLocalCacheMaps() async {
    final signature = _localCacheFilterSignature();
    final cached = _localCacheFilterCache;
    if (cached != null &&
        identical(cached.source, _localCacheMaps) &&
        cached.signature == signature) {
      return cached.maps;
    }
    final indexed = await _indexedLocalCacheSearchMaps();
    if (indexed != null) {
      _localCacheFilterCache = _LocalCacheFilterCache(
        source: _localCacheMaps,
        signature: signature,
        maps: indexed,
      );
      return indexed;
    }
    final filtered = await _filterSearchResults(_localCacheMaps);
    _localCacheFilterCache = _LocalCacheFilterCache(
      source: _localCacheMaps,
      signature: signature,
      maps: filtered,
    );
    return filtered;
  }

  Future<List<BeatSaverMap>?> _indexedLocalCacheSearchMaps() async {
    if (!_canUseLocalCacheIndexSearch()) {
      return null;
    }
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return null;
    }
    final index = await _readValidLocalCacheIndex();
    if (index == null) {
      return null;
    }
    final mapsById = {
      for (final map in _localCacheMaps) map.id.toLowerCase(): map,
    };
    final matched = <BeatSaverMap>[];
    for (final entry in index.search(query)) {
      final map = mapsById[entry.id];
      if (map != null) {
        matched.add(map);
      }
    }
    _addLog('LocalCache 轻量索引搜索：${matched.length} 首');
    return matched;
  }

  bool _canUseLocalCacheIndexSearch() {
    return canUseLocalCacheIndexSearchForTest(
      query: _queryController.text,
      regexSearchMode: _regexSearchMode,
      uploader: _uploaderController.text,
      filterText: _filterTextController.text,
      filterRegexMode: _filterRegexMode,
      includeTags: _includeTagsController.text,
      excludeTags: _excludeTagsController.text,
      requiredComponents: _requiredComponentsController.text,
      excludedComponents: _excludedComponentsController.text,
      difficultyFilter: _difficultyFilterController.text,
      characteristicFilter: _characteristicFilterController.text,
      hasNumericOrDateFilters: _hasLocalCacheNumericOrDateFilters(),
      hasSwitchFilters:
          _curatedOnly ||
          _noodleOnly ||
          _chromaOnly ||
          _cinemaOnly ||
          _rankedOnly ||
          _qualifiedOnly ||
          _hideAi ||
          _tagFilterEnabled ||
          _untaggedOnly ||
          _chinesePresetOnly ||
          _coverTagFilterEnabled ||
          _difficultyMatchAll ||
          _requireAllDifficulties,
    );
  }

  bool _hasLocalCacheNumericOrDateFilters() {
    return [
          _minDownloadsController,
          _minPlaysController,
          _maxPlaysController,
          _minUpvotesController,
          _minUpvoteRatioController,
          _maxUpvoteRatioController,
          _maxDownvotesController,
          _minDownvoteRatioController,
          _maxDownvoteRatioController,
          _minScoreController,
          _maxScoreController,
          _minBpmController,
          _maxBpmController,
          _uploadedAfterController,
          _uploadedBeforeController,
          _minNotesController,
          _maxNotesController,
          _minBombsController,
          _maxBombsController,
          _minObstaclesController,
          _maxObstaclesController,
          _minMapSecondsController,
          _maxMapSecondsController,
          _minNjsController,
          _maxNjsController,
          _minNpsController,
          _maxNpsController,
          _minOffsetController,
          _maxOffsetController,
          _minEventsController,
          _maxEventsController,
          _minSageScoreController,
          _maxSageScoreController,
          _minStarsController,
          _maxStarsController,
          _minMaxScoreController,
          _maxMaxScoreController,
          _maxParityErrorsController,
          _maxParityWarnsController,
          _maxParityResetsController,
          _coverIncludeConfidenceController,
          _coverExcludeConfidenceController,
        ].any((controller) => controller.text.trim().isNotEmpty) ||
        _minRating > 0 ||
        _maxDurationSeconds > 0;
  }

  String _localCacheFilterSignature() {
    return [
      _uploaderController.text,
      _queryController.text,
      _regexSearchMode,
      _filterTextController.text,
      _filterRegexMode,
      _filterTitle,
      _filterSongName,
      _filterSongAuthor,
      _filterMapper,
      _filterDescription,
      _filterTags,
      _includeTagsController.text,
      _excludeTagsController.text,
      _requiredComponentsController.text,
      _excludedComponentsController.text,
      _difficultyFilterController.text,
      _characteristicFilterController.text,
      _minDownloadsController.text,
      _minPlaysController.text,
      _maxPlaysController.text,
      _minUpvotesController.text,
      _minUpvoteRatioController.text,
      _maxUpvoteRatioController.text,
      _maxDownvotesController.text,
      _minDownvoteRatioController.text,
      _maxDownvoteRatioController.text,
      _minScoreController.text,
      _maxScoreController.text,
      _minBpmController.text,
      _maxBpmController.text,
      _uploadedAfterController.text,
      _uploadedBeforeController.text,
      _minNotesController.text,
      _maxNotesController.text,
      _minBombsController.text,
      _maxBombsController.text,
      _minObstaclesController.text,
      _maxObstaclesController.text,
      _minMapSecondsController.text,
      _maxMapSecondsController.text,
      _minNjsController.text,
      _maxNjsController.text,
      _minNpsController.text,
      _maxNpsController.text,
      _minOffsetController.text,
      _maxOffsetController.text,
      _minEventsController.text,
      _maxEventsController.text,
      _minSageScoreController.text,
      _maxSageScoreController.text,
      _minStarsController.text,
      _maxStarsController.text,
      _minMaxScoreController.text,
      _maxMaxScoreController.text,
      _maxParityErrorsController.text,
      _maxParityWarnsController.text,
      _maxParityResetsController.text,
      _coverTokenController.text,
      _coverIncludeTagsController.text,
      _coverExcludeTagsController.text,
      _coverIncludeConfidenceController.text,
      _coverExcludeConfidenceController.text,
      _minRating,
      _maxDurationSeconds,
      _curatedOnly,
      _noodleOnly,
      _chromaOnly,
      _cinemaOnly,
      _rankedOnly,
      _qualifiedOnly,
      _hideAi,
      _tagFilterEnabled,
      _untaggedOnly,
      _chinesePresetOnly,
      _coverTagFilterEnabled,
      _coverAcgPresetEnabled,
      _coverWaitOnFailure,
      _coverIncludeMatchAll,
      _coverExcludeMatchAll,
      _difficultyMatchAll,
      _requireAllDifficulties,
    ].join('\u001f');
  }

  bool _ensureLocalCacheLoaded() {
    if (_localCacheMaps.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('读取 LocalCache.saver');
      });
      return false;
    }
    return true;
  }

  Future<void> _addLocalCacheToTargets() async {
    if (!_ensureLocalCacheLoaded()) {
      return;
    }
    final filtered = await _filteredLocalCacheMaps();
    if (filtered.isEmpty) {
      setState(() {
        _status = emptyFilteredLocalCacheStatusForTest();
      });
      return;
    }
    setState(() {
      _targetMaps = {..._targetMaps, for (final map in filtered) map.id: map};
      _status = localCacheAddStatusForTest(
        target: '本次',
        count: filtered.length,
      );
    });
    _addLog(localCacheAddStatusForTest(target: '本次', count: filtered.length));
  }

  Future<void> _addLocalCacheToSkip() async {
    if (!_ensureLocalCacheLoaded()) {
      return;
    }
    final filtered = await _filteredLocalCacheMaps();
    if (filtered.isEmpty) {
      setState(() {
        _status = emptyFilteredLocalCacheStatusForTest();
      });
      return;
    }
    final existing = _parseBeatSaverIds(_skipMapsController.text);
    final merged = localCacheSkipIdsForTest(
      existingIds: existing,
      filteredIds: filtered.map((map) => map.id),
    );
    setState(() {
      _skipMapsController.text = merged.join('\n');
      _status = localCacheAddStatusForTest(
        target: '跳过',
        count: filtered.length,
      );
    });
    _addLog(localCacheAddStatusForTest(target: '跳过', count: filtered.length));
  }

  Future<void> _exportLocalCacheList() async {
    if (!_ensureLocalCacheLoaded()) {
      return;
    }
    final filtered = await _filteredLocalCacheMaps();
    if (filtered.isEmpty) {
      setState(() {
        _status = emptyFilteredLocalCacheStatusForTest();
      });
      return;
    }
    await _run('正在导出本地数据缓存列表...', () async {
      final path = await getSaveLocation(
        suggestedName: 'local_cache_maps.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '本地数据缓存列表', path: null);
        });
        return;
      }
      final lines = mapExportListForTest(filtered);
      await File(path.path).writeAsString(lines, flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: '本地数据缓存列表', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '本地数据缓存列表', path: path.path));
    });
  }

  Future<void> _exportLocalCacheSummary() async {
    if (!_ensureLocalCacheLoaded()) {
      return;
    }
    final filtered = await _filteredLocalCacheMaps();
    final status = _localCacheStatus;
    final summary = localCacheSummaryForTest(
      totalMaps: _localCacheMaps.length,
      filteredMaps: filtered,
    );

    await _run('正在导出本地数据缓存摘要...', () async {
      final path = await getSaveLocation(
        suggestedName: 'local_cache_summary.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本摘要', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '本地数据缓存摘要', path: null);
        });
        return;
      }
      final lines = [
        'LocalCache.saver: ${status?.path ?? _localCacheSaverController.text}',
        if (status != null) '文件大小: ${_formatBytes(status.bytes)}',
        if (status != null && status.generatedAt != null)
          '生成时间: ${_formatDateTime(status.generatedAt!)}',
        if (status != null) '文件修改时间: ${_formatDateTime(status.modified)}',
        '缓存总数: ${summary.totalMaps}',
        '当前筛选: ${summary.filteredMaps}',
        '上传者数: ${summary.uploaders}',
        '含 hash: ${summary.withHash}',
      ];
      await File(path.path).writeAsString(lines.join('\n'), flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: '本地数据缓存摘要', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '本地数据缓存摘要', path: path.path));
    });
  }

  void _clearLocalCacheMaps() {
    setState(() {
      _localCacheMaps = const [];
      _localCacheHashIndex = const {};
      _localCacheFilterCache = null;
      _localCacheStatus = null;
      _localCacheDeletedAudit = null;
      if (_resultSource == _ResultSource.localCache) {
        _results = const [];
        _totalResults = 0;
        _totalPages = 0;
      }
      _status = clearedStatusForTest('已读本地数据缓存');
    });
    _addLog(clearedStatusForTest('已读本地数据缓存'));
  }

  Future<_MapLookupResult> _getMapsByIdsWithFailures(
    List<String> ids, {
    required String logPrefix,
  }) async {
    try {
      final maps = await _client.getMapsByIds(ids);
      final foundIds = maps.map((map) => map.id.toLowerCase()).toSet();
      final missingIds = ids
          .where((id) => !foundIds.contains(id.toLowerCase()))
          .toList(growable: false);
      for (final id in missingIds) {
        _addLog('$logPrefix：$id，BeatSaver 未返回详情');
      }
      return _MapLookupResult(maps: maps, failed: missingIds.length);
    } catch (error) {
      _addLog('$logPrefix：批量请求失败，$error');
      return _MapLookupResult(maps: const [], failed: ids.length);
    }
  }

  Future<void> _goToSearchPage(int page) async {
    final maxPage = _totalPages <= 0 ? page : _totalPages - 1;
    final nextPage = page.clamp(0, maxPage);
    setState(() {
      _searchPage = nextPage;
    });
    final action = goToPageActionForTest(_resultSource.toResultSourceForTest());
    switch (action) {
      case GoToPageActionForTest.search:
        await _search();
      case GoToPageActionForTest.searchUploader:
        await _searchUploaderMaps();
      case GoToPageActionForTest.searchScoreSaber:
        await _searchScoreSaberMaps();
      case GoToPageActionForTest.searchBeastSaber:
        await _searchBeastSaberMaps();
      case GoToPageActionForTest.showLocalCachePage:
        await _showLocalCachePage();
    }
  }

  Future<List<BeatSaverMap>> _filterSearchResults(
    List<BeatSaverMap> maps,
  ) async {
    final uploader = _uploaderController.text.trim().toLowerCase();
    final filterTokens = _splitFilterTokens(_filterTextController.text);
    RegExp? filterRegex;
    RegExp? regex;
    if (_regexSearchMode && _queryController.text.trim().isNotEmpty) {
      try {
        regex = RegExp(_queryController.text.trim(), caseSensitive: false);
      } on FormatException catch (error) {
        _addLog('正则表达式无效：$error');
      }
    }
    if (_filterRegexMode && _filterTextController.text.trim().isNotEmpty) {
      try {
        filterRegex = RegExp(
          _filterTextController.text.trim(),
          caseSensitive: false,
          multiLine: true,
        );
      } on FormatException catch (error) {
        _addLog('搜索过滤正则无效：$error');
      }
    }
    final includeTags = _splitFilterTokens(_includeTagsController.text);
    final excludeTags = _splitFilterTokens(_excludeTagsController.text);
    final requiredComponents = _splitFilterTokens(
      _requiredComponentsController.text,
    );
    final excludedComponents = _splitFilterTokens(
      _excludedComponentsController.text,
    );
    final difficultyFilters = _splitFilterTokens(
      _difficultyFilterController.text,
    );
    final characteristicFilters = _splitFilterTokens(
      _characteristicFilterController.text,
    );
    final minDownloads = _parseInt(_minDownloadsController.text);
    final minPlays = _parseInt(_minPlaysController.text);
    final maxPlays = _parseInt(_maxPlaysController.text);
    final minUpvotes = _parseInt(_minUpvotesController.text);
    final minUpvoteRatio = _parseRatio(_minUpvoteRatioController.text);
    final maxUpvoteRatio = _parseRatio(_maxUpvoteRatioController.text);
    final maxDownvotes = _parseInt(_maxDownvotesController.text);
    final minDownvoteRatio = _parseRatio(_minDownvoteRatioController.text);
    final maxDownvoteRatio = _parseRatio(_maxDownvoteRatioController.text);
    final minScore = _parseRatio(_minScoreController.text);
    final maxScore = _parseRatio(_maxScoreController.text);
    final minBpm = _parseDouble(_minBpmController.text);
    final maxBpm = _parseDouble(_maxBpmController.text);
    final uploadedAfter = _parseDate(_uploadedAfterController.text);
    final uploadedBefore = _parseDate(_uploadedBeforeController.text);
    final minNotes = _parseInt(_minNotesController.text);
    final maxNotes = _parseInt(_maxNotesController.text);
    final minBombs = _parseInt(_minBombsController.text);
    final maxBombs = _parseInt(_maxBombsController.text);
    final minObstacles = _parseInt(_minObstaclesController.text);
    final maxObstacles = _parseInt(_maxObstaclesController.text);
    final minMapSeconds = _parseDouble(_minMapSecondsController.text);
    final maxMapSeconds = _parseDouble(_maxMapSecondsController.text);
    final minNjs = _parseDouble(_minNjsController.text);
    final maxNjs = _parseDouble(_maxNjsController.text);
    final minNps = _parseDouble(_minNpsController.text);
    final maxNps = _parseDouble(_maxNpsController.text);
    final minOffset = _parseDouble(_minOffsetController.text);
    final maxOffset = _parseDouble(_maxOffsetController.text);
    final minEvents = _parseInt(_minEventsController.text);
    final maxEvents = _parseInt(_maxEventsController.text);
    final minSageScore = _parseInt(_minSageScoreController.text);
    final maxSageScore = _parseInt(_maxSageScoreController.text);
    final minStars = _parseDouble(_minStarsController.text);
    final maxStars = _parseDouble(_maxStarsController.text);
    final minMaxScore = _parseInt(_minMaxScoreController.text);
    final maxMaxScore = _parseInt(_maxMaxScoreController.text);
    final maxParityErrors = _parseInt(_maxParityErrorsController.text);
    final maxParityWarns = _parseInt(_maxParityWarnsController.text);
    final maxParityResets = _parseInt(_maxParityResetsController.text);

    final filtered = maps
        .where((map) {
          final diffs =
              map.latestVersion?.diffs ?? const <BeatSaverDifficulty>[];
          if (uploader.isNotEmpty) {
            final uploaderName = (map.uploaderName ?? '').toLowerCase();
            final uploaderId = map.uploaderId?.toString() ?? '';
            if (!uploaderName.contains(uploader) && uploaderId != uploader) {
              return false;
            }
          }
          if (regex != null && !_matchesSearchRegex(map, regex)) {
            return false;
          }
          if (filterRegex != null &&
              !_matchesFieldFilterRegex(
                map,
                filterRegex,
                title: _filterTitle,
                songName: _filterSongName,
                songAuthor: _filterSongAuthor,
                mapper: _filterMapper,
                description: _filterDescription,
                tags: _filterTags,
              )) {
            return false;
          }
          if (filterRegex == null &&
              filterTokens.isNotEmpty &&
              !_matchesFieldFilterTokens(
                map,
                filterTokens,
                title: _filterTitle,
                songName: _filterSongName,
                songAuthor: _filterSongAuthor,
                mapper: _filterMapper,
                description: _filterDescription,
                tags: _filterTags,
              )) {
            return false;
          }
          if (_rankedOnly && !map.ranked) {
            return false;
          }
          if (_qualifiedOnly && !map.qualified) {
            return false;
          }
          if (_hideAi &&
              map.declaredAi != null &&
              map.declaredAi!.isNotEmpty &&
              map.declaredAi != 'None') {
            return false;
          }
          if (_chinesePresetOnly && !_matchesChinesePreset(map)) {
            return false;
          }
          if (minDownloads != null &&
              map.stats.downloads > 0 &&
              map.stats.downloads < minDownloads) {
            return false;
          }
          if (minPlays != null && map.stats.plays < minPlays) {
            return false;
          }
          if (maxPlays != null &&
              map.stats.plays > 0 &&
              map.stats.plays > maxPlays) {
            return false;
          }
          if (minUpvotes != null && map.stats.upvotes < minUpvotes) {
            return false;
          }
          final voteTotal = map.stats.upvotes + map.stats.downvotes;
          if (voteTotal > 0) {
            final upvoteRatio = map.stats.upvotes / voteTotal;
            final downvoteRatio = map.stats.downvotes / voteTotal;
            if (minUpvoteRatio != null && upvoteRatio < minUpvoteRatio) {
              return false;
            }
            if (maxUpvoteRatio != null && upvoteRatio > maxUpvoteRatio) {
              return false;
            }
            if (minDownvoteRatio != null && downvoteRatio < minDownvoteRatio) {
              return false;
            }
            if (maxDownvoteRatio != null && downvoteRatio > maxDownvoteRatio) {
              return false;
            }
          } else if (minUpvoteRatio != null ||
              maxUpvoteRatio != null ||
              minDownvoteRatio != null ||
              maxDownvoteRatio != null) {
            return false;
          }
          if (maxDownvotes != null && map.stats.downvotes > maxDownvotes) {
            return false;
          }
          if (minScore != null && map.stats.score < minScore) {
            return false;
          }
          if (maxScore != null &&
              map.stats.score > 0 &&
              map.stats.score > maxScore) {
            return false;
          }
          if (minBpm != null && map.metadata.bpm < minBpm) {
            return false;
          }
          if (maxBpm != null && map.metadata.bpm > maxBpm) {
            return false;
          }
          if (uploadedAfter != null &&
              (map.uploadedAt == null ||
                  map.uploadedAt!.isBefore(uploadedAfter))) {
            return false;
          }
          if (uploadedBefore != null &&
              (map.uploadedAt == null ||
                  !map.uploadedAt!.isBefore(
                    uploadedBefore.add(const Duration(days: 1)),
                  ))) {
            return false;
          }
          if (difficultyFilters.isNotEmpty &&
              !_diffsMatchDifficulties(
                diffs,
                difficultyFilters,
                matchAll: _difficultyMatchAll,
              )) {
            return false;
          }
          if (characteristicFilters.isNotEmpty &&
              !_diffsMatchCharacteristics(diffs, characteristicFilters)) {
            return false;
          }
          if (_requireAllDifficulties && !_hasAllStandardDifficulties(diffs)) {
            return false;
          }
          if (requiredComponents.isNotEmpty &&
              !_diffsContainAllComponents(diffs, requiredComponents)) {
            return false;
          }
          if (excludedComponents.isNotEmpty &&
              _diffsContainAnyComponent(diffs, excludedComponents)) {
            return false;
          }
          if (_tagFilterEnabled) {
            if (!tagsMatchForTest(
              map.tags,
              untaggedOnly: _untaggedOnly,
              includeTags: includeTags,
              excludeTags: excludeTags,
            )) {
              return false;
            }
          }
          if (minNotes != null &&
              !diffs.any((diff) => diff.notes >= minNotes)) {
            return false;
          }
          if (maxNotes != null &&
              !diffs.any((diff) => diff.notes <= maxNotes)) {
            return false;
          }
          if (minBombs != null &&
              !diffs.any((diff) => diff.bombs >= minBombs)) {
            return false;
          }
          if (maxBombs != null &&
              !diffs.any((diff) => diff.bombs <= maxBombs)) {
            return false;
          }
          if (minObstacles != null &&
              !diffs.any((diff) => diff.obstacles >= minObstacles)) {
            return false;
          }
          if (maxObstacles != null &&
              !diffs.any((diff) => diff.obstacles <= maxObstacles)) {
            return false;
          }
          if (minMapSeconds != null &&
              !diffs.any((diff) => diff.seconds >= minMapSeconds)) {
            return false;
          }
          if (maxMapSeconds != null &&
              !diffs.any((diff) => diff.seconds <= maxMapSeconds)) {
            return false;
          }
          if (minNjs != null && !diffs.any((diff) => diff.njs >= minNjs)) {
            return false;
          }
          if (maxNjs != null && !diffs.any((diff) => diff.njs <= maxNjs)) {
            return false;
          }
          if (minNps != null && !diffs.any((diff) => diff.nps >= minNps)) {
            return false;
          }
          if (maxNps != null && !diffs.any((diff) => diff.nps <= maxNps)) {
            return false;
          }
          if (minOffset != null &&
              !diffs.any((diff) => diff.offset >= minOffset)) {
            return false;
          }
          if (maxOffset != null &&
              !diffs.any((diff) => diff.offset <= maxOffset)) {
            return false;
          }
          if (minEvents != null &&
              !diffs.any((diff) => diff.events >= minEvents)) {
            return false;
          }
          if (maxEvents != null &&
              !diffs.any((diff) => diff.events <= maxEvents)) {
            return false;
          }
          final sageScore = map.latestVersion?.sageScore ?? 0;
          if (minSageScore != null && sageScore < minSageScore) {
            return false;
          }
          if (maxSageScore != null &&
              sageScore > 0 &&
              sageScore > maxSageScore) {
            return false;
          }
          if (minStars != null &&
              !diffs.any((diff) => _diffStars(diff) >= minStars)) {
            return false;
          }
          if (maxStars != null &&
              !diffs.any((diff) => _diffStars(diff) <= maxStars)) {
            return false;
          }
          if (minMaxScore != null &&
              !diffs.any((diff) => diff.maxScore >= minMaxScore)) {
            return false;
          }
          if (maxMaxScore != null &&
              !diffs.any((diff) => diff.maxScore <= maxMaxScore)) {
            return false;
          }
          if (maxParityErrors != null &&
              !diffs.any((diff) => diff.parityErrors <= maxParityErrors)) {
            return false;
          }
          if (maxParityWarns != null &&
              !diffs.any((diff) => diff.parityWarns <= maxParityWarns)) {
            return false;
          }
          if (maxParityResets != null &&
              !diffs.any((diff) => diff.parityResets <= maxParityResets)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    return _filterCoverLabels(filtered);
  }

  Future<List<BeatSaverMap>> _filterCoverLabels(List<BeatSaverMap> maps) async {
    if (!_coverTagFilterEnabled) {
      return maps;
    }
    final token = _coverTokenController.text.trim();
    if (token.isEmpty) {
      _addLog('封面标签过滤已开启，但 GCP Token 为空');
      return maps;
    }
    final includeTags = _splitFilterTokens(_coverIncludeTagsController.text);
    final excludeTags = _splitFilterTokens(_coverExcludeTagsController.text);
    final effectiveInclude = _coverAcgPresetEnabled && includeTags.isEmpty
        ? const {'anime', 'cartoon', 'illustration', 'game'}
        : includeTags;
    if (effectiveInclude.isEmpty && excludeTags.isEmpty) {
      return maps;
    }
    final includeConfidence =
        _parseDouble(_coverIncludeConfidenceController.text) ?? 0.7;
    final excludeConfidence =
        _parseDouble(_coverExcludeConfidenceController.text) ?? 0.7;
    return filterCoverLabelsWithFallbackForTest(
      maps,
      token: token,
      includeTags: effectiveInclude,
      excludeTags: excludeTags,
      includeConfidence: includeConfidence,
      excludeConfidence: excludeConfidence,
      includeMatchAll: _coverIncludeMatchAll,
      excludeMatchAll: _coverExcludeMatchAll,
      waitOnFailure: _coverWaitOnFailure,
      labelCache: _coverLabelCache,
      detectLabels: _coverLabelsForUrl,
      promptLabels: _promptForCoverLabels,
      onError: (map, error) => _addLog('封面识别失败：${map.id}，$error'),
      onCacheChanged: _saveCoverLabelCache,
    );
  }

  Future<List<CoverLabel>> _promptForCoverLabels(BeatSaverMap map) async {
    if (!mounted) {
      return const [];
    }
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('封面识别失败：${_mapTitle(map)}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '手动标签',
              hintText: 'anime, game',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('跳过'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return manualCoverLabelsForTest(result);
  }

  Future<List<CoverLabel>> _coverLabelsForUrl(String coverUrl, String token) {
    final cached = _coverLabelCache[coverUrl];
    if (cached != null) {
      return Future.value(cached);
    }
    return _coverLabelClient
        .detectLabels(imageUrl: coverUrl, apiKey: token)
        .then((labels) {
          _coverLabelCache[coverUrl] = labels;
          _saveCoverLabelCache();
          return labels;
        });
  }

  Future<void> _refreshInstalled() async {
    await _run('正在扫描已安装歌曲...', () async {
      final entries = await scanInstalledLibrary(_libraryDirectory);
      final zipCache = await _scanZipCache();
      setState(() {
        _installed = entries;
        _zipCache = zipCache;
        _status = localScanStatusForTest(
          installedCount: entries.length,
          zipCacheCount: zipCache.length,
        );
      });
      _addLog(
        localScanLogForTest(
          installedCount: entries.length,
          zipCacheCount: zipCache.length,
        ),
      );
    });
  }

  Future<List<ZipCacheEntryUiModel>> _scanZipCache() async {
    final entries = await scanZipCacheForTest(_downloadDirectory);
    return entries
        .map(
          (entry) => ZipCacheEntryUiModel(
            name: entry.name,
            path: entry.path,
            bytes: entry.bytes,
            modified: entry.modified,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _addManualMapsToResults() async {
    final ids = _parseBeatSaverIds(_manualMapsController.text);
    if (ids.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('输入 BeatSaver ID 或链接');
      });
      return;
    }

    await _run('正在读取 ${ids.length} 个手动谱面...', () async {
      final result = await _getMapsByIdsWithFailures(ids, logPrefix: '读取失败');
      final maps = result.maps;
      final failed = result.failed;
      setState(() {
        final merged = <String, BeatSaverMap>{
          for (final map in _results) map.id: map,
          for (final map in maps) map.id: map,
        };
        _results = merged.values.toList(growable: false);
        _targetMaps = {..._targetMaps, for (final map in maps) map.id: map};
        _status = manualAddResultsStatusForTest(
          added: maps.length,
          failed: failed,
        );
      });
      _addLog('手动添加完成：成功 ${maps.length}，失败 $failed');
    });
  }

  Future<void> _importOnlinePlaylistToTargets() async {
    final playlistText = _onlinePlaylistController.text.trim();
    final playlistId = _parseBeatSaverPlaylistId(playlistText);
    if (playlistId == null) {
      setState(() {
        _status = requireActionStatusForTest('输入 BeatSaver 在线歌单 ID 或链接');
      });
      return;
    }

    await _run('正在读取在线歌单 $playlistId...', () async {
      final loadedMaps = <BeatSaverMap>[];
      BeatSaverPlaylist? playlist;
      var page = 0;
      while (true) {
        final response = await _client.getPlaylistPage(
          playlistId: playlistId,
          page: page,
          pageSize: _pageSize,
        );
        playlist ??= response.playlist;
        loadedMaps.addAll(response.maps);
        if (response.maps.isEmpty ||
            (playlist.totalMaps > 0 &&
                loadedMaps.length >= playlist.totalMaps)) {
          break;
        }
        page += 1;
      }

      final filtered = await _filterSearchResults(loadedMaps);
      setState(() {
        final mergedResults = <String, BeatSaverMap>{
          for (final map in _results) map.id: map,
          for (final map in filtered) map.id: map,
        };
        _results = mergedResults.values.toList(growable: false);
        _targetMaps = {..._targetMaps, for (final map in filtered) map.id: map};
        _totalResults = loadedMaps.length;
        _totalPages = 1;
        _searchPage = 0;
        final name = playlist?.name.isEmpty ?? true
            ? '#$playlistId'
            : playlist!.name;
        _status = playlistImportStatusForTest(
          name: name,
          loadedCount: loadedMaps.length,
          filteredCount: filtered.length,
        );
      });
      _addLog(
        '在线歌单导入本次完成：$playlistId，读取 ${loadedMaps.length}，'
        '加入 ${filtered.length}',
      );
    });
  }

  void _addManualMapsToSkip() {
    final ids = _parseBeatSaverIds(_manualMapsController.text);
    if (ids.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('输入 BeatSaver ID 或链接');
      });
      return;
    }

    final existing = _parseBeatSaverIds(_skipMapsController.text);
    final merged = mergedSkipIdsForTest(existingIds: existing, newIds: ids);
    setState(() {
      _skipMapsController.text = merged.join('\n');
      _status = songCountStatusForTest(label: '已加入跳过歌曲', count: ids.length);
    });
    _addLog(songCountStatusForTest(label: '已加入跳过歌曲', count: ids.length));
  }

  Future<void> _installManualMaps() async {
    final ids = _parseBeatSaverIds(_manualMapsController.text);
    if (ids.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('输入 BeatSaver ID 或链接');
      });
      return;
    }

    _setQueueForIds(ids);
    _stopRequested = false;
    await _run('正在安装 ${ids.length} 个手动谱面...', () async {
      var installedCount = 0;
      var skippedCount = 0;
      var failedCount = 0;
      var stoppedCount = 0;
      for (var index = 0; index < ids.length; index += 1) {
        if (_stopRequested) {
          stoppedCount += _markRemainingQueueSkipped(ids.skip(index));
          break;
        }
        final id = ids[index];
        _updateQueueEntry(id, status: _QueueStatus.running);
        _setStatus('正在读取 ${index + 1}/${ids.length}：$id');
        try {
          final map = await _client.getMapById(id);
          _updateQueueEntry(
            id,
            title: _mapTitle(map),
            status: _QueueStatus.running,
          );
          final installed = await _installOne(map);
          if (installed) {
            installedCount += 1;
            _updateQueueEntry(id, status: _QueueStatus.completed);
          } else {
            skippedCount += 1;
            _updateQueueEntry(id, status: _QueueStatus.skipped);
          }
        } catch (error) {
          failedCount += 1;
          _updateQueueEntry(
            id,
            status: _QueueStatus.failed,
            message: error.toString(),
          );
          _addLog('手动安装失败：$id，$error');
        }
      }
      _setStatus('正在刷新已安装列表...');
      final installed = await scanInstalledLibrary(_libraryDirectory);
      setState(() {
        _installed = installed;
        _status = manualInstallStatusForTest(
          installed: installedCount,
          skipped: skippedCount,
          stopped: stoppedCount,
          failed: failedCount,
        );
      });
    });
  }

  Future<bool> _installOne(BeatSaverMap map) async {
    final title = _mapTitle(map);
    final existing = await findInstalledMapDirectory(
      map,
      _libraryDirectory,
      extraDirectories: _skipExistingDirectories,
    );
    if (existing != null) {
      _setStatus('已安装，跳过：$title');
      _addLog('跳过已有歌曲：$title，${existing.path}');
      return false;
    }

    if (_androidTreeUri != null && _androidStorage.isSupported) {
      _setStatus('正在下载 $title...');
      await _installToAndroidTree(map, _androidTreeUri!);
    } else {
      final localSongDirectory = await _findLocalSongDirectory(map);
      if (localSongDirectory != null) {
        _setStatus('正在从本地歌曲目录复制 $title...');
        await _copyLocalSongDirectory(map, localSongDirectory);
        _setStatus('本地复制安装完成：$title');
        _addLog('本地歌曲目录复制完成：$title，${localSongDirectory.path}');
        return true;
      }
      final cachedZip = await _findZipCacheFileForDownloadMode(map);
      if (cachedZip == null) {
        _setStatus('正在下载并解压 $title...');
        await _downloadClient().installLatestVersion(
          map,
          _libraryDirectory,
          directoryNameTemplate: _directoryNameTemplate,
          asciiDirectoryName: _asciiDirectoryNames,
        );
      } else {
        _setStatus('正在从本地缓存解压 $title...');
        await _installCachedZip(map, cachedZip);
      }
    }
    _setStatus('下载并安装完成：$title');
    _addLog('安装完成：$title');
    return true;
  }

  Future<void> _install(BeatSaverMap map) async {
    _setQueueForMaps([map]);
    _stopRequested = false;
    await _run('正在下载并安装 ${_mapTitle(map)}...', () async {
      _updateQueueEntry(map.id, status: _QueueStatus.running);
      final installed = await _installOne(map);
      _updateQueueEntry(
        map.id,
        status: installed ? _QueueStatus.completed : _QueueStatus.skipped,
      );
      _setStatus('正在刷新已安装列表...');
      final installedEntries = await scanInstalledLibrary(_libraryDirectory);
      setState(() {
        _installed = installedEntries;
      });
    });
  }

  Future<void> _installSelected() async {
    final selected = _limitedDownloadMaps(
      _targetMaps.values.toList(growable: false),
    );
    await _installMaps(selected, emptyAction: '选择要下载并安装的谱面');
  }

  Future<void> _installMaps(
    List<BeatSaverMap> selected, {
    required String emptyAction,
  }) async {
    if (selected.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest(emptyAction);
      });
      return;
    }

    _setQueueForMaps(selected);
    _stopRequested = false;
    await _run('正在批量下载并安装 ${selected.length} 张谱面...', () async {
      final summary = await _installMapsCore(selected);
      setState(() {
        _status = batchInstallStatusForTest(
          installed: summary.installed,
          skipped: summary.skipped,
          stopped: summary.stopped,
          failed: summary.failed,
        );
      });
      _addLog(
        '批量安装完成：安装 ${summary.installed}，跳过 ${summary.skipped}，'
        '停止 ${summary.stopped}，失败 ${summary.failed}',
      );
      final completionActions = completionActionsForTest(
        autoPack: _autoPackOnComplete,
        autoExtract: false,
        autoExit: _autoExitOnComplete,
        stopped: summary.stopped,
        failed: summary.failed,
      );
      if (completionActions.contains(CompletionActionForTest.packZip)) {
        final file = await _exportInstalledZipFile();
        setState(() {
          _status = batchInstallAutoPackStatusForTest(
            installed: summary.installed,
            skipped: summary.skipped,
            failed: summary.failed,
            path: file.path,
          );
        });
        _addLog('完成后自动打包：${file.path}');
      }
      if (completionActions.contains(CompletionActionForTest.exitApp)) {
        _scheduleAutoExitOnComplete();
      }
    });
  }

  Future<_InstallSummary> _installMapsCore(List<BeatSaverMap> selected) async {
    final skipIds = _skipMapIds;
    var installedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    await _forEachDownloadTask<BeatSaverMap>(selected, (map, index) async {
      if (_stopRequested) {
        return;
      }
      final title = _mapTitle(map);
      if (skipIds.contains(map.id.toLowerCase())) {
        skippedCount += 1;
        _updateQueueEntry(map.id, status: _QueueStatus.skipped);
        _addLog('跳过用户指定歌曲：$title');
        return;
      }
      _updateQueueEntry(map.id, status: _QueueStatus.running);
      _setStatus('正在处理 ${index + 1}/${selected.length}：$title');
      try {
        final installed = await _installOne(map);
        if (installed) {
          installedCount += 1;
          _updateQueueEntry(map.id, status: _QueueStatus.completed);
        } else {
          skippedCount += 1;
          _updateQueueEntry(map.id, status: _QueueStatus.skipped);
        }
      } catch (error) {
        failedCount += 1;
        _updateQueueEntry(
          map.id,
          status: _QueueStatus.failed,
          message: error.toString(),
        );
        _addLog('安装失败：$title，$error');
      }
    });
    final stoppedCount = _stopRequested
        ? _markRemainingQueueSkipped(
            _queue
                .where((entry) => entry.status == _QueueStatus.waiting)
                .map((entry) => entry.id),
          )
        : 0;
    _setStatus('正在刷新已安装列表...');
    final installed = await scanInstalledLibrary(_libraryDirectory);
    setState(() {
      _installed = installed;
    });
    return _InstallSummary(
      installed: installedCount,
      skipped: skippedCount,
      stopped: stoppedCount,
      failed: failedCount,
    );
  }

  Future<void> _downloadSelectedZip() async {
    final selected = _limitedDownloadMaps(
      _targetMaps.values.toList(growable: false),
    );
    if (selected.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择要下载 ZIP 的谱面');
      });
      return;
    }

    _setQueueForMaps(selected);
    _stopRequested = false;
    await _run('正在打包 ${selected.length} 张所选谱面...', () async {
      final skipIds = _skipMapIds;
      final archivePath = _outputPathFromTemplate(
        _archiveController.text.trim(),
        extension: 'zip',
      );
      final tempLibrary = await Directory.systemTemp.createTemp(
        'beat_saber_song_toolkit_pack_',
      );
      var packed = 0;
      var reused = 0;
      var downloaded = 0;
      var skipped = 0;
      var failed = 0;
      var stopped = 0;

      try {
        for (var index = 0; index < selected.length; index += 1) {
          if (_stopRequested) {
            stopped += _markRemainingQueueSkipped(
              selected.skip(index).map((map) => map.id),
            );
            break;
          }
          final map = selected[index];
          final title = _mapTitle(map);
          if (skipIds.contains(map.id.toLowerCase())) {
            skipped += 1;
            _updateQueueEntry(map.id, status: _QueueStatus.skipped);
            _addLog('打包跳过用户指定歌曲：$title');
            continue;
          }
          _updateQueueEntry(map.id, status: _QueueStatus.running);
          _setStatus('正在准备打包 ${index + 1}/${selected.length}：$title');
          try {
            final existing = await findInstalledMapDirectory(
              map,
              _libraryDirectory,
              extraDirectories: _skipExistingDirectories,
            );
            if (existing == null) {
              await _installIntoDirectory(map, tempLibrary);
              downloaded += 1;
            } else {
              await copyDirectoryRecursive(
                existing,
                Directory(
                  '${tempLibrary.path}${Platform.pathSeparator}'
                  '${installedSongDirectoryName(map, template: _directoryNameTemplate, asciiOnly: _asciiDirectoryNames)}',
                ),
              );
              reused += 1;
            }
            packed += 1;
            _updateQueueEntry(map.id, status: _QueueStatus.completed);
          } catch (error) {
            failed += 1;
            _updateQueueEntry(
              map.id,
              status: _QueueStatus.failed,
              message: error.toString(),
            );
            _addLog('打包准备失败：$title，$error');
          }
        }

        final file = await exportInstalledSongsZip(
          libraryDirectory: tempLibrary,
          outputFile: File(archivePath),
        );
        final status =
            '所选 ZIP 已打包：$packed 首，复用 $reused，下载 $downloaded，'
            '跳过 $skipped，停止 $stopped，失败 $failed，${file.path}';
        setState(() {
          _status = status;
        });
        _addLog(status);
        if (completionActionsForTest(
          autoPack: false,
          autoExtract: false,
          autoExit: _autoExitOnComplete,
          stopped: stopped,
          failed: failed,
        ).contains(CompletionActionForTest.exitApp)) {
          _scheduleAutoExitOnComplete();
        }
      } finally {
        if (await tempLibrary.exists()) {
          await tempLibrary.delete(recursive: true);
        }
      }
    });
  }

  Future<void> _downloadSelectedRawZips() async {
    final selected = _limitedDownloadMaps(
      _targetMaps.values.toList(growable: false),
    );
    if (selected.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择要下载 ZIP 的谱面');
      });
      return;
    }

    _setQueueForMaps(selected, task: _QueueTask.downloadZip);
    _stopRequested = false;
    await _run('正在批量下载 ${selected.length} 个 ZIP...', () async {
      final summary = await _downloadRawZipsForMaps(selected);
      setState(() {
        _status = zipDownloadStatusForTest(
          downloaded: summary.downloaded,
          skipped: summary.skipped,
          stopped: summary.stopped,
          failed: summary.failed,
        );
      });
      _addLog(
        '批量 ZIP 下载完成：下载 ${summary.downloaded}，'
        '跳过 ${summary.skipped}，停止 ${summary.stopped}，'
        '失败 ${summary.failed}',
      );
      final completionActions = completionActionsForTest(
        autoPack: false,
        autoExtract: _autoExtractOnComplete,
        autoExit: _autoExitOnComplete,
        stopped: summary.stopped,
        failed: summary.failed,
      );
      if (completionActions.contains(
        CompletionActionForTest.extractDownloaded,
      )) {
        final installed = await _autoExtractDownloadedMaps(selected);
        setState(() {
          _status = zipDownloadAutoExtractStatusForTest(
            downloaded: summary.downloaded,
            installed: installed,
            skipped: summary.skipped,
            failed: summary.failed,
          );
        });
      }
      if (completionActions.contains(CompletionActionForTest.exitApp)) {
        _scheduleAutoExitOnComplete();
      }
    });
  }

  Future<_ZipDownloadSummary> _downloadRawZipsForMaps(
    List<BeatSaverMap> selected,
  ) async {
    final skipIds = _skipMapIds;
    var downloaded = 0;
    var skipped = 0;
    var failed = 0;
    await _forEachDownloadTask<BeatSaverMap>(selected, (map, index) async {
      if (_stopRequested) {
        return;
      }
      final title = _mapTitle(map);
      if (skipIds.contains(map.id.toLowerCase())) {
        skipped += 1;
        _updateQueueEntry(map.id, status: _QueueStatus.skipped);
        _addLog('下载 ZIP 跳过用户指定歌曲：$title');
        return;
      }
      final existing = await findInstalledMapDirectory(
        map,
        _libraryDirectory,
        extraDirectories: _skipExistingDirectories,
      );
      if (existing != null) {
        skipped += 1;
        _updateQueueEntry(map.id, status: _QueueStatus.skipped);
        _addLog('下载 ZIP 跳过已有歌曲：$title，${existing.path}');
        return;
      }
      _updateQueueEntry(map.id, status: _QueueStatus.running);
      _setStatus('正在下载 ZIP ${index + 1}/${selected.length}：$title');
      try {
        final file = await _downloadZipOne(map);
        downloaded += 1;
        _updateQueueEntry(
          map.id,
          status: _QueueStatus.completed,
          message: file.path,
        );
      } catch (error) {
        failed += 1;
        _updateQueueEntry(
          map.id,
          status: _QueueStatus.failed,
          message: error.toString(),
        );
        _addLog('ZIP 下载失败：$title，$error');
      }
    });
    final stopped = _stopRequested
        ? _markRemainingQueueSkipped(
            _queue
                .where((entry) => entry.status == _QueueStatus.waiting)
                .map((entry) => entry.id),
          )
        : 0;
    return _ZipDownloadSummary(
      downloaded: downloaded,
      skipped: skipped,
      stopped: stopped,
      failed: failed,
    );
  }

  Future<void> _saveSelectedListAndZips() async {
    final selected = _limitedDownloadMaps(
      _targetMaps.values.toList(growable: false),
    );
    if (selected.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择要保存的本次歌曲');
      });
      return;
    }

    if (!_saveSongListEnabled && !_saveSongFilesEnabled) {
      setState(() {
        _status = outputModeDisabledStatusForTest();
      });
      return;
    }

    if (_saveSongFilesEnabled) {
      _setQueueForMaps(selected, task: _QueueTask.downloadZip);
    }
    _stopRequested = false;
    final actionLabel = saveSelectedActionLabelForTest(
      saveSongList: _saveSongListEnabled,
      saveSongFiles: _saveSongFilesEnabled,
    );
    await _run('正在$actionLabel...', () async {
      String? listPath;
      if (_saveSongListEnabled) {
        final path = await getSaveLocation(
          suggestedName: 'beat_saber_song_toolkit_targets.txt',
          acceptedTypeGroups: const [
            XTypeGroup(label: '文本列表', extensions: ['txt']),
          ],
        );
        if (path == null) {
          setState(() {
            _status = exportFileStatusForTest(label: '本次歌曲列表', path: null);
          });
          return;
        }

        await _writeTargetList(File(path.path), selected);
        listPath = path.path;
        _addLog('本次歌曲列表已保存：$listPath');
      }
      final summary = _saveSongFilesEnabled
          ? await _downloadRawZipsForMaps(selected)
          : const _ZipDownloadSummary(
              downloaded: 0,
              skipped: 0,
              stopped: 0,
              failed: 0,
            );
      final status = saveSelectedStatusForTest(
        listPath: listPath,
        saveSongFiles: _saveSongFilesEnabled,
        downloaded: summary.downloaded,
        skipped: summary.skipped,
        stopped: summary.stopped,
        failed: summary.failed,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
      final completionActions = completionActionsForTest(
        autoPack: false,
        autoExtract: _saveSongFilesEnabled && _autoExtractOnComplete,
        autoExit: _autoExitOnComplete,
        stopped: summary.stopped,
        failed: summary.failed,
      );
      if (completionActions.contains(
        CompletionActionForTest.extractDownloaded,
      )) {
        final installed = await _autoExtractDownloadedMaps(selected);
        final status = saveSelectedAutoExtractStatusForTest(
          listPath: listPath,
          downloaded: summary.downloaded,
          installed: installed,
          skipped: summary.skipped,
          failed: summary.failed,
        );
        setState(() {
          _status = status;
        });
        _addLog(status);
      }
      if (completionActions.contains(CompletionActionForTest.exitApp)) {
        _scheduleAutoExitOnComplete();
      }
    });
  }

  void _scheduleAutoExitOnComplete() {
    if (!_autoExitOnComplete) {
      return;
    }
    _addLog('完成后自动退出已触发');
    setState(() {
      _status = autoExitReadyStatusForTest();
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      exit(0);
    });
  }

  Future<int> _autoExtractDownloadedMaps(List<BeatSaverMap> maps) async {
    var installedCount = 0;
    for (final map in maps) {
      if (_stopRequested) {
        break;
      }
      try {
        if (await _installOne(map)) {
          installedCount += 1;
        }
      } catch (error) {
        _addLog('完成后自动解压失败：${_mapTitle(map)}，$error');
      }
    }
    if (installedCount > 0) {
      final installed = await scanInstalledLibrary(_libraryDirectory);
      setState(() {
        _installed = installed;
      });
    }
    _addLog('完成后自动解压：安装 $installedCount 首');
    return installedCount;
  }

  List<BeatSaverMap> _limitedDownloadMaps(List<BeatSaverMap> maps) {
    final limit = _parseInt(_downloadLimitController.text);
    return limitedItemsForTest(maps, limit);
  }

  Future<void> _copyLocalSongDirectory(
    BeatSaverMap map,
    Directory source,
  ) async {
    final destination = Directory(
      '${_libraryDirectory.path}${Platform.pathSeparator}'
      '${installedSongDirectoryName(map, template: _directoryNameTemplate, asciiOnly: _asciiDirectoryNames)}',
    );
    await copyDirectoryRecursive(source, destination);
  }

  void _toggleResultSelection(BeatSaverMap map, bool selected) {
    setState(() {
      final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
      if (selected) {
        targetMaps[map.id] = map;
      } else {
        targetMaps.remove(map.id);
      }
      _targetMaps = targetMaps;
    });
  }

  void _selectAllResults(bool selected) {
    setState(() {
      final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
      if (selected) {
        for (final map in _results) {
          targetMaps[map.id] = map;
        }
      } else {
        for (final map in _results) {
          targetMaps.remove(map.id);
        }
      }
      _targetMaps = targetMaps;
    });
  }

  void _clearResultSelection() {
    setState(() {
      _targetMaps = const {};
    });
  }

  void _setQueueForMaps(
    List<BeatSaverMap> maps, {
    _QueueTask task = _QueueTask.install,
  }) {
    setState(() {
      _queue = maps
          .map(
            (map) => _QueueEntry(
              id: map.id,
              title: _mapTitle(map),
              task: task,
              status: _QueueStatus.waiting,
            ),
          )
          .toList(growable: false);
    });
  }

  void _setQueueForIds(
    List<String> ids, {
    _QueueTask task = _QueueTask.install,
  }) {
    setState(() {
      _queue = ids
          .map(
            (id) => _QueueEntry(
              id: id,
              title: id,
              task: task,
              status: _QueueStatus.waiting,
            ),
          )
          .toList(growable: false);
    });
  }

  void _updateQueueEntry(
    String id, {
    String? title,
    required _QueueStatus status,
    String? message,
    bool clearMessage = false,
  }) {
    setState(() {
      _queue = _queue
          .map(
            (entry) => entry.id == id
                ? entry.copyWith(
                    title: title,
                    status: status,
                    message: message,
                    clearMessage: clearMessage,
                  )
                : entry,
          )
          .toList(growable: false);
    });
  }

  int _markRemainingQueueSkipped(Iterable<String> ids) {
    final skippedIds = queueIdsToMarkSkippedForTest(
      queueIds: _queue.map((entry) => entry.id),
      requestedIds: ids,
    );
    for (final id in skippedIds) {
      _updateQueueEntry(id, status: _QueueStatus.skipped, message: '用户停止队列');
    }
    return skippedIds.length;
  }

  int get _downloadThreadLimit {
    return downloadThreadLimitForTest(
      multiThreadDownload: _multiThreadDownload,
      maxDownloadThreads: _maxDownloadThreadsController.text,
    );
  }

  Future<void> _forEachDownloadTask<T>(
    List<T> items,
    Future<void> Function(T item, int index) task,
  ) async {
    final limit = _downloadThreadLimit;
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (_stopRequested) {
          return;
        }
        final index = nextIndex;
        if (index >= items.length) {
          return;
        }
        nextIndex += 1;
        await task(items[index], index);
      }
    }

    final workers = List<Future<void>>.generate(
      downloadWorkerCountForTest(itemCount: items.length, threadLimit: limit),
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  void _clearFilters() {
    _uploaderController.clear();
    _filterTextController.clear();
    _requiredComponentsController.clear();
    _excludedComponentsController.clear();
    _includeTagsController.clear();
    _excludeTagsController.clear();
    _minDownloadsController.clear();
    _minPlaysController.clear();
    _maxPlaysController.clear();
    _minUpvotesController.clear();
    _minUpvoteRatioController.clear();
    _maxUpvoteRatioController.clear();
    _maxDownvotesController.clear();
    _minDownvoteRatioController.clear();
    _maxDownvoteRatioController.clear();
    _minScoreController.clear();
    _maxScoreController.clear();
    _minBpmController.clear();
    _maxBpmController.clear();
    _uploadedAfterController.clear();
    _uploadedBeforeController.clear();
    _minNotesController.clear();
    _maxNotesController.clear();
    _minBombsController.clear();
    _maxBombsController.clear();
    _minObstaclesController.clear();
    _maxObstaclesController.clear();
    _minMapSecondsController.clear();
    _maxMapSecondsController.clear();
    _minNjsController.clear();
    _maxNjsController.clear();
    _minNpsController.clear();
    _maxNpsController.clear();
    _minOffsetController.clear();
    _maxOffsetController.clear();
    _minEventsController.clear();
    _maxEventsController.clear();
    _minSageScoreController.clear();
    _maxSageScoreController.clear();
    _minStarsController.clear();
    _maxStarsController.clear();
    _minMaxScoreController.clear();
    _maxMaxScoreController.clear();
    _maxParityErrorsController.clear();
    _maxParityWarnsController.clear();
    _maxParityResetsController.clear();
    _downloadLimitController.clear();
    _difficultyFilterController.clear();
    _characteristicFilterController.clear();
    setState(() {
      _minRating = 0.0;
      _maxDurationSeconds = 0;
      _curatedOnly = false;
      _noodleOnly = false;
      _chromaOnly = false;
      _cinemaOnly = false;
      _rankedOnly = false;
      _qualifiedOnly = false;
      _hideAi = false;
      _regexSearchMode = false;
      _filterTitle = false;
      _filterSongName = false;
      _filterSongAuthor = false;
      _filterMapper = false;
      _filterDescription = false;
      _filterTags = false;
      _filterRegexMode = false;
      _tagFilterEnabled = false;
      _untaggedOnly = false;
      _chinesePresetOnly = false;
      _requireAllDifficulties = false;
      _difficultyMatchAll = false;
      _searchPage = 0;
      _totalResults = 0;
      _totalPages = 0;
      _status = clearedStatusForTest('筛选');
    });
  }

  void _applyAcgIncludePreset() {
    _includeTagsController.text = 'anime game vocaloid j-pop';
    final status = presetAppliedStatusForTest('ACG 白名单预设');
    setState(() {
      _tagFilterEnabled = true;
      _untaggedOnly = false;
      _searchPage = 0;
      _status = status;
    });
    _addLog(status);
  }

  void _applyAcgExcludePreset() {
    _excludeTagsController.text = 'anime game vocaloid j-pop';
    final status = presetAppliedStatusForTest('ACG 黑名单预设');
    setState(() {
      _tagFilterEnabled = true;
      _untaggedOnly = false;
      _searchPage = 0;
      _status = status;
    });
    _addLog(status);
  }

  Future<void> _downloadZip(BeatSaverMap map) async {
    _setQueueForMaps([map], task: _QueueTask.downloadZip);
    _stopRequested = false;
    await _run('正在下载 ZIP：${map.metadata.songName}...', () async {
      _updateQueueEntry(map.id, status: _QueueStatus.running);
      final file = await _downloadZipOne(map);
      _updateQueueEntry(
        map.id,
        status: _QueueStatus.completed,
        message: file.path,
      );
      setState(() {
        _status = completedFileStatusForTest(
          label: 'ZIP',
          separator: ' ',
          path: file.path,
        );
      });
      _addLog(
        completedFileStatusForTest(
          label: 'ZIP',
          separator: ' ',
          path: file.path,
        ),
      );
    });
  }

  Future<File> _downloadZipOne(BeatSaverMap map) {
    return _downloadZipOneAsync(map);
  }

  Future<File> _downloadZipOneAsync(BeatSaverMap map) async {
    final cachedZip = await _findZipCacheFileForDownloadMode(map);
    if (cachedZip != null) {
      _addLog('下载来源：本地 ZIP 缓存，${cachedZip.path}');
      final destination = File(
        '${_downloadDirectory.path}${Platform.pathSeparator}'
        '${map.id}-${map.latestVersion?.hash ?? 'cached'}.zip',
      );
      if (cachedZip.path == destination.path) {
        return cachedZip;
      }
      await _downloadDirectory.create(recursive: true);
      return cachedZip.copy(destination.path);
    }
    return _downloadLatestVersionForDownloadMode(map, _downloadDirectory);
  }

  BeatSaverClient _downloadClient() {
    final retryCount = _parseInt(_downloadRetryController.text) ?? 0;
    final timeoutSeconds = _parseInt(_downloadTimeoutController.text) ?? 0;
    return _apiClient(
      downloadRetryCount: retryCount,
      downloadTimeout: timeoutSeconds > 0
          ? Duration(seconds: timeoutSeconds)
          : null,
    );
  }

  BeatSaverClient _apiClient({
    int downloadRetryCount = 0,
    Duration? downloadTimeout,
  }) {
    final requestRetryCount = _parseInt(_requestRetryController.text) ?? 0;
    final requestTimeoutSeconds =
        _parseInt(_requestTimeoutController.text) ?? 0;
    final apiBaseUrl = _apiBaseUrlController.text.trim();
    final baseUri = apiBaseUrl.isEmpty ? null : Uri.tryParse(apiBaseUrl);
    return BeatSaverClient(
      baseUri: baseUri?.hasScheme == true && baseUri?.host.isNotEmpty == true
          ? baseUri
          : null,
      requestRetryCount: requestRetryCount,
      requestTimeout: requestTimeoutSeconds > 0
          ? Duration(seconds: requestTimeoutSeconds)
          : null,
      userAgent: _userAgentController.text,
      downloadRetryCount: downloadRetryCount,
      downloadTimeout: downloadTimeout,
    );
  }

  Future<File?> _findZipCacheFile(BeatSaverMap map) async {
    final directory = _downloadDirectory;
    if (!await directory.exists()) {
      return null;
    }
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.zip')) {
        continue;
      }
      final fileName = entity.uri.pathSegments.last;
      if (_zipCacheMapId(fileName) == map.id.toLowerCase()) {
        return entity;
      }
    }
    return null;
  }

  Future<File?> _findZipCacheFileForDownloadMode(BeatSaverMap map) {
    return switch (_downloadMode.toDownloadModeForTest()) {
      DownloadModeForTest.localCache => _findZipCacheFile(map),
      DownloadModeForTest.zeyuCache => Future<File?>.value(),
      DownloadModeForTest.api => Future<File?>.value(),
    };
  }

  Future<File> _downloadLatestVersionForDownloadMode(
    BeatSaverMap map,
    Directory outputDirectory,
  ) async {
    final version = map.latestVersion;
    final source = downloadSourceForTest(
      mode: _downloadMode.toDownloadModeForTest(),
      hasVersionHash: version != null && version.hash.isNotEmpty,
    );
    return switch (source) {
      DownloadSourceForTest.zeyuCache => () async {
        final zeyuVersion = version!;
        final uri = zeyuCacheZipUriForTest(zeyuVersion.hash);
        _addLog('下载来源：泽宇缓存，$uri');
        return _downloadClient().downloadLatestVersionFromUrl(
          map,
          uri,
          outputDirectory,
        );
      }(),
      DownloadSourceForTest.localZipCache ||
      DownloadSourceForTest.beatSaverApi => () async {
        if (version != null && version.downloadUrl.isNotEmpty) {
          _addLog('下载来源：BeatSaver API，${version.downloadUrl}');
        }
        return _downloadClient().downloadLatestVersion(map, outputDirectory);
      }(),
    };
  }

  Future<void> _installCachedZip(BeatSaverMap map, File zipFile) async {
    await _extractCachedZipToDirectory(map, zipFile, _libraryDirectory);
  }

  Future<void> _installIntoDirectory(
    BeatSaverMap map,
    Directory outputDirectory,
  ) async {
    final localSongDirectory = await _findLocalSongDirectory(map);
    if (localSongDirectory != null) {
      await copyDirectoryRecursive(
        localSongDirectory,
        Directory(
          '${outputDirectory.path}${Platform.pathSeparator}'
          '${installedSongDirectoryName(map, template: _directoryNameTemplate, asciiOnly: _asciiDirectoryNames)}',
        ),
      );
      return;
    }
    final cachedZip = await _findZipCacheFileForDownloadMode(map);
    if (cachedZip == null) {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'beat_saber_song_toolkit_',
      );
      try {
        final zipFile = await _downloadLatestVersionForDownloadMode(
          map,
          tempDirectory,
        );
        await _extractCachedZipToDirectory(map, zipFile, outputDirectory);
      } finally {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      }
      return;
    }
    await _extractCachedZipToDirectory(map, cachedZip, outputDirectory);
  }

  Future<Directory?> _findLocalSongDirectory(BeatSaverMap map) {
    final directories = _localSongDirectories;
    if (directories.isEmpty) {
      return Future<Directory?>.value();
    }
    return findInstalledMapDirectory(
      map,
      directories.first,
      extraDirectories: directories.skip(1),
    );
  }

  Future<void> _extractCachedZipToDirectory(
    BeatSaverMap map,
    File zipFile,
    Directory outputDirectory,
  ) async {
    final songDirectory = Directory(
      '${outputDirectory.path}${Platform.pathSeparator}'
      '${installedSongDirectoryName(map, template: _directoryNameTemplate, asciiOnly: _asciiDirectoryNames)}',
    );
    await songDirectory.create(recursive: true);
    await extractZipBytesToDirectory(
      await zipFile.readAsBytes(),
      songDirectory,
    );
  }

  Future<void> _exportPlaylist() async {
    await _run('正在导出歌单...', () async {
      final playlistImage = await _playlistImageDataUrl();
      final file = await exportBplist(
        libraryDirectory: _libraryDirectory,
        outputFile: File(
          _outputPathFromTemplate(
            _playlistController.text.trim(),
            extension: 'bplist',
          ),
        ),
        playlistTitle: _playlistTitleController.text.trim().isEmpty
            ? 'Beat Saber 歌单'
            : _playlistTitleController.text.trim(),
        playlistImage: playlistImage,
      );
      final status = completedFileStatusForTest(
        label: '歌单',
        action: '已导出',
        path: file.path,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<String?> _playlistImageDataUrl() async {
    final imagePath = _playlistImageController.text.trim();
    if (imagePath.isEmpty) {
      return null;
    }
    final file = File(imagePath);
    if (!await file.exists()) {
      _addLog('歌单封面文件不存在：$imagePath');
      return null;
    }
    final mimeType = _imageMimeType(imagePath);
    if (mimeType == null) {
      _addLog('歌单封面格式不支持：$imagePath');
      return null;
    }
    return playlistImageDataUrlForTest(file);
  }

  Future<void> _exportInstalledZip() async {
    await _run('正在打包已安装歌曲...', () async {
      final file = await _exportInstalledZipFile();
      setState(() {
        _status = completedFileStatusForTest(
          label: '歌曲 ZIP',
          action: '已打包',
          separator: ' ',
          path: file.path,
        );
      });
      _addLog(
        completedFileStatusForTest(
          label: '歌曲 ZIP',
          action: '已打包',
          separator: ' ',
          path: file.path,
        ),
      );
    });
  }

  Future<File> _exportInstalledZipFile() {
    final archivePath = _outputPathFromTemplate(
      _archiveController.text.trim(),
      extension: 'zip',
    );
    return exportInstalledSongsZip(
      libraryDirectory: _libraryDirectory,
      outputFile: File(archivePath),
    );
  }

  String _outputPathFromTemplate(String rawPath, {required String extension}) {
    return outputPathFromTemplateForTest(
      rawPath,
      extension: extension,
      profileName: _safeOutputProfileName,
    );
  }

  String get _safeOutputProfileName {
    final raw =
        (_activeProfile.isNotEmpty
                ? _activeProfile
                : _profileNameController.text)
            .trim();
    return safeOutputProfileNameForTest(raw);
  }

  Future<void> _importPlaylist() async {
    final problem = await _playlistImportProblem();
    if (problem != null) {
      setState(() {
        _status = problem;
      });
      return;
    }
    final maps = <String, BeatSaverMap>{};
    var failed = 0;
    await _run('正在读取歌单...', () async {
      final playlist = await readBplist(File(_playlistController.text.trim()));
      var hashCache = await readBeatSaverHashCache(_beatSaverHashCacheFile);
      final localCacheIndex = await _readValidLocalCacheIndex();
      var hashCacheChanged = false;

      for (final entry in playlist.entries) {
        try {
          final map = await _mapFromPlaylistEntry(
            entry,
            hashCache,
            _localCacheHashIndex,
            localCacheIndex,
          );
          maps[map.id] = map;
          if (entry.hash.trim().isNotEmpty) {
            final normalizedHash = entry.hash.trim().toLowerCase();
            final cached = hashCache.get(normalizedHash);
            if (cached == null || cached.id != map.id) {
              hashCache = hashCache.put(
                normalizedHash,
                BeatSaverHashDetail.fromMap(map),
              );
              hashCacheChanged = true;
            }
          }
        } catch (_) {
          failed += 1;
        }
      }

      if (hashCacheChanged) {
        await writeBeatSaverHashCache(_beatSaverHashCacheFile, hashCache);
        _hashCacheStatus = _HashCacheStatus(
          path: _beatSaverHashCacheFile.path,
          entries: hashCache.data.length,
          cacheDate: hashCache.cacheDate,
        );
      }

      final status = importedPlaylistReadyStatusForTest(
        title: playlist.title,
        maps: maps.length,
        failed: failed,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
    if (maps.isEmpty) {
      return;
    }
    await _installMaps(
      _limitedDownloadMaps(maps.values.toList(growable: false)),
      emptyAction: '选择要从歌单安装的谱面',
    );
  }

  Future<void> _importPlaylistToTargets() async {
    final problem = await _playlistImportProblem();
    if (problem != null) {
      setState(() {
        _status = problem;
      });
      return;
    }
    await _run('正在导入歌单到本次...', () async {
      final playlist = await readBplist(File(_playlistController.text.trim()));
      var hashCache = await readBeatSaverHashCache(_beatSaverHashCacheFile);
      final localCacheIndex = await _readValidLocalCacheIndex();
      var hashCacheChanged = false;
      final maps = <String, BeatSaverMap>{};
      var failed = 0;

      for (final entry in playlist.entries) {
        try {
          final map = await _mapFromPlaylistEntry(
            entry,
            hashCache,
            _localCacheHashIndex,
            localCacheIndex,
          );
          maps[map.id] = map;
          if (entry.hash.trim().isNotEmpty) {
            final normalizedHash = entry.hash.trim().toLowerCase();
            final cached = hashCache.get(normalizedHash);
            if (cached == null || cached.id != map.id) {
              hashCache = hashCache.put(
                normalizedHash,
                BeatSaverHashDetail.fromMap(map),
              );
              hashCacheChanged = true;
            }
          }
        } catch (_) {
          failed += 1;
        }
      }

      if (hashCacheChanged) {
        await writeBeatSaverHashCache(_beatSaverHashCacheFile, hashCache);
        _hashCacheStatus = _HashCacheStatus(
          path: _beatSaverHashCacheFile.path,
          entries: hashCache.data.length,
          cacheDate: hashCache.cacheDate,
        );
      }

      final status = importedPlaylistTargetsStatusForTest(
        title: playlist.title,
        added: maps.length,
        failed: failed,
      );
      setState(() {
        _targetMaps = {..._targetMaps, ...maps};
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<String?> _playlistImportProblem() {
    return playlistImportProblemForTest(_playlistController.text);
  }

  Future<BeatSaverMap> _mapFromPlaylistEntry(
    BplistSongEntry entry,
    BeatSaverHashCache hashCache,
    Map<String, BeatSaverMap> localCacheHashIndex,
    LocalCacheIndex? localCacheIndex,
  ) async {
    final id = entry.key.trim();
    if (id.isNotEmpty) {
      return _client.getMapById(id);
    }
    final hash = entry.hash.trim();
    if (hash.isEmpty) {
      throw const FormatException('bplist song entry has no key or hash.');
    }
    final cached = hashCache.get(hash);
    if (cached != null && cached.id.isNotEmpty) {
      try {
        return await _client.getMapById(cached.id);
      } catch (error) {
        _addLog('hash 缓存 ID 读取失败，改用 hash 查询：$hash，$error');
      }
    }
    final localCached = localCacheHashIndex[hash.toLowerCase()];
    if (localCached != null) {
      _addLog('已通过 LocalCache.saver 匹配 hash：$hash -> ${localCached.id}');
      return localCached;
    }
    final indexed = localCacheIndex?.getByHash(hash);
    if (indexed != null && indexed.id.isNotEmpty) {
      try {
        final map = await _client.getMapById(indexed.id);
        _addLog('已通过 LocalCache 轻量索引匹配 hash：$hash -> ${map.id}');
        return map;
      } catch (error) {
        _addLog('LocalCache 轻量索引 ID 读取失败，改用 hash 查询：$hash，$error');
      }
    }
    final map = await _client.getMapByHash(hash);
    _addLog('已通过 hash 查询 BeatSaver：$hash -> ${map.id}');
    return map;
  }

  Future<void> _deleteInstalled(InstalledSongEntry entry) async {
    final id = entry.mapId;
    if (id == null) {
      setState(() {
        _status = missingBeatSaverIdStatusForTest(action: '删除');
      });
      return;
    }
    final confirmed = await _confirmDeleteInstalled(entry);
    if (!confirmed) {
      return;
    }

    await _run('正在删除 ${entry.title ?? entry.directoryName}...', () async {
      final deleted = await deleteInstalledMapById(_libraryDirectory, id);
      final entries = await scanInstalledLibrary(_libraryDirectory);
      final status = deleteInstalledStatusForTest(
        id: id,
        deletedTitle: deleted?.title ?? deleted?.directoryName,
      );
      setState(() {
        _installed = entries;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<bool> _confirmDeleteInstalled(InstalledSongEntry entry) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除已安装歌曲'),
        content: Text(
          installedSingleDeleteConfirmTextForTest(
            title: entry.title ?? entry.directoryName,
            path: entry.directory.path,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('直接删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _applyInstalledPathCorrection(
    InstalledPathCorrection correction,
  ) async {
    final confirmed = await _confirmInstalledPathCorrection(correction);
    if (!confirmed) {
      return;
    }

    final currentName = correction.entry.directoryName;
    final expectedName = correction.expectedDirectoryName;
    await _run('正在重命名本地歌曲目录：$currentName...', () async {
      final renamed = await applyInstalledPathCorrection(correction);
      final entries = await scanInstalledLibrary(_libraryDirectory);
      final status = installedPathCorrectionStatusForTest(
        oldName: currentName,
        newName: expectedName,
        path: renamed.path,
      );
      setState(() {
        _installed = entries;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _applySelectedInstalledPathCorrections(
    List<InstalledPathCorrection> corrections,
  ) async {
    if (corrections.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('可重命名的路径建议');
      });
      return;
    }
    final confirmed = await _confirmInstalledPathCorrections(corrections);
    if (!confirmed) {
      return;
    }

    await _run('正在批量重命名本地歌曲目录...', () async {
      final result = await applyInstalledPathCorrections(corrections);
      final entries = await scanInstalledLibrary(_libraryDirectory);
      final failure = result.failures.isEmpty ? null : result.failures.first;
      final status = installedPathCorrectionBatchStatusForTest(
        requested: result.requested,
        renamed: result.renamed,
        failed: result.failed,
        failureSourcePath: failure?.sourcePath,
        failureExpectedDirectoryName: failure?.expectedDirectoryName,
        failureReason: failure?.reason,
      );
      final remainingCorrections = suggestInstalledPathCorrections(
        entries,
        template: _directoryNameTemplate,
        asciiOnly: _asciiDirectoryNames,
      );
      final remainingKeys = remainingCorrections
          .map(installedPathCorrectionKeyForTest)
          .toSet();
      setState(() {
        _installed = entries;
        _selectedInstalledPathCorrectionKeys =
            _selectedInstalledPathCorrectionKeys.intersection(remainingKeys);
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _deleteSelectedInstalledDuplicates(
    List<InstalledSongEntry> entries,
  ) async {
    if (entries.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('可删除的重复歌曲');
      });
      return;
    }
    final confirmed = await _confirmDeleteInstalledDuplicates(entries);
    if (!confirmed) {
      return;
    }

    await _run('正在备份并删除重复歌曲...', () async {
      final backupDirectory = Directory(
        '${_libraryDirectory.path}_backup'
        '${Platform.pathSeparator}duplicates',
      );
      final result = await deleteInstalledDuplicateEntriesWithBackup(
        entries: entries,
        backupDirectory: backupDirectory,
      );
      final installed = await scanInstalledLibrary(_libraryDirectory);
      final duplicateGroups = findInstalledDuplicateGroups(installed);
      final remainingKeys = installedDuplicateRemovalCandidates(
        duplicateGroups,
      ).map(installedDuplicateEntryKeyForTest).toSet();
      final status = installedDuplicateDeleteStatusForTest(
        requested: result.requested,
        deleted: result.deleted,
        backups: result.backups.length,
        skippedMissing: result.skippedMissing,
        backupDirectory: backupDirectory.path,
      );
      setState(() {
        _installed = installed;
        _selectedInstalledDuplicateKeys = _selectedInstalledDuplicateKeys
            .intersection(remainingKeys);
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<bool> _confirmInstalledPathCorrection(
    InstalledPathCorrection correction,
  ) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重命名目录'),
        content: Text(
          installedPathCorrectionConfirmTextForTest(
            oldName: correction.entry.directoryName,
            newName: correction.expectedDirectoryName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.drive_file_rename_outline),
            label: const Text('重命名'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmInstalledPathCorrections(
    List<InstalledPathCorrection> corrections,
  ) async {
    if (!mounted) {
      return false;
    }
    final preview = corrections
        .take(5)
        .map(
          (correction) =>
              '${correction.entry.directoryName} -> ${correction.expectedDirectoryName}',
        )
        .join('\n');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认批量重命名目录'),
        content: Text(
          installedPathCorrectionBatchConfirmTextForTest(
            count: corrections.length,
            preview: preview,
            hiddenCount: corrections.length > 5 ? corrections.length - 5 : 0,
            templateDifferenceOnly: corrections.every((correction) {
              return !_installedPathCorrectionIsAbnormal(correction);
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.drive_file_rename_outline),
            label: const Text('批量重命名'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmDeleteInstalledDuplicates(
    List<InstalledSongEntry> entries,
  ) async {
    if (!mounted) {
      return false;
    }
    final preview = entries
        .take(5)
        .map((entry) => '${entry.directoryName}\n${entry.directory.path}')
        .join('\n\n');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认备份删除重复歌曲'),
        content: Text(
          installedDuplicateDeleteConfirmTextForTest(
            count: entries.length,
            preview: preview,
            hiddenCount: entries.length > 5 ? entries.length - 5 : 0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('备份并删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _addInstalledToTargets(InstalledSongEntry entry) async {
    final id = entry.mapId;
    if (id == null || id.isEmpty) {
      setState(() {
        _status = missingBeatSaverIdStatusForTest(action: '加入本次');
      });
      return;
    }

    await _run('正在加入本次：${entry.title ?? entry.directoryName}...', () async {
      try {
        final map = await _client.getMapById(id);
        final title = _mapTitle(map);
        setState(() {
          _targetMaps = {..._targetMaps, map.id: map};
          _status = addedTargetStatusForTest(title);
        });
        _addLog(addedTargetStatusForTest(title));
      } catch (error) {
        setState(() {
          _status = '加入本次失败：$error';
        });
        _addLog('加入本次失败：$id，$error');
      }
    });
  }

  Future<void> _addInstalledEntriesToTargets(
    List<InstalledSongEntry> entries,
  ) async {
    final ids = entries
        .map((entry) => entry.mapId?.trim().toLowerCase())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      setState(() {
        _status = '当前过滤结果没有可加入的 BeatSaver id';
      });
      return;
    }

    await _run('正在加入 ${ids.length} 首已安装歌曲到本次...', () async {
      final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
      var added = 0;
      var failed = 0;
      for (final id in ids) {
        try {
          final map = await _client.getMapById(id);
          targetMaps[map.id] = map;
          added += 1;
        } catch (error) {
          failed += 1;
          _addLog('加入已安装失败：$id，$error');
        }
      }
      setState(() {
        _targetMaps = targetMaps;
        _status = successFailureStatusForTest(
          label: '已安装加入本次完成',
          success: added,
          failed: failed,
        );
      });
      _addLog(
        successFailureStatusForTest(
          label: '已安装加入本次完成',
          success: added,
          failed: failed,
        ),
      );
    });
  }

  Future<_PlaylistSyncMissingResolveResult> _resolvePlaylistSyncMissingEntries(
    List<PlaylistSyncEntry> missing, {
    required String queueMessage,
  }) async {
    setState(() {
      _queue = [
        for (final entry in missing)
          _QueueEntry(
            id: _playlistSyncMissingQueueId(entry),
            title: _playlistSyncTitle(entry),
            task: _QueueTask.resolveMissing,
            status: _QueueStatus.waiting,
            message: '等待解析',
          ),
      ];
    });
    var hashCache = await readBeatSaverHashCache(_beatSaverHashCacheFile);
    final localCacheIndex = await _readValidLocalCacheIndex();
    var hashCacheChanged = false;
    final items = <_PlaylistSyncMissingResolvedMap>[];
    var failed = 0;

    for (var index = 0; index < missing.length; index += 1) {
      final entry = missing[index];
      final progress = playlistSyncMissingAddProgressStatusForTest(
        current: index + 1,
        total: missing.length,
        entry: entry,
      );
      setState(() {
        _status = progress;
        _busyDetail = progress;
      });
      _addLog(progress);
      final queueId = _playlistSyncMissingQueueId(entry);
      _updateQueueEntry(
        queueId,
        status: _QueueStatus.running,
        message: queueMessage,
      );
      try {
        final map = await _mapFromPlaylistEntry(
          entry.playlistEntry,
          hashCache,
          _localCacheHashIndex,
          localCacheIndex,
        );
        items.add(_PlaylistSyncMissingResolvedMap(entry: entry, map: map));
        _updateQueueEntry(
          queueId,
          title: _mapTitle(map),
          status: _QueueStatus.completed,
          message: '已解析',
        );
        final hash = entry.hash;
        if (hash.isNotEmpty) {
          final cached = hashCache.get(hash);
          if (cached == null || cached.id != map.id) {
            hashCache = hashCache.put(hash, BeatSaverHashDetail.fromMap(map));
            hashCacheChanged = true;
          }
        }
      } catch (error) {
        failed += 1;
        final id = entry.mapId.isEmpty ? '-' : entry.mapId;
        final hash = entry.hash.isEmpty ? '-' : entry.hash;
        _updateQueueEntry(
          queueId,
          status: _QueueStatus.failed,
          message: error.toString(),
        );
        _addLog('缺失歌单条目解析失败：ID $id，Hash $hash，$error');
      }
    }

    _HashCacheStatus? hashCacheStatus;
    if (hashCacheChanged) {
      await writeBeatSaverHashCache(_beatSaverHashCacheFile, hashCache);
      hashCacheStatus = _HashCacheStatus(
        path: _beatSaverHashCacheFile.path,
        entries: hashCache.data.length,
        cacheDate: hashCache.cacheDate,
      );
      setState(() {
        _hashCacheStatus = hashCacheStatus;
      });
    }

    return _PlaylistSyncMissingResolveResult(
      items: items,
      failed: failed,
      hashCacheStatus: hashCacheStatus,
    );
  }

  Future<void> _addPlaylistSyncMissingToTargets(
    List<PlaylistSyncEntry> entries,
  ) async {
    final missing = entries
        .where((entry) => !entry.isInstalled)
        .toList(growable: false);
    if (missing.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('缺失歌单条目');
      });
      return;
    }

    await _run('正在将 ${missing.length} 首缺失歌曲加入本次...', () async {
      final resolved = await _resolvePlaylistSyncMissingEntries(
        missing,
        queueMessage: '正在解析后加入本次',
      );
      final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
      var added = 0;
      var existing = 0;
      for (final item in resolved.items) {
        final map = item.map;
        final alreadySelected = targetMaps.containsKey(map.id);
        if (alreadySelected) {
          existing += 1;
        } else {
          added += 1;
        }
        targetMaps[map.id] = map;
        _updateQueueEntry(
          _playlistSyncMissingQueueId(item.entry),
          title: _mapTitle(map),
          status: _QueueStatus.completed,
          message: alreadySelected ? '已在本次' : '已新增到本次',
        );
        _addLog(
          alreadySelected
              ? '缺失歌单条目已在本次：${map.id}，${_mapTitle(map)}'
              : '缺失歌单条目已新增到本次：${map.id}，${_mapTitle(map)}',
        );
      }
      final status = playlistSyncMissingAddStatusForTest(
        requested: missing.length,
        added: added,
        existing: existing,
        failed: resolved.failed,
      );
      setState(() {
        _targetMaps = targetMaps;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _downloadPlaylistSyncMissingZips(
    List<PlaylistSyncEntry> entries,
  ) async {
    final missing = entries
        .where((entry) => !entry.isInstalled)
        .toList(growable: false);
    if (missing.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('缺失歌单条目');
      });
      return;
    }

    await _run('正在解析并下载 ${missing.length} 首缺失歌曲...', () async {
      final resolved = await _resolvePlaylistSyncMissingEntries(
        missing,
        queueMessage: '正在解析后下载 ZIP',
      );
      if (resolved.maps.isEmpty) {
        final status = playlistSyncMissingDownloadStatusForTest(
          requested: missing.length,
          resolved: 0,
          downloaded: 0,
          skipped: 0,
          stopped: 0,
          failed: resolved.failed,
        );
        setState(() {
          _status = status;
        });
        _addLog(status);
        return;
      }

      _setQueueForMaps(resolved.maps, task: _QueueTask.downloadZip);
      _stopRequested = false;
      final summary = await _downloadRawZipsForMaps(resolved.maps);
      final status = playlistSyncMissingDownloadStatusForTest(
        requested: missing.length,
        resolved: resolved.maps.length,
        downloaded: summary.downloaded,
        skipped: summary.skipped,
        stopped: summary.stopped,
        failed: resolved.failed + summary.failed,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _installPlaylistSyncMissing(
    List<PlaylistSyncEntry> entries,
  ) async {
    final missing = entries
        .where((entry) => !entry.isInstalled)
        .toList(growable: false);
    if (missing.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('缺失歌单条目');
      });
      return;
    }

    await _run('正在解析并安装 ${missing.length} 首缺失歌曲...', () async {
      final resolved = await _resolvePlaylistSyncMissingEntries(
        missing,
        queueMessage: '正在解析后安装',
      );
      if (resolved.maps.isEmpty) {
        final status = playlistSyncMissingInstallStatusForTest(
          requested: missing.length,
          resolved: 0,
          installed: 0,
          skipped: 0,
          stopped: 0,
          failed: resolved.failed,
        );
        setState(() {
          _status = status;
        });
        _addLog(status);
        return;
      }

      _setQueueForMaps(resolved.maps);
      _stopRequested = false;
      final summary = await _installMapsCore(resolved.maps);
      final status = playlistSyncMissingInstallStatusForTest(
        requested: missing.length,
        resolved: resolved.maps.length,
        installed: summary.installed,
        skipped: summary.skipped,
        stopped: summary.stopped,
        failed: resolved.failed + summary.failed,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  void _addInstalledEntriesToSkip(List<InstalledSongEntry> entries) {
    final ids = entries
        .map((entry) => entry.mapId?.trim().toLowerCase())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      setState(() {
        _status = '当前过滤结果没有可加入跳过的 BeatSaver id';
      });
      return;
    }

    final existing = _parseBeatSaverIds(_skipMapsController.text);
    final merged = mergedSkipIdsForTest(existingIds: existing, newIds: ids);
    setState(() {
      _skipMapsController.text = merged.join('\n');
      _status = songCountStatusForTest(label: '已加入跳过歌曲', count: ids.length);
    });
    _addLog('已从已安装加入跳过歌曲：${ids.length} 首');
  }

  void _addZipCacheToSkip(List<ZipCacheEntryUiModel> entries) {
    final ids = zipCacheMapIdsForTest(entries);
    if (ids.isEmpty) {
      setState(() {
        _status = 'ZIP 缓存没有可识别的 BeatSaver id';
      });
      return;
    }

    final existing = _parseBeatSaverIds(_skipMapsController.text);
    final merged = <String>{...existing, ...ids}.toList(growable: false);
    setState(() {
      _skipMapsController.text = merged.join('\n');
      _status = songCountStatusForTest(
        label: '已从 ZIP 缓存加入跳过歌曲',
        count: ids.length,
      );
    });
    _addLog(
      songCountStatusForTest(label: '已从 ZIP 缓存加入跳过歌曲', count: ids.length),
    );
  }

  Future<void> _addZipCacheToTargets(List<ZipCacheEntryUiModel> entries) async {
    final ids = zipCacheMapIdsForTest(entries);
    if (ids.isEmpty) {
      setState(() {
        _status = 'ZIP 缓存没有可加入本次的 BeatSaver id';
      });
      return;
    }

    await _run('正在加入 ${ids.length} 个 ZIP 缓存到本次...', () async {
      final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
      var added = 0;
      var failed = 0;
      for (final id in ids) {
        try {
          final map = await _client.getMapById(id);
          targetMaps[map.id] = map;
          added += 1;
        } catch (error) {
          failed += 1;
          _addLog('ZIP 缓存加入本次失败：$id，$error');
        }
      }
      setState(() {
        _targetMaps = targetMaps;
        _status = successFailureStatusForTest(
          label: 'ZIP 缓存加入本次完成',
          success: added,
          failed: failed,
        );
      });
      _addLog(
        successFailureStatusForTest(
          label: 'ZIP 缓存加入本次完成',
          success: added,
          failed: failed,
        ),
      );
    });
  }

  Future<void> _pickAndroidDirectory() async {
    await _run('正在打开 Android 目录授权...', () async {
      final uri = await _androidStorage.pickDirectory();
      final status = androidDirectoryStatusForTest(uri);
      setState(() {
        _androidTreeUri = uri;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _pickLibraryDirectory() async {
    await _pickDirectoryInto(
      controller: _libraryController,
      statusLabel: '安装目录',
    );
  }

  Future<void> _pickLocalSongsDirectory() async {
    await _pickDirectoryInto(
      controller: _localSongsDirectoryController,
      statusLabel: '本地歌曲目录',
    );
  }

  Future<void> _pickGameDirectory() async {
    await _pickDirectoryInto(
      controller: _gameDirectoryController,
      statusLabel: '游戏目录',
    );
    await _inspectGameDirectory();
  }

  Future<void> _pickSkipExistingDirectory() async {
    await _pickDirectoryInto(
      controller: _skipExistingDirectoryController,
      statusLabel: '跳过已有目录',
    );
  }

  Future<void> _pickDownloadDirectory() async {
    await _pickDirectoryInto(
      controller: _downloadController,
      statusLabel: 'ZIP 下载目录',
    );
  }

  Future<void> _refreshZipCache() async {
    await _run('正在扫描 ZIP 缓存...', () async {
      final zipCache = await _scanZipCache();
      setState(() {
        _zipCache = zipCache;
        _status = zipCacheCountStatusForTest(zipCache.length);
      });
      _addLog('ZIP 缓存扫描完成：${zipCache.length} 个');
    });
  }

  Future<void> _inspectGameDirectory() async {
    final path = _gameDirectoryController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _gameDirectoryStatus = null;
        _songCoreFolderEntries = const [];
        _songCoreLastBackupDirectory = null;
        _status = requireActionStatusForTest('填写游戏目录');
      });
      return;
    }
    final status = inspectBeatSaberGameDirectory(Directory(path));
    final entries = await _readSongCoreFolderEntries(status);
    final text = gameDirectoryInspectStatusForTest(
      isBeatSaberDirectory: status.isBeatSaberDirectory,
      songCoreInstalled: status.isSongCoreInstalled,
      playlistManagerInstalled: status.isPlaylistManagerInstalled,
      path: status.gameDirectory.path,
    );
    setState(() {
      _gameDirectoryStatus = status;
      _songCoreFolderEntries = entries;
      _songCoreLastBackupDirectory = songCoreBackupDirectoryForTest(
        foldersFilePath: status.songCoreFoldersFile.path,
      );
      _status = text;
    });
    _addLog(text);
  }

  Future<List<SongCoreFolderEntry>> _readSongCoreFolderEntries(
    BeatSaberGameDirectoryStatus status,
  ) async {
    try {
      return await readSongCoreFolderEntries(status.songCoreFoldersFile);
    } catch (error) {
      _addLog('读取 SongCore 保存列表失败：$error');
      return const [];
    }
  }

  Future<void> _autoInspectConfiguredGameDirectory() async {
    try {
      final result = await autoInspectConfiguredGameDirectoryForTest(
        _gameDirectoryController.text,
      );
      if (result == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _gameDirectoryStatus = result.status;
        _songCoreFolderEntries = result.entries;
        _songCoreLastBackupDirectory = result.backupDirectory;
        _status = result.statusText;
      });
      _addLog(result.statusText);
    } catch (error) {
      _addLog('自动检测游戏目录失败：$error');
    }
  }

  Future<void> _refreshSongCoreFolderEntries() async {
    final path = _gameDirectoryController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('填写游戏目录');
      });
      return;
    }
    await _run('正在读取 SongCore 保存列表...', () async {
      final status = inspectBeatSaberGameDirectory(Directory(path));
      final entries = await readSongCoreFolderEntries(
        status.songCoreFoldersFile,
      );
      final text = songCoreFolderReadStatusForTest(
        count: entries.length,
        path: status.songCoreFoldersFile.path,
        backupDirectory: songCoreBackupDirectoryForTest(
          foldersFilePath: status.songCoreFoldersFile.path,
        ),
      );
      setState(() {
        _gameDirectoryStatus = status;
        _songCoreFolderEntries = entries;
        _songCoreLastBackupDirectory = songCoreBackupDirectoryForTest(
          foldersFilePath: status.songCoreFoldersFile.path,
        );
        _status = text;
      });
      _addLog(text);
    });
  }

  Future<void> _saveSongCoreFolderList() async {
    final gamePath = _gameDirectoryController.text.trim();
    if (gamePath.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('填写游戏目录');
      });
      return;
    }
    final songFolderPath = _libraryController.text.trim();
    if (songFolderPath.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('填写安装目录');
      });
      return;
    }

    await _run('正在写入 SongCore 保存列表...', () async {
      final result = await saveSongCoreFolderEntry(
        gameDirectory: Directory(gamePath),
        songFolder: Directory(songFolderPath),
        name: _playlistTitleController.text,
        imageFile: _playlistImageController.text.trim().isEmpty
            ? null
            : File(_playlistImageController.text.trim()),
      );
      final status = inspectBeatSaberGameDirectory(Directory(gamePath));
      final validSongs = await countValidInstalledSongs(
        Directory(songFolderPath),
      );
      final text = songCoreFolderSaveStatusForTest(
        added: result.added,
        updated: result.updated,
        validSongs: validSongs,
        path: result.file.path,
        songFolderPath: Directory(songFolderPath).absolute.path,
        backupPath: result.backupFile?.path,
        backupDirectory: result.backupFile?.parent.path,
      );
      setState(() {
        _gameDirectoryStatus = status;
        _songCoreFolderEntries = result.entries;
        _songCoreLastBackupDirectory =
            result.backupFile?.parent.path ?? _songCoreLastBackupDirectory;
        _status = text;
      });
      _addLog(text);
    });
  }

  Future<void> _removeSongCoreFolderEntry(SongCoreFolderEntry entry) async {
    final status = _gameDirectoryStatus;
    if (status == null) {
      setState(() {
        _status = requireActionStatusForTest('检测游戏目录');
      });
      return;
    }
    final confirmed = await _confirmRemoveSongCoreFolderEntry(entry);
    if (!confirmed) {
      setState(() {
        _status = '已取消移除 SongCore 保存列表条目';
      });
      return;
    }
    await _run('正在移除 SongCore 保存列表条目...', () async {
      final result = await removeSongCoreFolderEntries(
        file: status.songCoreFoldersFile,
        keys: [songCoreFolderEntryKey(entry)],
      );
      final refreshedStatus = inspectBeatSaberGameDirectory(
        status.gameDirectory,
      );
      final text = songCoreFolderRemoveStatusForTest(
        removed: result.removed,
        remaining: result.entries.length,
        path: result.file.path,
        removedEntryPath: entry.path,
        backupPath: result.backupFile?.path,
        backupDirectory: result.backupFile?.parent.path,
      );
      setState(() {
        _gameDirectoryStatus = refreshedStatus;
        _songCoreFolderEntries = result.entries;
        _songCoreLastBackupDirectory =
            result.backupFile?.parent.path ?? _songCoreLastBackupDirectory;
        _status = text;
      });
      _addLog(text);
    });
  }

  Future<void> _copySongCorePath(String? path, String label) async {
    final value = path?.trim() ?? '';
    if (value.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest(label);
      });
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    final text = copiedPathStatusForTest(label: label, path: value);
    setState(() {
      _status = text;
    });
    _addLog(text);
  }

  Future<bool> _confirmRemoveSongCoreFolderEntry(
    SongCoreFolderEntry entry,
  ) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移除保存列表'),
        content: Text(
          songCoreFolderRemoveConfirmTextForTest(
            name: entry.name.isEmpty ? '-' : entry.name,
            path: entry.path,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('移除条目'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _scanPlaylistSync() async {
    final playlistPath = _playlistController.text.trim();
    if (playlistPath.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择歌单文件');
      });
      return;
    }
    final playlistFile = File(playlistPath);
    if (!await playlistFile.exists()) {
      setState(() {
        _status = '歌单文件不存在：$playlistPath';
      });
      return;
    }

    await _run('正在扫描歌单同步差异...', () async {
      final playlist = await readBplist(playlistFile);
      final hashCache = await readBeatSaverHashCache(_beatSaverHashCacheFile);
      final comparison = await comparePlaylistWithInstalledLibraryDetailed(
        playlist: playlist,
        libraryDirectory: _libraryDirectory,
        hashDetails: hashCache.data,
      );
      final syncEntries = comparison.entries;
      final installed = await scanInstalledLibrary(_libraryDirectory);
      final status = playlistSyncStatusForTest(syncEntries);
      setState(() {
        _playlistSyncEntries = syncEntries;
        _playlistSyncLocalOnlyInstalledEntries =
            comparison.localOnlyInstalledEntries;
        _selectedPlaylistSyncEntryKeys = const {};
        _installed = installed;
        _hashCacheStatus = _HashCacheStatus(
          path: _beatSaverHashCacheFile.path,
          entries: hashCache.data.length,
          cacheDate: hashCache.cacheDate,
        );
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _exportPlaylistSyncEntries(
    List<PlaylistSyncEntry> entries,
  ) async {
    if (entries.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('歌单同步结果');
      });
      return;
    }

    await _run('正在导出歌单同步结果...', () async {
      final path = await getSaveLocation(
        suggestedName: 'playlist_sync.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '歌单同步结果', path: null);
        });
        return;
      }
      await File(
        path.path,
      ).writeAsString(playlistSyncExportListForTest(entries), flush: true);
      final status = exportFileStatusForTest(label: '歌单同步结果', path: path.path);
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _deletePlaylistSyncEntries(
    List<PlaylistSyncEntry> entries,
  ) async {
    final deletable = entries
        .where((entry) => entry.installedEntry != null)
        .toList(growable: false);
    if (deletable.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('可删除的歌单同步条目');
      });
      return;
    }
    final playlistPath = _playlistController.text.trim();
    if (playlistPath.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择歌单文件');
      });
      return;
    }
    final playlistFile = File(playlistPath);
    if (!await playlistFile.exists()) {
      setState(() {
        _status = '歌单文件不存在：$playlistPath';
      });
      return;
    }

    final confirmed = await _confirmPlaylistSyncDelete(deletable.length);
    if (!confirmed) {
      setState(() {
        _status = '已取消歌单同步删除';
      });
      return;
    }

    await _run('正在备份并删除歌单同步条目...', () async {
      final backupDirectory = Directory(
        '${playlistFile.parent.path}${Platform.pathSeparator}backup',
      );
      final result = await deletePlaylistSyncEntriesWithBackup(
        playlistFile: playlistFile,
        entries: deletable,
        backupDirectory: backupDirectory,
      );
      final hashCache = await readBeatSaverHashCache(_beatSaverHashCacheFile);
      final playlist = await readBplist(playlistFile);
      final syncEntries = await comparePlaylistWithInstalledLibrary(
        playlist: playlist,
        libraryDirectory: _libraryDirectory,
        hashDetails: hashCache.data,
      );
      final installed = await scanInstalledLibrary(_libraryDirectory);
      final status = playlistSyncDeleteStatusForTest(result);
      setState(() {
        _playlistSyncEntries = syncEntries;
        _selectedPlaylistSyncEntryKeys = const {};
        _installed = installed;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _removePlaylistSyncEntriesFromPlaylist(
    List<PlaylistSyncEntry> entries,
  ) async {
    final selected = entries.toList(growable: false);
    if (selected.isEmpty) {
      setState(() {
        _status = emptyActionStatusForTest('可移出歌单的条目');
      });
      return;
    }
    final playlistPath = _playlistController.text.trim();
    if (playlistPath.isEmpty) {
      setState(() {
        _status = requireActionStatusForTest('选择歌单文件');
      });
      return;
    }
    final playlistFile = File(playlistPath);
    if (!await playlistFile.exists()) {
      setState(() {
        _status = '歌单文件不存在：$playlistPath';
      });
      return;
    }

    final confirmed = await _confirmPlaylistSyncPlaylistRemove(selected.length);
    if (!confirmed) {
      setState(() {
        _status = '已取消从歌单移出条目';
      });
      return;
    }

    await _run('正在从歌单移出条目...', () async {
      final backupDirectory = Directory(
        '${playlistFile.parent.path}${Platform.pathSeparator}backup',
      );
      final result = await removePlaylistSyncEntriesFromBplistWithBackup(
        playlistFile: playlistFile,
        entries: selected,
        backupDirectory: backupDirectory,
      );
      final hashCache = await readBeatSaverHashCache(_beatSaverHashCacheFile);
      final playlist = await readBplist(playlistFile);
      final syncEntries = await comparePlaylistWithInstalledLibrary(
        playlist: playlist,
        libraryDirectory: _libraryDirectory,
        hashDetails: hashCache.data,
      );
      final status = playlistSyncPlaylistRemoveStatusForTest(result);
      setState(() {
        _playlistSyncEntries = syncEntries;
        _selectedPlaylistSyncEntryKeys = const {};
        _status = status;
      });
      _addLog(status);
    });
  }

  void _togglePlaylistSyncEntrySelection(
    PlaylistSyncEntry entry,
    bool selected,
  ) {
    final key = playlistSyncEntryKeyForTest(entry);
    if (key.isEmpty) {
      return;
    }
    setState(() {
      final keys = _selectedPlaylistSyncEntryKeys.toSet();
      if (selected) {
        keys.add(key);
      } else {
        keys.remove(key);
      }
      _selectedPlaylistSyncEntryKeys = keys;
    });
  }

  void _selectPlaylistSyncEntries(List<PlaylistSyncEntry> entries) {
    setState(() {
      _selectedPlaylistSyncEntryKeys = {
        ..._selectedPlaylistSyncEntryKeys,
        for (final entry in entries) playlistSyncEntryKeyForTest(entry),
      }.where((key) => key.isNotEmpty).toSet();
    });
  }

  void _clearPlaylistSyncSelection(List<PlaylistSyncEntry> entries) {
    final removeKeys = entries
        .map(playlistSyncEntryKeyForTest)
        .where((key) => key.isNotEmpty)
        .toSet();
    setState(() {
      _selectedPlaylistSyncEntryKeys = _selectedPlaylistSyncEntryKeys
          .where((key) => !removeKeys.contains(key))
          .toSet();
    });
  }

  Future<bool> _confirmPlaylistSyncDelete(int count) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认备份删除'),
        content: Text(playlistSyncDeleteConfirmTextForTest(count: count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('备份并删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmPlaylistSyncPlaylistRemove(int count) async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移出歌单'),
        content: Text(
          playlistSyncPlaylistRemoveConfirmTextForTest(count: count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.playlist_remove),
            label: const Text('移出歌单'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickPlaylistFile() async {
    await _run('正在选择歌单文件...', () async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Beat Saber 歌单', extensions: ['bplist']),
          XTypeGroup(label: '所有文件', extensions: ['*']),
        ],
      );
      if (file == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: '歌单文件', path: null);
        });
        return;
      }
      final status = pathSelectionStatusForTest(label: '歌单文件', path: file.path);
      setState(() {
        _playlistController.text = file.path;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _pickPlaylistSaveFile() async {
    await _run('正在选择歌单保存位置...', () async {
      final path = await getSaveLocation(
        suggestedName: '$_safeOutputProfileName.bplist',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Beat Saber 歌单', extensions: ['bplist']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: '歌单保存位置', path: null);
        });
        return;
      }
      final status = pathSelectionStatusForTest(
        label: '歌单保存位置',
        path: path.path,
      );
      setState(() {
        _playlistController.text = path.path;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _pickPlaylistImageFile() async {
    await _run('正在选择歌单封面...', () async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '图片',
            extensions: ['jpg', 'jpeg', 'png', 'bmp', 'gif'],
          ),
          XTypeGroup(label: '所有文件', extensions: ['*']),
        ],
      );
      if (file == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: '歌单封面', path: null);
        });
        return;
      }
      final status = pathSelectionStatusForTest(label: '歌单封面', path: file.path);
      setState(() {
        _playlistImageController.text = file.path;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _pickArchiveSaveFile() async {
    await _run('正在选择 ZIP 保存位置...', () async {
      final path = await getSaveLocation(
        suggestedName: '$_safeOutputProfileName.zip',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'ZIP 压缩包', extensions: ['zip']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: 'ZIP 保存位置', path: null);
        });
        return;
      }
      final status = pathSelectionStatusForTest(
        label: 'ZIP 保存位置',
        path: path.path,
      );
      setState(() {
        _archiveController.text = path.path;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _pickManualListFile() async {
    await _run('正在读取歌曲列表文件...', () async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt', 'csv', 'list']),
          XTypeGroup(label: '所有文件', extensions: ['*']),
        ],
      );
      if (file == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: '歌曲列表文件', path: null);
        });
        return;
      }
      final content = await File(file.path).readAsString();
      final existing = _manualMapsController.text.trim();
      setState(() {
        _manualMapsController.text = existing.isEmpty
            ? content.trim()
            : '$existing\n${content.trim()}';
        _status = readFileStatusForTest(label: '歌曲列表', path: file.path);
      });
      _addLog(readFileStatusForTest(label: '歌曲列表', path: file.path));
    });
  }

  Future<void> _exportResultsList() async {
    if (_results.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('可导出的搜索结果');
      });
      return;
    }

    await _run('正在导出当前结果列表...', () async {
      final path = await getSaveLocation(
        suggestedName: 'beatsaver_maps.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '结果列表', path: null);
        });
        return;
      }
      final lines = mapExportListForTest(_results);
      await File(path.path).writeAsString(lines, flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: '结果列表', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '结果列表', path: path.path));
    });
  }

  Future<void> _importTargetList() async {
    await _run('正在导入本次歌曲列表...', () async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt', 'csv', 'list']),
          XTypeGroup(label: '所有文件', extensions: ['*']),
        ],
      );
      if (file == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: '本次歌曲列表', path: null);
        });
        return;
      }

      final ids = _parseBeatSaverIds(await File(file.path).readAsString());
      final targetMaps = Map<String, BeatSaverMap>.of(_targetMaps);
      var imported = 0;
      var failed = 0;
      for (final id in ids) {
        try {
          final map = await _client.getMapById(id);
          targetMaps[map.id] = map;
          imported += 1;
        } catch (error) {
          failed += 1;
          _addLog('导入目标失败：$id，$error');
        }
      }
      final status = successFailureStatusForTest(
        label: '本次歌曲导入完成',
        success: imported,
        failed: failed,
      );
      setState(() {
        _targetMaps = targetMaps;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _exportTargetList() async {
    if (_targetMaps.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('本次歌曲');
      });
      return;
    }

    await _run('正在导出本次歌曲列表...', () async {
      final path = await getSaveLocation(
        suggestedName: defaultTargetListExportFilenameForTest,
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '本次歌曲列表', path: null);
        });
        return;
      }
      await _writeTargetList(
        File(path.path),
        _targetMaps.values.toList(growable: false),
      );
      final status = exportFileStatusForTest(label: '本次歌曲列表', path: path.path);
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _writeTargetList(File file, List<BeatSaverMap> maps) async {
    await file.writeAsString(targetExportListForTest(maps), flush: true);
  }

  Future<void> _exportInstalledEntries(List<InstalledSongEntry> entries) async {
    if (entries.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('已安装歌曲');
      });
      return;
    }

    await _run('正在导出已安装列表...', () async {
      final path = await getSaveLocation(
        suggestedName: 'installed_songs.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '已安装列表', path: null);
        });
        return;
      }
      final lines = installedExportListForTest(
        entries.map(installedEntrySnapshotForTest),
      );
      await File(path.path).writeAsString(lines, flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: '已安装列表', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: '已安装列表', path: path.path));
    });
  }

  Future<void> _exportInstalledEntriesPlaylist(
    List<InstalledSongEntry> entries,
  ) async {
    final exportable = entries
        .where(
          (entry) =>
              entry.hasInfoDat &&
              entry.mapId != null &&
              entry.mapId!.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (exportable.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('已安装歌单');
      });
      return;
    }

    await _run('正在导出已安装歌单...', () async {
      final path = await getSaveLocation(
        suggestedName: 'installed_songs.bplist',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Beat Saber 歌单', extensions: ['bplist']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '已安装歌单', path: null);
        });
        return;
      }
      final playlistImage = await _playlistImageDataUrl();
      final file = await exportBplistFromInstalledEntries(
        entries: exportable,
        outputFile: File(path.path),
        playlistTitle: _playlistTitleController.text.trim().isEmpty
            ? 'Beat Saber 歌单'
            : _playlistTitleController.text.trim(),
        playlistImage: playlistImage,
      );
      final status = installedPlaylistExportStatusForTest(
        count: exportable.length,
        skipped: entries.length - exportable.length,
        path: file.path,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _exportFavoritesPlaylist() async {
    await _run('正在读取收藏存档...', () async {
      final playerData = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Beat Saber PlayerData', extensions: ['dat']),
          XTypeGroup(label: '所有文件', extensions: ['*']),
        ],
      );
      if (playerData == null) {
        setState(() {
          _status = pathSelectionStatusForTest(
            label: 'PlayerData.dat',
            path: null,
          );
        });
        return;
      }

      final hashes = await readFavoriteHashesFromPlayerData(
        File(playerData.path),
      );
      if (hashes.isEmpty) {
        setState(() {
          _status = '没有读取到有效的收藏歌曲，请确认这是正确的 PlayerData.dat';
        });
        return;
      }

      final savePath = await getSaveLocation(
        suggestedName: 'favorites.bplist',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Beat Saber 歌单', extensions: ['bplist']),
        ],
      );
      if (savePath == null) {
        setState(() {
          _status = exportFileStatusForTest(label: '收藏歌单', path: null);
        });
        return;
      }

      final playlistImage = await _playlistImageDataUrl();
      final file = await exportFavoriteHashesBplist(
        hashes: hashes,
        outputFile: File(savePath.path),
        playlistImage: playlistImage,
      );
      final status = favoritePlaylistExportStatusForTest(
        count: hashes.length,
        path: file.path,
      );
      setState(() {
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _exportZipCache(List<ZipCacheEntryUiModel> entries) async {
    if (entries.isEmpty) {
      setState(() {
        _status = emptyExportStatusForTest('ZIP 缓存');
      });
      return;
    }

    await _run('正在导出 ZIP 缓存列表...', () async {
      final path = await getSaveLocation(
        suggestedName: 'zip_cache.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: '文本列表', extensions: ['txt']),
        ],
      );
      if (path == null) {
        setState(() {
          _status = exportFileStatusForTest(label: 'ZIP 缓存列表', path: null);
        });
        return;
      }
      final lines = zipCacheExportListForTest(entries);
      await File(path.path).writeAsString(lines, flush: true);
      setState(() {
        _status = exportFileStatusForTest(label: 'ZIP 缓存列表', path: path.path);
      });
      _addLog(exportFileStatusForTest(label: 'ZIP 缓存列表', path: path.path));
    });
  }

  Future<void> _pickDirectoryInto({
    required TextEditingController controller,
    required String statusLabel,
  }) async {
    await _run('正在选择$statusLabel...', () async {
      final path = await getDirectoryPath();
      if (path == null) {
        setState(() {
          _status = pathSelectionStatusForTest(label: statusLabel, path: null);
        });
        return;
      }
      final status = pathSelectionStatusForTest(label: statusLabel, path: path);
      setState(() {
        controller.text = path;
        _status = status;
      });
      _addLog(status);
    });
  }

  Future<void> _installToAndroidTree(BeatSaverMap map, String treeUri) async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'beat_saber_song_toolkit_',
    );
    try {
      final zipFile = await _downloadClient().downloadLatestVersion(
        map,
        tempRoot,
      );
      final entries = decodeZipFileEntries(await zipFile.readAsBytes());
      final songDirectoryName = installedSongDirectoryName(
        map,
        template: _directoryNameTemplate,
        asciiOnly: _asciiDirectoryNames,
      );
      _setStatus('正在写入 Android 目录：${map.metadata.songName}...');
      for (final entry in entries) {
        await _androidStorage.writeFile(
          treeUri: treeUri,
          relativePath: '$songDirectoryName/${entry.relativePath}',
          bytes: entry.bytes,
        );
      }
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Directory get _libraryDirectory {
    final value = _libraryController.text.trim();
    return Directory(value.isEmpty ? 'installed' : value);
  }

  Directory get _downloadDirectory {
    final value = _downloadController.text.trim();
    return Directory(value.isEmpty ? 'downloads' : value);
  }

  List<Directory> get _skipExistingDirectories {
    final value = _skipExistingDirectoryController.text.trim();
    if (!_skipExistingMaps || value.isEmpty) {
      return const [];
    }
    return _directoriesFromText(value);
  }

  List<Directory> get _localSongDirectories {
    final value = _localSongsDirectoryController.text.trim();
    if (value.isEmpty) {
      return const [];
    }
    return _directoriesFromText(value);
  }

  List<Directory> _directoriesFromText(String value) {
    return directoriesFromTextForTest(value);
  }

  String get _directoryNameTemplate {
    final value = _directoryNameTemplateController.text.trim();
    return value.isEmpty ? '[id] - [歌名]' : value;
  }

  Set<String> get _skipMapIds =>
      _parseBeatSaverIds(_skipMapsController.text).toSet();

  File get _settingsFile {
    final appData = Platform.environment['APPDATA'];
    if (Platform.isWindows && appData != null && appData.isNotEmpty) {
      return _settingsFileWithLegacyFallback(
        File('$appData\\BeatSaberSongToolkit\\settings.json'),
        File('$appData\\BeatSpiderReborn\\settings.json'),
      );
    }
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return _settingsFileWithLegacyFallback(
      File(
        '$home${Platform.pathSeparator}.beat_saber_song_toolkit'
        '${Platform.pathSeparator}settings.json',
      ),
      File(
        '$home${Platform.pathSeparator}.beat_spider_reborn'
        '${Platform.pathSeparator}settings.json',
      ),
    );
  }

  File _settingsFileWithLegacyFallback(File current, File legacy) {
    if (current.existsSync() || !legacy.existsSync()) {
      return current;
    }
    try {
      current.parent.createSync(recursive: true);
      legacy.copySync(current.path);
      return current;
    } on FileSystemException {
      return legacy;
    }
  }

  File get _coverLabelCacheFile {
    final settingsFile = _settingsFile;
    return File(
      '${settingsFile.parent.path}${Platform.pathSeparator}cover_label_cache.json',
    );
  }

  File get _beatSaverHashCacheFile {
    final settingsFile = _settingsFile;
    return File(
      '${settingsFile.parent.path}${Platform.pathSeparator}beatsaver_hash_cache.json',
    );
  }

  File get _localCacheIndexFile {
    final settingsFile = _settingsFile;
    return File(
      '${settingsFile.parent.path}${Platform.pathSeparator}local_cache_index.json',
    );
  }

  File get _defaultLocalCacheSaverFile {
    final settingsFile = _settingsFile;
    return File(
      '${settingsFile.parent.path}${Platform.pathSeparator}LocalCache.saver',
    );
  }

  File get _currentLocalCacheSaverFile {
    final cachePath = _localCacheSaverController.text.trim();
    return File(
      cachePath.isEmpty ? _defaultLocalCacheSaverFile.path : cachePath,
    );
  }

  bool get _hasCurrentLocalCacheDeletedAudit {
    final audit = _localCacheDeletedAudit;
    if (audit == null) {
      return false;
    }
    return audit.cachePath.toLowerCase() ==
        _currentLocalCacheSaverFile.absolute.path.toLowerCase();
  }

  Future<LocalCacheIndex?> _readValidLocalCacheIndex() async {
    final cachePath = _localCacheSaverController.text.trim();
    if (cachePath.isEmpty) {
      return null;
    }
    final sourceFile = File(cachePath);
    final type = await FileSystemEntity.type(sourceFile.path);
    if (type != FileSystemEntityType.file) {
      return null;
    }
    try {
      final stat = await sourceFile.stat();
      final index = await readLocalCacheIndex(_localCacheIndexFile);
      if (index != null && index.matchesSource(sourceFile, stat)) {
        return index;
      }
    } catch (error) {
      _addLog('读取 LocalCache 轻量索引失败：$error');
    }
    return null;
  }

  Future<void> _writeLocalCacheIndex(
    File sourceFile,
    FileStat sourceStat,
    Iterable<BeatSaverMap> maps,
  ) async {
    try {
      await writeLocalCacheIndex(
        _localCacheIndexFile,
        LocalCacheIndex.fromMaps(
          sourceFile: sourceFile,
          sourceStat: sourceStat,
          maps: maps,
        ),
      );
      _addLog('LocalCache 轻量索引已更新：${_localCacheIndexFile.path}');
    } catch (error) {
      _addLog('写入 LocalCache 轻量索引失败：$error');
    }
  }

  Widget _workspaceSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_Workspace>(
        segments: const [
          ButtonSegment(
            value: _Workspace.search,
            icon: Icon(Icons.search),
            label: Text('找歌下载'),
          ),
          ButtonSegment(
            value: _Workspace.library,
            icon: Icon(Icons.folder_copy_outlined),
            label: Text('本地曲库'),
          ),
          ButtonSegment(
            value: _Workspace.playlistSync,
            icon: Icon(Icons.sync_alt),
            label: Text('歌单同步'),
          ),
        ],
        selected: {_workspace},
        onSelectionChanged: _busy
            ? null
            : (selection) {
                setState(() {
                  _workspace = selection.single;
                });
                unawaited(_saveSettingsSilently());
              },
      ),
    );
  }

  Widget _workspaceBody(bool wide) {
    final search = _buildSearchPanel();
    final library = Column(
      children: [
        _buildInstalledPanel(),
        const SizedBox(height: 16),
        _buildZipCachePanel(),
      ],
    );
    final playlistSync = _buildPlaylistSyncPanel();

    if (_workspace == _Workspace.search) {
      if (!wide) {
        return search;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: search),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: library),
        ],
      );
    }
    if (_workspace == _Workspace.library) {
      return library;
    }
    return playlistSync;
  }

  Widget _buildSearchPanel() {
    return _SearchPanel(
      results: _results,
      selectedMaps: _targetMaps.values.toList(growable: false),
      page: _searchPage,
      pageSize: _pageSize,
      totalResults: _totalResults,
      totalPages: _totalPages,
      busy: _busy,
      stopRequested: _stopRequested,
      onPreviousPage: _searchPage <= 0
          ? null
          : () => _goToSearchPage(_searchPage - 1),
      onNextPage: _totalPages > 0 && _searchPage >= _totalPages - 1
          ? null
          : () => _goToSearchPage(_searchPage + 1),
      onSelectionChanged: _toggleResultSelection,
      onSelectAllChanged: _selectAllResults,
      onClearSelection: _clearResultSelection,
      onImportTargets: _importTargetList,
      onExportTargets: _exportTargetList,
      onSaveSelectedListAndZips: _saveSelectedListAndZips,
      onDownloadSelectedRawZips: _downloadSelectedRawZips,
      onDownloadSelectedZip: _downloadSelectedZip,
      onInstallSelected: _installSelected,
      onStopSelectedFlow: _requestStopQueue,
      onDownloadZip: _downloadZip,
      onInstall: _install,
    );
  }

  Widget _buildInstalledPanel() {
    return _InstalledPanel(
      entries: _installed,
      filterController: _installedFilterController,
      filterMode: _installedFilterMode,
      directoryNameTemplate: _directoryNameTemplate,
      asciiDirectoryNames: _asciiDirectoryNames,
      gameDirectoryStatus: _gameDirectoryStatus,
      songCoreFolderEntries: _songCoreFolderEntries,
      songCoreLastBackupDirectory: _songCoreLastBackupDirectory,
      busy: _busy,
      onFilterModeChanged: (value) {
        setState(() {
          _installedFilterMode = value;
        });
      },
      onAddToTargets: _addInstalledToTargets,
      onAddFilteredToTargets: _addInstalledEntriesToTargets,
      onAddFilteredToSkip: _addInstalledEntriesToSkip,
      onExportFiltered: _exportInstalledEntries,
      onExportFilteredPlaylist: _exportInstalledEntriesPlaylist,
      onExportFavoritesPlaylist: _exportFavoritesPlaylist,
      onInspectGameDirectory: _inspectGameDirectory,
      onRefreshSongCoreFolderEntries: _refreshSongCoreFolderEntries,
      onSaveSongCoreFolderList: _saveSongCoreFolderList,
      onRemoveSongCoreFolderEntry: _removeSongCoreFolderEntry,
      onCopySongCoreFoldersFilePath: () => _copySongCorePath(
        _gameDirectoryStatus?.songCoreFoldersFile.path,
        'SongCore folders.xml 路径',
      ),
      onCopySongCoreBackupDirectory: () =>
          _copySongCorePath(_songCoreLastBackupDirectory, 'SongCore 备份目录'),
      onDelete: _deleteInstalled,
      onApplyPathCorrection: _applyInstalledPathCorrection,
      selectedPathCorrectionKeys: _selectedInstalledPathCorrectionKeys,
      onSelectedPathCorrectionKeysChanged: (keys) {
        setState(() {
          _selectedInstalledPathCorrectionKeys = keys;
        });
      },
      onApplySelectedPathCorrections: _applySelectedInstalledPathCorrections,
      selectedDuplicateKeys: _selectedInstalledDuplicateKeys,
      onSelectedDuplicateKeysChanged: (keys) {
        setState(() {
          _selectedInstalledDuplicateKeys = keys;
        });
      },
      onDeleteSelectedDuplicates: _deleteSelectedInstalledDuplicates,
    );
  }

  Widget _buildPlaylistSyncPanel() {
    return _PlaylistSyncPanel(
      entries: _playlistSyncEntries,
      localOnlyInstalledEntries: _playlistSyncLocalOnlyInstalledEntries,
      selectedEntryKeys: _selectedPlaylistSyncEntryKeys,
      filterMode: _playlistSyncFilterMode,
      tableExpanded: _playlistSyncTableExpanded,
      busy: _busy,
      onFilterModeChanged: (value) {
        setState(() {
          _playlistSyncFilterMode = value;
        });
      },
      onTableExpandedChanged: (value) {
        setState(() {
          _playlistSyncTableExpanded = value;
        });
      },
      onExport: _exportPlaylistSyncEntries,
      onExportLocalOnly: _exportInstalledEntries,
      onAddLocalOnlyToTargets: _addInstalledEntriesToTargets,
      onAddLocalOnlyToSkip: _addInstalledEntriesToSkip,
      onAddMissingToTargets: _addPlaylistSyncMissingToTargets,
      onDownloadMissingZips: _downloadPlaylistSyncMissingZips,
      onInstallMissing: _installPlaylistSyncMissing,
      onDelete: _deletePlaylistSyncEntries,
      onRemoveFromPlaylist: _removePlaylistSyncEntriesFromPlaylist,
      onEntrySelectionChanged: _togglePlaylistSyncEntrySelection,
      onSelectEntries: _selectPlaylistSyncEntries,
      onClearEntries: _clearPlaylistSyncSelection,
    );
  }

  Widget _buildZipCachePanel() {
    return ZipCachePanel(
      entries: _zipCache,
      busy: _busy,
      onRefresh: _refreshZipCache,
      onExport: _exportZipCache,
      onAddToTargets: _addZipCacheToTargets,
      onAddToSkip: _addZipCacheToSkip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beat Saber Song Toolkit v$appVersionForTest'),
        actions: [
          IconButton(
            tooltip: '捐助作者',
            onPressed: _showDonateAuthor,
            icon: const Icon(Icons.volunteer_activism),
          ),
          IconButton(
            tooltip: '帮助',
            onPressed: _showWorkspaceHelp,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: '联网检查更新：请求已配置的 release API，不会自动下载或替换程序。',
            onPressed: _busy ? null : _checkForUpdates,
            icon: const Icon(Icons.system_update_alt),
          ),
          IconButton(
            tooltip: '刷新已安装歌曲',
            onPressed: _busy ? null : _refreshInstalled,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _workspaceSelector(),
                  const SizedBox(height: 12),
                  _Controls(
                    workspace: _workspace,
                    dataSourceTabIndex: _dataSourceTabIndex,
                    queryController: _queryController,
                    libraryController: _libraryController,
                    localSongsDirectoryController:
                        _localSongsDirectoryController,
                    gameDirectoryController: _gameDirectoryController,
                    skipExistingDirectoryController:
                        _skipExistingDirectoryController,
                    downloadController: _downloadController,
                    playlistController: _playlistController,
                    onlinePlaylistController: _onlinePlaylistController,
                    playlistTitleController: _playlistTitleController,
                    playlistImageController: _playlistImageController,
                    archiveController: _archiveController,
                    profileNameController: _profileNameController,
                    directoryNameTemplateController:
                        _directoryNameTemplateController,
                    asciiDirectoryNames: _asciiDirectoryNames,
                    saveSongListEnabled: _saveSongListEnabled,
                    saveSongFilesEnabled: _saveSongFilesEnabled,
                    skipExistingMaps: _skipExistingMaps,
                    multiThreadDownload: _multiThreadDownload,
                    readLocalDataOnStartup: _readLocalDataOnStartup,
                    autoPackOnComplete: _autoPackOnComplete,
                    autoExtractOnComplete: _autoExtractOnComplete,
                    autoStartOnStartup: _autoStartOnStartup,
                    autoExitOnComplete: _autoExitOnComplete,
                    downloadMode: _downloadMode,
                    profileNames: _profileNames,
                    activeProfile: _activeProfile,
                    manualMapsController: _manualMapsController,
                    skipMapsController: _skipMapsController,
                    beastSaberUrlController: _beastSaberUrlController,
                    beastSaberStartPageController:
                        _beastSaberStartPageController,
                    scoreSaberMinStarController: _scoreSaberMinStarController,
                    scoreSaberMaxStarController: _scoreSaberMaxStarController,
                    localCacheSaverController: _localCacheSaverController,
                    localCacheStatus: _localCacheStatus,
                    hasLocalCacheDeletedAudit:
                        _hasCurrentLocalCacheDeletedAudit,
                    localCacheSnapshotProgress: _localCacheSnapshotProgress,
                    hashCacheStatus: _hashCacheStatus,
                    zipCacheEntries: _zipCache,
                    uploaderController: _uploaderController,
                    filterTextController: _filterTextController,
                    requiredComponentsController: _requiredComponentsController,
                    excludedComponentsController: _excludedComponentsController,
                    difficultyFilterController: _difficultyFilterController,
                    characteristicFilterController:
                        _characteristicFilterController,
                    includeTagsController: _includeTagsController,
                    excludeTagsController: _excludeTagsController,
                    coverTokenController: _coverTokenController,
                    coverIncludeTagsController: _coverIncludeTagsController,
                    coverExcludeTagsController: _coverExcludeTagsController,
                    coverIncludeConfidenceController:
                        _coverIncludeConfidenceController,
                    coverExcludeConfidenceController:
                        _coverExcludeConfidenceController,
                    coverLabelCacheCount: _coverLabelCache.length,
                    minDownloadsController: _minDownloadsController,
                    minPlaysController: _minPlaysController,
                    maxPlaysController: _maxPlaysController,
                    minUpvotesController: _minUpvotesController,
                    minUpvoteRatioController: _minUpvoteRatioController,
                    maxUpvoteRatioController: _maxUpvoteRatioController,
                    maxDownvotesController: _maxDownvotesController,
                    minDownvoteRatioController: _minDownvoteRatioController,
                    maxDownvoteRatioController: _maxDownvoteRatioController,
                    minScoreController: _minScoreController,
                    maxScoreController: _maxScoreController,
                    minBpmController: _minBpmController,
                    maxBpmController: _maxBpmController,
                    uploadedAfterController: _uploadedAfterController,
                    uploadedBeforeController: _uploadedBeforeController,
                    minNotesController: _minNotesController,
                    maxNotesController: _maxNotesController,
                    minBombsController: _minBombsController,
                    maxBombsController: _maxBombsController,
                    minObstaclesController: _minObstaclesController,
                    maxObstaclesController: _maxObstaclesController,
                    minMapSecondsController: _minMapSecondsController,
                    maxMapSecondsController: _maxMapSecondsController,
                    minNjsController: _minNjsController,
                    maxNjsController: _maxNjsController,
                    minNpsController: _minNpsController,
                    maxNpsController: _maxNpsController,
                    minOffsetController: _minOffsetController,
                    maxOffsetController: _maxOffsetController,
                    minEventsController: _minEventsController,
                    maxEventsController: _maxEventsController,
                    minSageScoreController: _minSageScoreController,
                    maxSageScoreController: _maxSageScoreController,
                    minStarsController: _minStarsController,
                    maxStarsController: _maxStarsController,
                    minMaxScoreController: _minMaxScoreController,
                    maxMaxScoreController: _maxMaxScoreController,
                    maxParityErrorsController: _maxParityErrorsController,
                    maxParityWarnsController: _maxParityWarnsController,
                    maxParityResetsController: _maxParityResetsController,
                    downloadLimitController: _downloadLimitController,
                    downloadRetryController: _downloadRetryController,
                    downloadTimeoutController: _downloadTimeoutController,
                    maxDownloadThreadsController: _maxDownloadThreadsController,
                    apiBaseUrlController: _apiBaseUrlController,
                    releaseApiController: _releaseApiController,
                    requestRetryController: _requestRetryController,
                    requestTimeoutController: _requestTimeoutController,
                    userAgentController: _userAgentController,
                    busy: _busy,
                    searchOrder: _searchOrder,
                    pageSize: _pageSize,
                    minRating: _minRating,
                    maxDurationSeconds: _maxDurationSeconds,
                    curatedOnly: _curatedOnly,
                    noodleOnly: _noodleOnly,
                    chromaOnly: _chromaOnly,
                    cinemaOnly: _cinemaOnly,
                    rankedOnly: _rankedOnly,
                    qualifiedOnly: _qualifiedOnly,
                    hideAi: _hideAi,
                    regexSearchMode: _regexSearchMode,
                    filterTitle: _filterTitle,
                    filterSongName: _filterSongName,
                    filterSongAuthor: _filterSongAuthor,
                    filterMapper: _filterMapper,
                    filterDescription: _filterDescription,
                    filterTags: _filterTags,
                    filterRegexMode: _filterRegexMode,
                    tagFilterEnabled: _tagFilterEnabled,
                    untaggedOnly: _untaggedOnly,
                    chinesePresetOnly: _chinesePresetOnly,
                    coverTagFilterEnabled: _coverTagFilterEnabled,
                    coverAcgPresetEnabled: _coverAcgPresetEnabled,
                    coverWaitOnFailure: _coverWaitOnFailure,
                    coverIncludeMatchAll: _coverIncludeMatchAll,
                    coverExcludeMatchAll: _coverExcludeMatchAll,
                    difficultyMatchAll: _difficultyMatchAll,
                    requireAllDifficulties: _requireAllDifficulties,
                    onSearchOrderChanged: (value) {
                      setState(() {
                        _searchOrder = value;
                      });
                    },
                    onPageSizeChanged: (value) {
                      setState(() {
                        _pageSize = value;
                        _searchPage = 0;
                      });
                    },
                    onMinRatingChanged: (value) {
                      setState(() {
                        _minRating = value;
                      });
                    },
                    onMaxDurationChanged: (value) {
                      setState(() {
                        _maxDurationSeconds = value;
                      });
                    },
                    onCuratedOnlyChanged: (value) {
                      setState(() {
                        _curatedOnly = value;
                      });
                    },
                    onNoodleOnlyChanged: (value) {
                      setState(() {
                        _noodleOnly = value;
                      });
                    },
                    onChromaOnlyChanged: (value) {
                      setState(() {
                        _chromaOnly = value;
                      });
                    },
                    onCinemaOnlyChanged: (value) {
                      setState(() {
                        _cinemaOnly = value;
                      });
                    },
                    onRankedOnlyChanged: (value) {
                      setState(() {
                        _rankedOnly = value;
                      });
                    },
                    onQualifiedOnlyChanged: (value) {
                      setState(() {
                        _qualifiedOnly = value;
                      });
                    },
                    onHideAiChanged: (value) {
                      setState(() {
                        _hideAi = value;
                      });
                    },
                    onRegexSearchModeChanged: (value) {
                      setState(() {
                        _regexSearchMode = value;
                      });
                    },
                    onFilterTitleChanged: (value) {
                      setState(() {
                        _filterTitle = value;
                      });
                    },
                    onFilterSongNameChanged: (value) {
                      setState(() {
                        _filterSongName = value;
                      });
                    },
                    onFilterSongAuthorChanged: (value) {
                      setState(() {
                        _filterSongAuthor = value;
                      });
                    },
                    onFilterMapperChanged: (value) {
                      setState(() {
                        _filterMapper = value;
                      });
                    },
                    onFilterDescriptionChanged: (value) {
                      setState(() {
                        _filterDescription = value;
                      });
                    },
                    onFilterTagsChanged: (value) {
                      setState(() {
                        _filterTags = value;
                      });
                    },
                    onFilterRegexModeChanged: (value) {
                      setState(() {
                        _filterRegexMode = value;
                      });
                    },
                    onTagFilterEnabledChanged: (value) {
                      setState(() {
                        _tagFilterEnabled = value;
                      });
                    },
                    onUntaggedOnlyChanged: (value) {
                      setState(() {
                        _untaggedOnly = value;
                      });
                    },
                    onChinesePresetOnlyChanged: (value) {
                      setState(() {
                        _chinesePresetOnly = value;
                      });
                    },
                    onCoverTagFilterEnabledChanged: (value) {
                      setState(() {
                        _coverTagFilterEnabled = value;
                      });
                    },
                    onCoverAcgPresetEnabledChanged: (value) {
                      setState(() {
                        _coverAcgPresetEnabled = value;
                      });
                    },
                    onCoverWaitOnFailureChanged: (value) {
                      setState(() {
                        _coverWaitOnFailure = value;
                      });
                    },
                    onCoverIncludeMatchAllChanged: (value) {
                      setState(() {
                        _coverIncludeMatchAll = value;
                      });
                    },
                    onCoverExcludeMatchAllChanged: (value) {
                      setState(() {
                        _coverExcludeMatchAll = value;
                      });
                    },
                    onExportCoverLabelCache: _exportCoverLabelCache,
                    onClearCoverLabelCache: _clearCoverLabelCache,
                    onRequireAllDifficultiesChanged: (value) {
                      setState(() {
                        _requireAllDifficulties = value;
                      });
                    },
                    onDifficultyMatchAllChanged: (value) {
                      setState(() {
                        _difficultyMatchAll = value;
                      });
                    },
                    onAsciiDirectoryNamesChanged: (value) {
                      setState(() {
                        _asciiDirectoryNames = value;
                      });
                    },
                    onSaveSongListEnabledChanged: (value) {
                      setState(() {
                        _saveSongListEnabled = value;
                      });
                    },
                    onSaveSongFilesEnabledChanged: (value) {
                      setState(() {
                        _saveSongFilesEnabled = value;
                      });
                    },
                    onSkipExistingMapsChanged: (value) {
                      setState(() {
                        _skipExistingMaps = value;
                      });
                    },
                    onMultiThreadDownloadChanged: (value) {
                      setState(() {
                        _multiThreadDownload = value;
                      });
                    },
                    onReadLocalDataOnStartupChanged: (value) {
                      setState(() {
                        _readLocalDataOnStartup = value;
                      });
                    },
                    onAutoPackOnCompleteChanged: (value) {
                      setState(() {
                        _autoPackOnComplete = value;
                      });
                    },
                    onAutoExtractOnCompleteChanged: (value) {
                      setState(() {
                        _autoExtractOnComplete = value;
                      });
                    },
                    onAutoStartOnStartupChanged: (value) {
                      setState(() {
                        _autoStartOnStartup = value;
                      });
                    },
                    onAutoExitOnCompleteChanged: (value) {
                      setState(() {
                        _autoExitOnComplete = value;
                      });
                    },
                    onDownloadModeChanged: (value) {
                      setState(() {
                        _downloadMode = value;
                      });
                    },
                    onApplyAcgIncludePreset: _applyAcgIncludePreset,
                    onApplyAcgExcludePreset: _applyAcgExcludePreset,
                    androidDirectoryPickerEnabled: _androidStorage.isSupported,
                    onSearch: _searchFromFirstPage,
                    onSearchUploader: _searchUploaderFromFirstPage,
                    onSearchScoreSaber: _searchScoreSaberFromFirstPage,
                    onSearchBeastSaber: _searchBeastSaberFromStartPage,
                    onReadLocalCache: _readLocalCacheFromFirstPage,
                    onPickLocalCacheSaverFile: _pickLocalCacheSaverFile,
                    onBuildLocalCacheSnapshot: () =>
                        _buildLocalCacheSnapshot(reset: true),
                    onResumeLocalCacheSnapshot: () =>
                        _buildLocalCacheSnapshot(reset: false),
                    onUpdateLocalCacheSnapshot: _updateLocalCacheSnapshot,
                    onAuditLocalCacheDeleted: _auditLocalCacheDeleted,
                    onExportLocalCacheDeletedAudit:
                        _exportLocalCacheDeletedAudit,
                    onPauseLocalCacheSnapshot: _pauseLocalCacheSnapshot,
                    onAddLocalCacheToTargets: _addLocalCacheToTargets,
                    onAddLocalCacheToSkip: _addLocalCacheToSkip,
                    onExportLocalCache: _exportLocalCacheList,
                    onExportLocalCacheSummary: _exportLocalCacheSummary,
                    onClearLocalCache: _clearLocalCacheMaps,
                    onExportHashCache: _exportHashCache,
                    onClearHashCache: _clearHashCache,
                    onRefreshZipCache: _refreshZipCache,
                    onAddZipCacheToTargets: _addZipCacheToTargets,
                    onAddZipCacheToSkip: _addZipCacheToSkip,
                    onExportZipCache: () => _exportZipCache(_zipCache),
                    onRefresh: _refreshInstalled,
                    onScanPlaylistSync: _scanPlaylistSync,
                    onExportPlaylist: _exportPlaylist,
                    onExportInstalledZip: _exportInstalledZip,
                    onImportPlaylist: _importPlaylist,
                    onImportPlaylistToTargets: _importPlaylistToTargets,
                    onImportOnlinePlaylist: _importOnlinePlaylistToTargets,
                    onSaveSettings: _saveSettings,
                    onProfileChanged: _switchProfile,
                    onDeleteProfile: _deleteCurrentProfile,
                    onAddManualMapsToResults: _addManualMapsToResults,
                    onAddManualMapsToSkip: _addManualMapsToSkip,
                    onInstallManualMaps: _installManualMaps,
                    onPickManualListFile: _pickManualListFile,
                    onImportTargets: _importTargetList,
                    onExportResultsList: _exportResultsList,
                    onPickLibraryDirectory: _pickLibraryDirectory,
                    onPickLocalSongsDirectory: _pickLocalSongsDirectory,
                    onPickGameDirectory: _pickGameDirectory,
                    onPickSkipExistingDirectory: _pickSkipExistingDirectory,
                    onPickDownloadDirectory: _pickDownloadDirectory,
                    onPickPlaylistFile: _pickPlaylistFile,
                    onPickPlaylistSaveFile: _pickPlaylistSaveFile,
                    onPickPlaylistImageFile: _pickPlaylistImageFile,
                    onPickArchiveSaveFile: _pickArchiveSaveFile,
                    onPickAndroidDirectory: _pickAndroidDirectory,
                    onClearFilters: _clearFilters,
                  ),
                  const SizedBox(height: 12),
                  Text(_status),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    if (_busyDetail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _busyDetail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  _workspaceBody(wide),
                  const SizedBox(height: 16),
                  LogPanel(
                    logs: _logs,
                    cachedLogCount: _cachedLogs.length,
                    paused: _pauseLogOutput,
                    busy: _busy,
                    onTogglePause: _toggleLogPause,
                    onExport: _exportLogs,
                    onClear: _clearLogs,
                  ),
                  const SizedBox(height: 16),
                  QueuePanel(
                    entries: _queue
                        .map(_queueEntrySnapshotForTest)
                        .toList(growable: false),
                    busy: _busy,
                    stopRequested: _stopRequested,
                    onStop: _requestStopQueue,
                    onRetryFailed: _retryFailedQueueItems,
                    onClearFinished: _clearFinishedQueueItems,
                    onClearQueue: _clearQueue,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Tooltip(
                      message: donateAuthorTooltip,
                      child: TextButton.icon(
                        onPressed: _showDonateAuthor,
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('捐助作者'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.workspace,
    required this.dataSourceTabIndex,
    required this.queryController,
    required this.libraryController,
    required this.localSongsDirectoryController,
    required this.gameDirectoryController,
    required this.skipExistingDirectoryController,
    required this.downloadController,
    required this.playlistController,
    required this.onlinePlaylistController,
    required this.playlistTitleController,
    required this.playlistImageController,
    required this.archiveController,
    required this.profileNameController,
    required this.directoryNameTemplateController,
    required this.asciiDirectoryNames,
    required this.saveSongListEnabled,
    required this.saveSongFilesEnabled,
    required this.skipExistingMaps,
    required this.multiThreadDownload,
    required this.readLocalDataOnStartup,
    required this.autoPackOnComplete,
    required this.autoExtractOnComplete,
    required this.autoStartOnStartup,
    required this.autoExitOnComplete,
    required this.downloadMode,
    required this.profileNames,
    required this.activeProfile,
    required this.manualMapsController,
    required this.skipMapsController,
    required this.beastSaberUrlController,
    required this.beastSaberStartPageController,
    required this.scoreSaberMinStarController,
    required this.scoreSaberMaxStarController,
    required this.localCacheSaverController,
    required this.localCacheStatus,
    required this.hasLocalCacheDeletedAudit,
    required this.localCacheSnapshotProgress,
    required this.hashCacheStatus,
    required this.zipCacheEntries,
    required this.uploaderController,
    required this.filterTextController,
    required this.requiredComponentsController,
    required this.excludedComponentsController,
    required this.difficultyFilterController,
    required this.characteristicFilterController,
    required this.includeTagsController,
    required this.excludeTagsController,
    required this.coverTokenController,
    required this.coverIncludeTagsController,
    required this.coverExcludeTagsController,
    required this.coverIncludeConfidenceController,
    required this.coverExcludeConfidenceController,
    required this.coverLabelCacheCount,
    required this.minDownloadsController,
    required this.minPlaysController,
    required this.maxPlaysController,
    required this.minUpvotesController,
    required this.minUpvoteRatioController,
    required this.maxUpvoteRatioController,
    required this.maxDownvotesController,
    required this.minDownvoteRatioController,
    required this.maxDownvoteRatioController,
    required this.minScoreController,
    required this.maxScoreController,
    required this.minBpmController,
    required this.maxBpmController,
    required this.uploadedAfterController,
    required this.uploadedBeforeController,
    required this.minNotesController,
    required this.maxNotesController,
    required this.minBombsController,
    required this.maxBombsController,
    required this.minObstaclesController,
    required this.maxObstaclesController,
    required this.minMapSecondsController,
    required this.maxMapSecondsController,
    required this.minNjsController,
    required this.maxNjsController,
    required this.minNpsController,
    required this.maxNpsController,
    required this.minOffsetController,
    required this.maxOffsetController,
    required this.minEventsController,
    required this.maxEventsController,
    required this.minSageScoreController,
    required this.maxSageScoreController,
    required this.minStarsController,
    required this.maxStarsController,
    required this.minMaxScoreController,
    required this.maxMaxScoreController,
    required this.maxParityErrorsController,
    required this.maxParityWarnsController,
    required this.maxParityResetsController,
    required this.downloadLimitController,
    required this.downloadRetryController,
    required this.downloadTimeoutController,
    required this.maxDownloadThreadsController,
    required this.apiBaseUrlController,
    required this.releaseApiController,
    required this.requestRetryController,
    required this.requestTimeoutController,
    required this.userAgentController,
    required this.busy,
    required this.searchOrder,
    required this.pageSize,
    required this.minRating,
    required this.maxDurationSeconds,
    required this.curatedOnly,
    required this.noodleOnly,
    required this.chromaOnly,
    required this.cinemaOnly,
    required this.rankedOnly,
    required this.qualifiedOnly,
    required this.hideAi,
    required this.regexSearchMode,
    required this.filterTitle,
    required this.filterSongName,
    required this.filterSongAuthor,
    required this.filterMapper,
    required this.filterDescription,
    required this.filterTags,
    required this.filterRegexMode,
    required this.tagFilterEnabled,
    required this.untaggedOnly,
    required this.chinesePresetOnly,
    required this.coverTagFilterEnabled,
    required this.coverAcgPresetEnabled,
    required this.coverWaitOnFailure,
    required this.coverIncludeMatchAll,
    required this.coverExcludeMatchAll,
    required this.difficultyMatchAll,
    required this.requireAllDifficulties,
    required this.onSearchOrderChanged,
    required this.onPageSizeChanged,
    required this.onMinRatingChanged,
    required this.onMaxDurationChanged,
    required this.onCuratedOnlyChanged,
    required this.onNoodleOnlyChanged,
    required this.onChromaOnlyChanged,
    required this.onCinemaOnlyChanged,
    required this.onRankedOnlyChanged,
    required this.onQualifiedOnlyChanged,
    required this.onHideAiChanged,
    required this.onRegexSearchModeChanged,
    required this.onFilterTitleChanged,
    required this.onFilterSongNameChanged,
    required this.onFilterSongAuthorChanged,
    required this.onFilterMapperChanged,
    required this.onFilterDescriptionChanged,
    required this.onFilterTagsChanged,
    required this.onFilterRegexModeChanged,
    required this.onTagFilterEnabledChanged,
    required this.onUntaggedOnlyChanged,
    required this.onChinesePresetOnlyChanged,
    required this.onCoverTagFilterEnabledChanged,
    required this.onCoverAcgPresetEnabledChanged,
    required this.onCoverWaitOnFailureChanged,
    required this.onCoverIncludeMatchAllChanged,
    required this.onCoverExcludeMatchAllChanged,
    required this.onExportCoverLabelCache,
    required this.onClearCoverLabelCache,
    required this.onRequireAllDifficultiesChanged,
    required this.onDifficultyMatchAllChanged,
    required this.onAsciiDirectoryNamesChanged,
    required this.onSaveSongListEnabledChanged,
    required this.onSaveSongFilesEnabledChanged,
    required this.onSkipExistingMapsChanged,
    required this.onMultiThreadDownloadChanged,
    required this.onReadLocalDataOnStartupChanged,
    required this.onAutoPackOnCompleteChanged,
    required this.onAutoExtractOnCompleteChanged,
    required this.onAutoStartOnStartupChanged,
    required this.onAutoExitOnCompleteChanged,
    required this.onDownloadModeChanged,
    required this.onApplyAcgIncludePreset,
    required this.onApplyAcgExcludePreset,
    required this.androidDirectoryPickerEnabled,
    required this.onSearch,
    required this.onSearchUploader,
    required this.onSearchScoreSaber,
    required this.onSearchBeastSaber,
    required this.onReadLocalCache,
    required this.onPickLocalCacheSaverFile,
    required this.onBuildLocalCacheSnapshot,
    required this.onResumeLocalCacheSnapshot,
    required this.onUpdateLocalCacheSnapshot,
    required this.onAuditLocalCacheDeleted,
    required this.onExportLocalCacheDeletedAudit,
    required this.onPauseLocalCacheSnapshot,
    required this.onAddLocalCacheToTargets,
    required this.onAddLocalCacheToSkip,
    required this.onExportLocalCache,
    required this.onExportLocalCacheSummary,
    required this.onClearLocalCache,
    required this.onExportHashCache,
    required this.onClearHashCache,
    required this.onRefreshZipCache,
    required this.onAddZipCacheToTargets,
    required this.onAddZipCacheToSkip,
    required this.onExportZipCache,
    required this.onRefresh,
    required this.onScanPlaylistSync,
    required this.onExportPlaylist,
    required this.onExportInstalledZip,
    required this.onImportPlaylist,
    required this.onImportPlaylistToTargets,
    required this.onImportOnlinePlaylist,
    required this.onSaveSettings,
    required this.onProfileChanged,
    required this.onDeleteProfile,
    required this.onAddManualMapsToResults,
    required this.onAddManualMapsToSkip,
    required this.onInstallManualMaps,
    required this.onPickManualListFile,
    required this.onImportTargets,
    required this.onExportResultsList,
    required this.onPickLibraryDirectory,
    required this.onPickLocalSongsDirectory,
    required this.onPickGameDirectory,
    required this.onPickSkipExistingDirectory,
    required this.onPickDownloadDirectory,
    required this.onPickPlaylistFile,
    required this.onPickPlaylistSaveFile,
    required this.onPickPlaylistImageFile,
    required this.onPickArchiveSaveFile,
    required this.onPickAndroidDirectory,
    required this.onClearFilters,
  });

  final _Workspace workspace;
  final int dataSourceTabIndex;
  final TextEditingController queryController;
  final TextEditingController libraryController;
  final TextEditingController localSongsDirectoryController;
  final TextEditingController gameDirectoryController;
  final TextEditingController skipExistingDirectoryController;
  final TextEditingController downloadController;
  final TextEditingController playlistController;
  final TextEditingController onlinePlaylistController;
  final TextEditingController playlistTitleController;
  final TextEditingController playlistImageController;
  final TextEditingController archiveController;
  final TextEditingController profileNameController;
  final TextEditingController directoryNameTemplateController;
  final bool asciiDirectoryNames;
  final bool saveSongListEnabled;
  final bool saveSongFilesEnabled;
  final bool skipExistingMaps;
  final bool multiThreadDownload;
  final bool readLocalDataOnStartup;
  final bool autoPackOnComplete;
  final bool autoExtractOnComplete;
  final bool autoStartOnStartup;
  final bool autoExitOnComplete;
  final _DownloadMode downloadMode;
  final List<String> profileNames;
  final String activeProfile;
  final TextEditingController manualMapsController;
  final TextEditingController skipMapsController;
  final TextEditingController beastSaberUrlController;
  final TextEditingController beastSaberStartPageController;
  final TextEditingController scoreSaberMinStarController;
  final TextEditingController scoreSaberMaxStarController;
  final TextEditingController localCacheSaverController;
  final _LocalCacheStatus? localCacheStatus;
  final bool hasLocalCacheDeletedAudit;
  final LocalCacheSnapshotProgress? localCacheSnapshotProgress;
  final _HashCacheStatus? hashCacheStatus;
  final List<ZipCacheEntryUiModel> zipCacheEntries;
  final TextEditingController uploaderController;
  final TextEditingController filterTextController;
  final TextEditingController requiredComponentsController;
  final TextEditingController excludedComponentsController;
  final TextEditingController difficultyFilterController;
  final TextEditingController characteristicFilterController;
  final TextEditingController includeTagsController;
  final TextEditingController excludeTagsController;
  final TextEditingController coverTokenController;
  final TextEditingController coverIncludeTagsController;
  final TextEditingController coverExcludeTagsController;
  final TextEditingController coverIncludeConfidenceController;
  final TextEditingController coverExcludeConfidenceController;
  final int coverLabelCacheCount;
  final TextEditingController minDownloadsController;
  final TextEditingController minPlaysController;
  final TextEditingController maxPlaysController;
  final TextEditingController minUpvotesController;
  final TextEditingController minUpvoteRatioController;
  final TextEditingController maxUpvoteRatioController;
  final TextEditingController maxDownvotesController;
  final TextEditingController minDownvoteRatioController;
  final TextEditingController maxDownvoteRatioController;
  final TextEditingController minScoreController;
  final TextEditingController maxScoreController;
  final TextEditingController minBpmController;
  final TextEditingController maxBpmController;
  final TextEditingController uploadedAfterController;
  final TextEditingController uploadedBeforeController;
  final TextEditingController minNotesController;
  final TextEditingController maxNotesController;
  final TextEditingController minBombsController;
  final TextEditingController maxBombsController;
  final TextEditingController minObstaclesController;
  final TextEditingController maxObstaclesController;
  final TextEditingController minMapSecondsController;
  final TextEditingController maxMapSecondsController;
  final TextEditingController minNjsController;
  final TextEditingController maxNjsController;
  final TextEditingController minNpsController;
  final TextEditingController maxNpsController;
  final TextEditingController minOffsetController;
  final TextEditingController maxOffsetController;
  final TextEditingController minEventsController;
  final TextEditingController maxEventsController;
  final TextEditingController minSageScoreController;
  final TextEditingController maxSageScoreController;
  final TextEditingController minStarsController;
  final TextEditingController maxStarsController;
  final TextEditingController minMaxScoreController;
  final TextEditingController maxMaxScoreController;
  final TextEditingController maxParityErrorsController;
  final TextEditingController maxParityWarnsController;
  final TextEditingController maxParityResetsController;
  final TextEditingController downloadLimitController;
  final TextEditingController downloadRetryController;
  final TextEditingController downloadTimeoutController;
  final TextEditingController maxDownloadThreadsController;
  final TextEditingController apiBaseUrlController;
  final TextEditingController releaseApiController;
  final TextEditingController requestRetryController;
  final TextEditingController requestTimeoutController;
  final TextEditingController userAgentController;
  final bool busy;
  final BeatSaverSearchOrder searchOrder;
  final int pageSize;
  final double minRating;
  final int maxDurationSeconds;
  final bool curatedOnly;
  final bool noodleOnly;
  final bool chromaOnly;
  final bool cinemaOnly;
  final bool rankedOnly;
  final bool qualifiedOnly;
  final bool hideAi;
  final bool regexSearchMode;
  final bool filterTitle;
  final bool filterSongName;
  final bool filterSongAuthor;
  final bool filterMapper;
  final bool filterDescription;
  final bool filterTags;
  final bool filterRegexMode;
  final bool tagFilterEnabled;
  final bool untaggedOnly;
  final bool chinesePresetOnly;
  final bool coverTagFilterEnabled;
  final bool coverAcgPresetEnabled;
  final bool coverWaitOnFailure;
  final bool coverIncludeMatchAll;
  final bool coverExcludeMatchAll;
  final bool difficultyMatchAll;
  final bool requireAllDifficulties;
  final ValueChanged<BeatSaverSearchOrder> onSearchOrderChanged;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<double> onMinRatingChanged;
  final ValueChanged<int> onMaxDurationChanged;
  final ValueChanged<bool> onCuratedOnlyChanged;
  final ValueChanged<bool> onNoodleOnlyChanged;
  final ValueChanged<bool> onChromaOnlyChanged;
  final ValueChanged<bool> onCinemaOnlyChanged;
  final ValueChanged<bool> onRankedOnlyChanged;
  final ValueChanged<bool> onQualifiedOnlyChanged;
  final ValueChanged<bool> onHideAiChanged;
  final ValueChanged<bool> onRegexSearchModeChanged;
  final ValueChanged<bool> onFilterTitleChanged;
  final ValueChanged<bool> onFilterSongNameChanged;
  final ValueChanged<bool> onFilterSongAuthorChanged;
  final ValueChanged<bool> onFilterMapperChanged;
  final ValueChanged<bool> onFilterDescriptionChanged;
  final ValueChanged<bool> onFilterTagsChanged;
  final ValueChanged<bool> onFilterRegexModeChanged;
  final ValueChanged<bool> onTagFilterEnabledChanged;
  final ValueChanged<bool> onUntaggedOnlyChanged;
  final ValueChanged<bool> onChinesePresetOnlyChanged;
  final ValueChanged<bool> onCoverTagFilterEnabledChanged;
  final ValueChanged<bool> onCoverAcgPresetEnabledChanged;
  final ValueChanged<bool> onCoverWaitOnFailureChanged;
  final ValueChanged<bool> onCoverIncludeMatchAllChanged;
  final ValueChanged<bool> onCoverExcludeMatchAllChanged;
  final VoidCallback onExportCoverLabelCache;
  final VoidCallback onClearCoverLabelCache;
  final ValueChanged<bool> onRequireAllDifficultiesChanged;
  final ValueChanged<bool> onDifficultyMatchAllChanged;
  final ValueChanged<bool> onAsciiDirectoryNamesChanged;
  final ValueChanged<bool> onSaveSongListEnabledChanged;
  final ValueChanged<bool> onSaveSongFilesEnabledChanged;
  final ValueChanged<bool> onSkipExistingMapsChanged;
  final ValueChanged<bool> onMultiThreadDownloadChanged;
  final ValueChanged<bool> onReadLocalDataOnStartupChanged;
  final ValueChanged<bool> onAutoPackOnCompleteChanged;
  final ValueChanged<bool> onAutoExtractOnCompleteChanged;
  final ValueChanged<bool> onAutoStartOnStartupChanged;
  final ValueChanged<bool> onAutoExitOnCompleteChanged;
  final ValueChanged<_DownloadMode> onDownloadModeChanged;
  final VoidCallback onApplyAcgIncludePreset;
  final VoidCallback onApplyAcgExcludePreset;
  final bool androidDirectoryPickerEnabled;
  final VoidCallback onSearch;
  final VoidCallback onSearchUploader;
  final VoidCallback onSearchScoreSaber;
  final VoidCallback onSearchBeastSaber;
  final VoidCallback onReadLocalCache;
  final VoidCallback onPickLocalCacheSaverFile;
  final VoidCallback onBuildLocalCacheSnapshot;
  final VoidCallback onResumeLocalCacheSnapshot;
  final VoidCallback onUpdateLocalCacheSnapshot;
  final VoidCallback onAuditLocalCacheDeleted;
  final VoidCallback onExportLocalCacheDeletedAudit;
  final VoidCallback onPauseLocalCacheSnapshot;
  final VoidCallback onAddLocalCacheToTargets;
  final VoidCallback onAddLocalCacheToSkip;
  final VoidCallback onExportLocalCache;
  final VoidCallback onExportLocalCacheSummary;
  final VoidCallback onClearLocalCache;
  final VoidCallback onExportHashCache;
  final VoidCallback onClearHashCache;
  final VoidCallback onRefreshZipCache;
  final Future<void> Function(List<ZipCacheEntryUiModel> entries)
  onAddZipCacheToTargets;
  final ValueChanged<List<ZipCacheEntryUiModel>> onAddZipCacheToSkip;
  final VoidCallback onExportZipCache;
  final VoidCallback onRefresh;
  final VoidCallback onScanPlaylistSync;
  final VoidCallback onExportPlaylist;
  final VoidCallback onExportInstalledZip;
  final VoidCallback onImportPlaylist;
  final VoidCallback onImportPlaylistToTargets;
  final VoidCallback onImportOnlinePlaylist;
  final VoidCallback onSaveSettings;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onDeleteProfile;
  final VoidCallback onAddManualMapsToResults;
  final VoidCallback onAddManualMapsToSkip;
  final VoidCallback onInstallManualMaps;
  final VoidCallback onPickManualListFile;
  final VoidCallback onImportTargets;
  final VoidCallback onExportResultsList;
  final VoidCallback onPickLibraryDirectory;
  final VoidCallback onPickLocalSongsDirectory;
  final VoidCallback onPickGameDirectory;
  final VoidCallback onPickSkipExistingDirectory;
  final VoidCallback onPickDownloadDirectory;
  final VoidCallback onPickPlaylistFile;
  final VoidCallback onPickPlaylistSaveFile;
  final VoidCallback onPickPlaylistImageFile;
  final VoidCallback onPickArchiveSaveFile;
  final VoidCallback onPickAndroidDirectory;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final searchWorkspace = workspace == _Workspace.search;
    final libraryWorkspace = workspace == _Workspace.library;
    final playlistSyncWorkspace = workspace == _Workspace.playlistSync;
    final workspaceScanAction = playlistSyncWorkspace
        ? onScanPlaylistSync
        : onRefresh;
    final workspaceScanLabel = playlistSyncWorkspace ? '扫描歌单同步' : '扫描曲库';
    final workspaceScanIcon = playlistSyncWorkspace
        ? Icons.compare_arrows
        : Icons.library_music;
    final workspaceScanTooltip = playlistSyncWorkspace
        ? '读取当前 .bplist 歌单和安装目录，生成一一对比结果。'
        : '扫描安装目录，刷新本地曲库歌曲列表。';
    final pathSummaryLabels = <String>[
      '目录',
      if (searchWorkspace) ...[
        '配置',
        '保存方式',
        '歌单',
        'ZIP/命名',
        '下载/API',
        '完成后',
      ] else if (libraryWorkspace) ...[
        '歌单',
        '命名',
      ] else if (playlistSyncWorkspace) ...[
        '歌单',
      ],
    ];
    final pathPanel = _ControlGroup(
      title: searchWorkspace ? '路径与保存方式' : '共享路径配置',
      initiallyExpanded: !searchWorkspace,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (searchWorkspace) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pathSummaryLabels
                  .map((label) => _PathSummaryLabel(text: label))
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (searchWorkspace) ...[
                const _PathGroupHeader(text: '配置'),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: profileNameController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '配置名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: activeProfile.isEmpty ? null : activeProfile,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '已保存配置',
                      border: OutlineInputBorder(),
                    ),
                    items: profileNames
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (name) {
                            if (name != null) {
                              onProfileChanged(name);
                            }
                          },
                  ),
                ),
                Tooltip(
                  message: profileSaveTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onSaveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('保存配置'),
                  ),
                ),
                Tooltip(
                  message: profileDeleteTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onDeleteProfile,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除配置'),
                  ),
                ),
              ],
              const _PathGroupHeader(text: '目录'),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: libraryController,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: '安装目录',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Tooltip(
                message: pickInstallDirectoryTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPickLibraryDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('浏览安装目录'),
                ),
              ),
              if (!playlistSyncWorkspace) ...[
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: localSongsDirectoryController,
                    enabled: !busy,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '本地歌曲目录',
                      hintText: '可用换行或分号分隔多个目录',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Tooltip(
                  message: pickLocalSongsDirectoryTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPickLocalSongsDirectory,
                    icon: const Icon(Icons.folder_copy),
                    label: const Text('浏览本地歌曲'),
                  ),
                ),
              ],
              if (searchWorkspace) ...[
                SizedBox(
                  width: 140,
                  child: CheckboxListTile(
                    value: skipExistingMaps,
                    onChanged: busy
                        ? null
                        : (value) => onSkipExistingMapsChanged(value ?? false),
                    title: const Text('跳过已有'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: skipExistingDirectoryController,
                    enabled: !busy && skipExistingMaps,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '跳过已有目录',
                      hintText: '可用换行或分号分隔多个目录',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Tooltip(
                  message: pickSkipExistingDirectoryTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPickSkipExistingDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('浏览跳过目录'),
                  ),
                ),
              ],
              Tooltip(
                message: workspaceScanTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onRefresh,
                  icon: const Icon(Icons.library_music),
                  label: const Text('扫描'),
                ),
              ),
              Tooltip(
                message: androidDirectoryTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy || !androidDirectoryPickerEnabled
                      ? null
                      : onPickAndroidDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Android 目录'),
                ),
              ),
              if (searchWorkspace) ...[
                const _PathGroupHeader(text: '保存方式'),
                SizedBox(
                  width: 140,
                  child: CheckboxListTile(
                    value: saveSongFilesEnabled,
                    onChanged: busy
                        ? null
                        : (value) =>
                              onSaveSongFilesEnabledChanged(value ?? false),
                    title: const Text('下载歌曲'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: downloadController,
                    enabled: !busy && saveSongFilesEnabled,
                    decoration: const InputDecoration(
                      labelText: 'ZIP 下载目录',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Tooltip(
                  message: pickZipDownloadDirectoryTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPickDownloadDirectory,
                    icon: const Icon(Icons.folder_zip),
                    label: const Text('浏览 ZIP 目录'),
                  ),
                ),
              ],
              _PathGroupHeader(text: playlistSyncWorkspace ? '歌单' : '歌单/封面'),
              if (searchWorkspace)
                SizedBox(
                  width: 140,
                  child: CheckboxListTile(
                    value: saveSongListEnabled,
                    onChanged: busy
                        ? null
                        : (value) =>
                              onSaveSongListEnabledChanged(value ?? false),
                    title: const Text('歌曲列表'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: playlistController,
                  enabled: !busy && (!searchWorkspace || saveSongListEnabled),
                  decoration: const InputDecoration(
                    labelText: '歌单路径',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Tooltip(
                message: pickPlaylistFileTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPickPlaylistFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('选择歌单'),
                ),
              ),
              Tooltip(
                message: pickPlaylistSaveTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPickPlaylistSaveFile,
                  icon: const Icon(Icons.save_as),
                  label: const Text('保存到'),
                ),
              ),
              if (searchWorkspace) ...[
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: playlistTitleController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '歌单标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: playlistImageController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '歌单封面',
                      hintText: 'jpg/png/bmp/gif，本地文件',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Tooltip(
                  message: pickPlaylistCoverTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPickPlaylistImageFile,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('选择封面'),
                  ),
                ),
              ],
              if (searchWorkspace) ...[
                Tooltip(
                  message: exportPlaylistTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onExportPlaylist,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('导出歌单'),
                  ),
                ),
                Tooltip(
                  message: installPlaylistTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onImportPlaylist,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('安装歌单'),
                  ),
                ),
                Tooltip(
                  message: playlistToTargetsTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onImportPlaylistToTargets,
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('歌单入本次'),
                  ),
                ),
              ],
              if (!playlistSyncWorkspace) ...[
                _PathGroupHeader(text: searchWorkspace ? 'ZIP/命名' : '命名'),
                if (searchWorkspace)
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: archiveController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: '歌曲 ZIP 路径',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: directoryNameTemplateController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '命名方式',
                      hintText: '[id] - [歌名]',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
              if (searchWorkspace) ...[
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<_DownloadMode>(
                    initialValue: downloadMode,
                    decoration: const InputDecoration(
                      labelText: '下载方式',
                      border: OutlineInputBorder(),
                    ),
                    items: _DownloadMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(_downloadModeLabel(mode)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value != null) {
                              onDownloadModeChanged(value);
                            }
                          },
                  ),
                ),
                Tooltip(
                  message: pickArchiveSaveTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPickArchiveSaveFile,
                    icon: const Icon(Icons.save_as),
                    label: const Text('ZIP 保存到'),
                  ),
                ),
                Tooltip(
                  message: exportInstalledZipTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onExportInstalledZip,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('打包 ZIP'),
                  ),
                ),
                const _PathGroupHeader(text: '下载/API'),
                _CompactTextField(
                  controller: apiBaseUrlController,
                  enabled: !busy,
                  width: 220,
                  label: 'SaverAPI',
                  hintText: 'https://api.beatsaver.com',
                  onSubmitted: onSearch,
                ),
                _CompactTextField(
                  controller: releaseApiController,
                  enabled: !busy,
                  width: 260,
                  label: '更新API',
                  hintText: 'GitHub latest release API',
                  onSubmitted: onSearch,
                ),
                _CompactNumberField(
                  controller: requestRetryController,
                  enabled: !busy,
                  label: '访问重试',
                  onSubmitted: onSearch,
                ),
                _CompactNumberField(
                  controller: requestTimeoutController,
                  enabled: !busy,
                  label: '访问超时',
                  onSubmitted: onSearch,
                ),
                _CompactTextField(
                  controller: userAgentController,
                  enabled: !busy,
                  width: 180,
                  label: 'UA标签',
                  hintText: 'Beat Saber Song Toolkit',
                  onSubmitted: onSearch,
                ),
                _CompactNumberField(
                  controller: downloadRetryController,
                  enabled: !busy,
                  label: '重试次数',
                  onSubmitted: onSearch,
                ),
                _CompactNumberField(
                  controller: downloadTimeoutController,
                  enabled: !busy,
                  label: '超时秒数',
                  onSubmitted: onSearch,
                ),
                SizedBox(
                  width: 140,
                  child: CheckboxListTile(
                    value: multiThreadDownload,
                    onChanged: busy
                        ? null
                        : (value) =>
                              onMultiThreadDownloadChanged(value ?? false),
                    title: const Text('多线程'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                _CompactNumberField(
                  controller: maxDownloadThreadsController,
                  enabled: !busy && multiThreadDownload,
                  label: '线程数',
                  onSubmitted: onSearch,
                ),
              ],
              if (searchWorkspace)
                SizedBox(
                  width: 120,
                  child: CheckboxListTile(
                    value: asciiDirectoryNames,
                    onChanged: busy
                        ? null
                        : (value) =>
                              onAsciiDirectoryNamesChanged(value ?? false),
                    title: const Text('英文'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (searchWorkspace) ...[
                const _PathGroupHeader(text: '完成后'),
                SizedBox(
                  width: 140,
                  child: Tooltip(
                    message: readLocalDataOnStartupTooltip,
                    child: CheckboxListTile(
                      value: readLocalDataOnStartup,
                      onChanged: busy
                          ? null
                          : (value) =>
                                onReadLocalDataOnStartupChanged(value ?? false),
                      title: const Text('读入本地'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Tooltip(
                    message: autoStartOnStartupTooltip,
                    child: CheckboxListTile(
                      value: autoStartOnStartup,
                      onChanged: busy
                          ? null
                          : (value) =>
                                onAutoStartOnStartupChanged(value ?? false),
                      title: const Text('自动开始'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Tooltip(
                    message: autoPackOnCompleteTooltip,
                    child: CheckboxListTile(
                      value: autoPackOnComplete,
                      onChanged: busy
                          ? null
                          : (value) =>
                                onAutoPackOnCompleteChanged(value ?? false),
                      title: const Text('自动打包'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Tooltip(
                    message: autoExtractOnCompleteTooltip,
                    child: CheckboxListTile(
                      value: autoExtractOnComplete,
                      onChanged: busy
                          ? null
                          : (value) =>
                                onAutoExtractOnCompleteChanged(value ?? false),
                      title: const Text('自动解压'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Tooltip(
                    message: autoExitOnCompleteTooltip,
                    child: CheckboxListTile(
                      value: autoExitOnComplete,
                      onChanged: busy
                          ? null
                          : (value) =>
                                onAutoExitOnCompleteChanged(value ?? false),
                      title: const Text('自动退出'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    final workspacePathToolbar = _WorkspacePathToolbar(
      title: libraryWorkspace ? '本地曲库' : '歌单同步',
      children: [
        _CompactTextField(
          controller: libraryController,
          enabled: !busy,
          width: 300,
          label: '安装目录',
          hintText: '',
          onSubmitted: workspaceScanAction,
        ),
        Tooltip(
          message: pickInstallDirectoryTooltip,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onPickLibraryDirectory,
            icon: const Icon(Icons.folder_open),
            label: const Text('安装目录'),
          ),
        ),
        if (libraryWorkspace) ...[
          _CompactTextField(
            controller: localSongsDirectoryController,
            enabled: !busy,
            width: 300,
            label: '本地歌曲目录',
            hintText: '多个目录用换行或分号分隔',
            onSubmitted: onRefresh,
          ),
          Tooltip(
            message: pickLocalSongsDirectoryTooltip,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickLocalSongsDirectory,
              icon: const Icon(Icons.folder_copy),
              label: const Text('歌曲目录'),
            ),
          ),
          _CompactTextField(
            controller: gameDirectoryController,
            enabled: !busy,
            width: 300,
            label: '游戏目录',
            hintText: 'Beat Saber 根目录',
            onSubmitted: onRefresh,
          ),
          Tooltip(
            message: pickGameDirectoryTooltip,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickGameDirectory,
              icon: const Icon(Icons.sports_esports),
              label: const Text('游戏目录'),
            ),
          ),
        ],
        _CompactTextField(
          controller: playlistController,
          enabled: !busy,
          width: 300,
          label: '歌单路径',
          hintText: '',
          onSubmitted: playlistSyncWorkspace ? onScanPlaylistSync : onRefresh,
        ),
        Tooltip(
          message: pickPlaylistFileTooltip,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onPickPlaylistFile,
            icon: const Icon(Icons.file_open),
            label: const Text('选择歌单'),
          ),
        ),
        if (libraryWorkspace) ...[
          _CompactTextField(
            controller: directoryNameTemplateController,
            enabled: !busy,
            width: 240,
            label: '命名方式',
            hintText: '[id] - [歌名]',
            onSubmitted: onRefresh,
          ),
        ],
        Tooltip(
          message: workspaceScanTooltip,
          child: OutlinedButton.icon(
            onPressed: busy ? null : workspaceScanAction,
            icon: Icon(workspaceScanIcon),
            label: Text(workspaceScanLabel),
          ),
        ),
      ],
    );

    final dataSourcePanel = _ControlGroup(
      title: '数据源',
      initiallyExpanded: true,
      child: _DataSourceTabs(
        initialTabIndex: dataSourceTabIndex,
        queryController: queryController,
        uploaderController: uploaderController,
        beastSaberUrlController: beastSaberUrlController,
        beastSaberStartPageController: beastSaberStartPageController,
        scoreSaberMinStarController: scoreSaberMinStarController,
        scoreSaberMaxStarController: scoreSaberMaxStarController,
        localCacheSaverController: localCacheSaverController,
        localCacheStatus: localCacheStatus,
        hasLocalCacheDeletedAudit: hasLocalCacheDeletedAudit,
        localCacheSnapshotProgress: localCacheSnapshotProgress,
        hashCacheStatus: hashCacheStatus,
        zipCacheEntries: zipCacheEntries,
        onlinePlaylistController: onlinePlaylistController,
        manualMapsController: manualMapsController,
        skipMapsController: skipMapsController,
        busy: busy,
        searchOrder: searchOrder,
        pageSize: pageSize,
        regexSearchMode: regexSearchMode,
        onSearch: onSearch,
        onSearchUploader: onSearchUploader,
        onSearchScoreSaber: onSearchScoreSaber,
        onSearchBeastSaber: onSearchBeastSaber,
        onReadLocalCache: onReadLocalCache,
        onPickLocalCacheSaverFile: onPickLocalCacheSaverFile,
        onBuildLocalCacheSnapshot: onBuildLocalCacheSnapshot,
        onResumeLocalCacheSnapshot: onResumeLocalCacheSnapshot,
        onUpdateLocalCacheSnapshot: onUpdateLocalCacheSnapshot,
        onAuditLocalCacheDeleted: onAuditLocalCacheDeleted,
        onExportLocalCacheDeletedAudit: onExportLocalCacheDeletedAudit,
        onPauseLocalCacheSnapshot: onPauseLocalCacheSnapshot,
        onAddLocalCacheToTargets: onAddLocalCacheToTargets,
        onAddLocalCacheToSkip: onAddLocalCacheToSkip,
        onExportLocalCache: onExportLocalCache,
        onExportLocalCacheSummary: onExportLocalCacheSummary,
        onClearLocalCache: onClearLocalCache,
        onExportHashCache: onExportHashCache,
        onClearHashCache: onClearHashCache,
        onRefreshZipCache: onRefreshZipCache,
        onAddZipCacheToTargets: onAddZipCacheToTargets,
        onAddZipCacheToSkip: onAddZipCacheToSkip,
        onExportZipCache: onExportZipCache,
        onImportOnlinePlaylist: onImportOnlinePlaylist,
        onSearchOrderChanged: onSearchOrderChanged,
        onPageSizeChanged: onPageSizeChanged,
        onRegexSearchModeChanged: onRegexSearchModeChanged,
        onClearFilters: onClearFilters,
        onAddManualMapsToResults: onAddManualMapsToResults,
        onAddManualMapsToSkip: onAddManualMapsToSkip,
        onInstallManualMaps: onInstallManualMaps,
        onPickManualListFile: onPickManualListFile,
        onImportTargets: onImportTargets,
        onExportResultsList: onExportResultsList,
      ),
    );

    final filterPanel = _ControlGroup(
      title: '高级筛选',
      initiallyExpanded: true,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _InlineLabeledField(
            label: '搜索过滤',
            width: 360,
            child: TextField(
              controller: filterTextController,
              enabled: !busy,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          _CompactCheckItem(
            label: '标题',
            selected: filterTitle,
            onChanged: busy ? null : onFilterTitleChanged,
          ),
          _CompactCheckItem(
            label: '歌名',
            selected: filterSongName,
            onChanged: busy ? null : onFilterSongNameChanged,
          ),
          _CompactCheckItem(
            label: '作者',
            selected: filterSongAuthor,
            onChanged: busy ? null : onFilterSongAuthorChanged,
          ),
          _CompactCheckItem(
            label: '谱师',
            selected: filterMapper,
            onChanged: busy ? null : onFilterMapperChanged,
          ),
          _CompactCheckItem(
            label: '介绍',
            selected: filterDescription,
            onChanged: busy ? null : onFilterDescriptionChanged,
          ),
          _CompactCheckItem(
            label: '分类',
            selected: filterTags,
            onChanged: busy ? null : onFilterTagsChanged,
          ),
          _CompactCheckItem(
            label: '过滤正则',
            selected: filterRegexMode,
            onChanged: busy ? null : onFilterRegexModeChanged,
          ),
          _CompactNumberField(
            controller: downloadLimitController,
            enabled: !busy,
            label: '限制数量',
            onSubmitted: onSearch,
          ),
          _InlineLabeledField(
            label: '最低评分',
            width: 220,
            child: DropdownButtonFormField<double>(
              initialValue: minRating,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('不限')),
                DropdownMenuItem(value: 0.6, child: Text('0.60+')),
                DropdownMenuItem(value: 0.7, child: Text('0.70+')),
                DropdownMenuItem(value: 0.8, child: Text('0.80+')),
                DropdownMenuItem(value: 0.9, child: Text('0.90+')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        onMinRatingChanged(value);
                      }
                    },
            ),
          ),
          _InlineLabeledField(
            label: '最长时长',
            width: 220,
            child: DropdownButtonFormField<int>(
              initialValue: maxDurationSeconds,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text('不限')),
                DropdownMenuItem(value: 120, child: Text('2 分钟')),
                DropdownMenuItem(value: 180, child: Text('3 分钟')),
                DropdownMenuItem(value: 240, child: Text('4 分钟')),
                DropdownMenuItem(value: 300, child: Text('5 分钟')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        onMaxDurationChanged(value);
                      }
                    },
            ),
          ),
          _CompactCheckItem(
            label: '精选',
            selected: curatedOnly,
            onChanged: busy ? null : onCuratedOnlyChanged,
          ),
          _CompactCheckItem(
            label: 'Noodle',
            selected: noodleOnly,
            onChanged: busy ? null : onNoodleOnlyChanged,
          ),
          _CompactCheckItem(
            label: 'Chroma',
            selected: chromaOnly,
            onChanged: busy ? null : onChromaOnlyChanged,
          ),
          _CompactCheckItem(
            label: 'Cinema',
            selected: cinemaOnly,
            onChanged: busy ? null : onCinemaOnlyChanged,
          ),
          _CompactCheckItem(
            label: 'Ranked',
            selected: rankedOnly,
            onChanged: busy ? null : onRankedOnlyChanged,
          ),
          _CompactCheckItem(
            label: 'Qualified',
            selected: qualifiedOnly,
            onChanged: busy ? null : onQualifiedOnlyChanged,
          ),
          _CompactCheckItem(
            label: '隐藏 AI 谱',
            selected: hideAi,
            onChanged: busy ? null : onHideAiChanged,
          ),
          _CompactCheckItem(
            label: '标签过滤',
            selected: tagFilterEnabled,
            onChanged: busy ? null : onTagFilterEnabledChanged,
          ),
          _CompactCheckItem(
            label: '无标签',
            selected: untaggedOnly,
            onChanged: busy || !tagFilterEnabled ? null : onUntaggedOnlyChanged,
          ),
          Tooltip(
            message: acgIncludePresetTooltip,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onApplyAcgIncludePreset,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('ACG 白名单'),
            ),
          ),
          Tooltip(
            message: acgExcludePresetTooltip,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onApplyAcgExcludePreset,
              icon: const Icon(Icons.block),
              label: const Text('ACG 黑名单'),
            ),
          ),
          _CompactCheckItem(
            label: '筛选中文',
            selected: chinesePresetOnly,
            onChanged: busy ? null : onChinesePresetOnlyChanged,
          ),
          _CompactCheckItem(
            label: '全难度',
            selected: requireAllDifficulties,
            onChanged: busy ? null : onRequireAllDifficultiesChanged,
          ),
          _CompactTextField(
            controller: difficultyFilterController,
            enabled: !busy,
            width: 180,
            label: '包含难度',
            hintText: 'Expert, ExpertPlus',
            onSubmitted: onSearch,
          ),
          _CompactCheckItem(
            label: '难度-与',
            selected: difficultyMatchAll,
            onChanged: busy ? null : onDifficultyMatchAllChanged,
          ),
          _CompactTextField(
            controller: characteristicFilterController,
            enabled: !busy,
            width: 220,
            label: '包含模式',
            hintText: 'Standard, OneSaber',
            onSubmitted: onSearch,
          ),
          _InlineLabeledField(
            label: '上传者/ID',
            width: 190,
            child: TextField(
              controller: uploaderController,
              enabled: !busy,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          _CompactTextField(
            controller: requiredComponentsController,
            enabled: !busy,
            width: 180,
            label: '需求组件',
            hintText: 'ne, me',
            onSubmitted: onSearch,
          ),
          _CompactTextField(
            controller: excludedComponentsController,
            enabled: !busy,
            width: 180,
            label: '排除组件',
            hintText: 'chroma, cinema',
            onSubmitted: onSearch,
          ),
          _CompactTextField(
            controller: includeTagsController,
            enabled: !busy,
            width: 180,
            label: '包含标签',
            hintText: 'electronic, speed',
            onSubmitted: onSearch,
          ),
          _CompactTextField(
            controller: excludeTagsController,
            enabled: !busy,
            width: 180,
            label: '排除标签',
            hintText: 'meme',
            onSubmitted: onSearch,
          ),
          Tooltip(
            message: '联网识别：开启后搜索结果会用 GCP Vision 识别封面标签；已命中封面缓存时优先离线复用。',
            child: _CompactCheckItem(
              label: '封面标签',
              selected: coverTagFilterEnabled,
              onChanged: busy ? null : onCoverTagFilterEnabledChanged,
            ),
          ),
          _InlineLabeledField(
            label: 'GCP Token',
            width: 260,
            child: TextField(
              controller: coverTokenController,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          _CompactTextField(
            controller: coverIncludeTagsController,
            enabled: !busy,
            width: 180,
            label: '封面包含',
            hintText: 'anime, game',
            onSubmitted: onSearch,
          ),
          _CompactTextField(
            controller: coverExcludeTagsController,
            enabled: !busy,
            width: 180,
            label: '封面排除',
            hintText: 'person',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: coverIncludeConfidenceController,
            enabled: !busy,
            label: '包含置信',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: coverExcludeConfidenceController,
            enabled: !busy,
            label: '排除置信',
            onSubmitted: onSearch,
          ),
          _CompactCheckItem(
            label: '封面 ACG',
            selected: coverAcgPresetEnabled,
            onChanged: busy ? null : onCoverAcgPresetEnabledChanged,
          ),
          _CompactCheckItem(
            label: '失败等待',
            selected: coverWaitOnFailure,
            onChanged: busy ? null : onCoverWaitOnFailureChanged,
          ),
          _CompactCheckItem(
            label: '包含-与',
            selected: coverIncludeMatchAll,
            onChanged: busy ? null : onCoverIncludeMatchAllChanged,
          ),
          _CompactCheckItem(
            label: '排除-与',
            selected: coverExcludeMatchAll,
            onChanged: busy ? null : onCoverExcludeMatchAllChanged,
          ),
          Tooltip(
            message: coverLabelCacheExportTooltip,
            child: OutlinedButton.icon(
              onPressed:
                  coverLabelCacheActionEnabledForTest(
                    entries: coverLabelCacheCount,
                    busy: busy,
                  )
                  ? onExportCoverLabelCache
                  : null,
              icon: const Icon(Icons.ios_share),
              label: const Text('导出封面缓存'),
            ),
          ),
          Tooltip(
            message: coverLabelCacheClearTooltip,
            child: OutlinedButton.icon(
              onPressed:
                  coverLabelCacheActionEnabledForTest(
                    entries: coverLabelCacheCount,
                    busy: busy,
                  )
                  ? onClearCoverLabelCache
                  : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('清空封面缓存'),
            ),
          ),
          _CompactNumberField(
            controller: minDownloadsController,
            enabled: !busy,
            label: '下载量 >=*',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minPlaysController,
            enabled: !busy,
            label: '游戏 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxPlaysController,
            enabled: !busy,
            label: '游戏 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minUpvotesController,
            enabled: !busy,
            label: '点赞 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minUpvoteRatioController,
            enabled: !busy,
            label: '赞比 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxUpvoteRatioController,
            enabled: !busy,
            label: '赞比 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxDownvotesController,
            enabled: !busy,
            label: '点踩 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minDownvoteRatioController,
            enabled: !busy,
            label: '踩比 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxDownvoteRatioController,
            enabled: !busy,
            label: '踩比 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minScoreController,
            enabled: !busy,
            label: '评分 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxScoreController,
            enabled: !busy,
            label: '评分 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minBpmController,
            enabled: !busy,
            label: 'BPM >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxBpmController,
            enabled: !busy,
            label: 'BPM <=',
            onSubmitted: onSearch,
          ),
          _CompactTextField(
            controller: uploadedAfterController,
            enabled: !busy,
            width: 150,
            label: '上传起始',
            hintText: 'YYYY-MM-DD',
            onSubmitted: onSearch,
          ),
          _CompactTextField(
            controller: uploadedBeforeController,
            enabled: !busy,
            width: 150,
            label: '上传截止',
            hintText: 'YYYY-MM-DD',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minNotesController,
            enabled: !busy,
            label: '方块 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxNotesController,
            enabled: !busy,
            label: '方块 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minBombsController,
            enabled: !busy,
            label: '炸弹 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxBombsController,
            enabled: !busy,
            label: '炸弹 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minObstaclesController,
            enabled: !busy,
            label: '墙 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxObstaclesController,
            enabled: !busy,
            label: '墙 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minMapSecondsController,
            enabled: !busy,
            label: '谱秒 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxMapSecondsController,
            enabled: !busy,
            label: '谱秒 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minNjsController,
            enabled: !busy,
            label: 'NJS >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxNjsController,
            enabled: !busy,
            label: 'NJS <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minNpsController,
            enabled: !busy,
            label: 'NPS >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxNpsController,
            enabled: !busy,
            label: 'NPS <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minOffsetController,
            enabled: !busy,
            label: '偏移 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxOffsetController,
            enabled: !busy,
            label: '偏移 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minEventsController,
            enabled: !busy,
            label: '灯光 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxEventsController,
            enabled: !busy,
            label: '灯光 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minSageScoreController,
            enabled: !busy,
            label: 'Sage >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxSageScoreController,
            enabled: !busy,
            label: 'Sage <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minStarsController,
            enabled: !busy,
            label: '星级 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxStarsController,
            enabled: !busy,
            label: '星级 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: minMaxScoreController,
            enabled: !busy,
            label: '最高分 >=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxMaxScoreController,
            enabled: !busy,
            label: '最高分 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxParityErrorsController,
            enabled: !busy,
            label: '错 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxParityWarnsController,
            enabled: !busy,
            label: '警 <=',
            onSubmitted: onSearch,
          ),
          _CompactNumberField(
            controller: maxParityResetsController,
            enabled: !busy,
            label: '重 <=',
            onSubmitted: onSearch,
          ),
        ],
      ),
    );

    final filterCorePanel = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineLabeledField(
          label: '搜索过滤',
          width: 360,
          child: TextField(
            controller: filterTextController,
            enabled: !busy,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        _CompactCheckItem(
          label: '标题',
          selected: filterTitle,
          onChanged: busy ? null : onFilterTitleChanged,
        ),
        _CompactCheckItem(
          label: '歌名',
          selected: filterSongName,
          onChanged: busy ? null : onFilterSongNameChanged,
        ),
        _CompactCheckItem(
          label: '作者',
          selected: filterSongAuthor,
          onChanged: busy ? null : onFilterSongAuthorChanged,
        ),
        _CompactCheckItem(
          label: '谱师',
          selected: filterMapper,
          onChanged: busy ? null : onFilterMapperChanged,
        ),
        _CompactCheckItem(
          label: '过滤正则',
          selected: filterRegexMode,
          onChanged: busy ? null : onFilterRegexModeChanged,
        ),
        _CompactNumberField(
          controller: downloadLimitController,
          enabled: !busy,
          label: '限制数量',
          onSubmitted: onSearch,
        ),
        _CompactCheckItem(
          label: '精选',
          selected: curatedOnly,
          onChanged: busy ? null : onCuratedOnlyChanged,
        ),
        _CompactCheckItem(
          label: 'Ranked',
          selected: rankedOnly,
          onChanged: busy ? null : onRankedOnlyChanged,
        ),
        _CompactCheckItem(
          label: '隐藏 AI 谱',
          selected: hideAi,
          onChanged: busy ? null : onHideAiChanged,
        ),
        _CompactCheckItem(
          label: '标签过滤',
          selected: tagFilterEnabled,
          onChanged: busy ? null : onTagFilterEnabledChanged,
        ),
        Tooltip(
          message: clearFiltersTooltip,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onClearFilters,
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('清空筛选'),
          ),
        ),
      ],
    );

    final compactFilterPanel = _ControlGroup(
      title: '高级筛选',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          filterCorePanel,
          const SizedBox(height: 8),
          _InlineAdvancedFilterGroup(child: filterPanel.child),
        ],
      ),
    );

    const gap = SizedBox(height: 12);
    if (!searchWorkspace) {
      return workspacePathToolbar;
    }

    return _Section(
      title: 'Beat Saber Song Toolkit 主面板',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1100) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [dataSourcePanel, gap, pathPanel],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: compactFilterPanel),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [dataSourcePanel, gap, filterPanel, gap, pathPanel],
          );
        },
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.results,
    required this.selectedMaps,
    required this.page,
    required this.pageSize,
    required this.totalResults,
    required this.totalPages,
    required this.busy,
    required this.stopRequested,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onSelectionChanged,
    required this.onSelectAllChanged,
    required this.onClearSelection,
    required this.onImportTargets,
    required this.onExportTargets,
    required this.onSaveSelectedListAndZips,
    required this.onDownloadSelectedRawZips,
    required this.onDownloadSelectedZip,
    required this.onInstallSelected,
    required this.onStopSelectedFlow,
    required this.onDownloadZip,
    required this.onInstall,
  });

  final List<BeatSaverMap> results;
  final List<BeatSaverMap> selectedMaps;
  final int page;
  final int pageSize;
  final int totalResults;
  final int totalPages;
  final bool busy;
  final bool stopRequested;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final void Function(BeatSaverMap map, bool selected) onSelectionChanged;
  final ValueChanged<bool> onSelectAllChanged;
  final VoidCallback onClearSelection;
  final VoidCallback onImportTargets;
  final VoidCallback onExportTargets;
  final VoidCallback onSaveSelectedListAndZips;
  final VoidCallback onDownloadSelectedRawZips;
  final VoidCallback onDownloadSelectedZip;
  final VoidCallback onInstallSelected;
  final VoidCallback onStopSelectedFlow;
  final Future<void> Function(BeatSaverMap map) onDownloadZip;
  final Future<void> Function(BeatSaverMap map) onInstall;

  @override
  Widget build(BuildContext context) {
    final selectedIds = selectedMaps.map((map) => map.id).toSet();
    final selectedOnPage = results
        .where((map) => selectedIds.contains(map.id))
        .length;
    return _Section(
      title: 'BeatSaver 搜索',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                totalResults <= 0
                    ? '未搜索'
                    : '第 ${page + 1}/${totalPages == 0 ? 1 : totalPages} 页，'
                          '总数 $totalResults，每页 $pageSize',
              ),
              Tooltip(
                message: previousPageTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPreviousPage,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('上一页'),
                ),
              ),
              Tooltip(
                message: nextPageTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onNextPage,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('下一页'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SelectedTargetsPanel(
            selectedMaps: selectedMaps,
            busy: busy,
            onRemove: (map) => onSelectionChanged(map, false),
            onClear: onClearSelection,
            onImport: onImportTargets,
            onExport: onExportTargets,
            stopRequested: stopRequested,
            onStart: onInstallSelected,
            onStop: onStopSelectedFlow,
          ),
          const SizedBox(height: 12),
          if (results.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: CheckboxListTile(
                    value: selectedOnPage == 0
                        ? false
                        : selectedOnPage == results.length
                        ? true
                        : null,
                    tristate: true,
                    onChanged: busy
                        ? null
                        : (value) => onSelectAllChanged(value ?? false),
                    title: Text('本页选择 $selectedOnPage/${results.length}'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Tooltip(
                  message: selectedSaveTooltip,
                  child: OutlinedButton.icon(
                    onPressed:
                        selectedResultsActionEnabledForTest(
                          selectedCount: selectedIds.length,
                          busy: busy,
                        )
                        ? onSaveSelectedListAndZips
                        : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('保存所选'),
                  ),
                ),
                Tooltip(
                  message: selectedDownloadZipTooltip,
                  child: OutlinedButton.icon(
                    onPressed:
                        selectedResultsActionEnabledForTest(
                          selectedCount: selectedIds.length,
                          busy: busy,
                        )
                        ? onDownloadSelectedRawZips
                        : null,
                    icon: const Icon(Icons.folder_zip),
                    label: const Text('下载所选 ZIP'),
                  ),
                ),
                Tooltip(
                  message: selectedPackZipTooltip,
                  child: OutlinedButton.icon(
                    onPressed:
                        selectedResultsActionEnabledForTest(
                          selectedCount: selectedIds.length,
                          busy: busy,
                        )
                        ? onDownloadSelectedZip
                        : null,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('打包所选 ZIP'),
                  ),
                ),
                Tooltip(
                  message: selectedInstallTooltip,
                  child: FilledButton.tonalIcon(
                    onPressed:
                        selectedResultsActionEnabledForTest(
                          selectedCount: selectedIds.length,
                          busy: busy,
                        )
                        ? onInstallSelected
                        : null,
                    icon: const Icon(Icons.download),
                    label: const Text('安装所选'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
          for (final map in results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 96,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: selectedIds.contains(map.id),
                      onChanged: busy
                          ? null
                          : (value) => onSelectionChanged(map, value ?? false),
                    ),
                    CoverImage(url: map.latestVersion?.coverUrl ?? ''),
                  ],
                ),
              ),
              title: Text(
                map.metadata.songName.isEmpty
                    ? map.name
                    : map.metadata.songName,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${map.metadata.songAuthorName} | '
                    '${map.metadata.levelAuthorName} | '
                    '上传者 ${map.uploaderName ?? '-'}'
                    '${map.uploaderId == null ? '' : ' #${map.uploaderId}'} | '
                    'ID ${map.id}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(map.metadata.durationSeconds)} | '
                    'BPM ${map.metadata.bpm.toStringAsFixed(0)} | '
                    '评分 ${map.stats.score.toStringAsFixed(2)} | '
                    '${_formatDownloads(map.stats.downloads)} | '
                    '赞 ${map.stats.upvotes}/踩 ${map.stats.downvotes} | '
                    '评论 ${map.stats.reviews}',
                  ),
                  const SizedBox(height: 6),
                  MapBadges(map: map),
                  const SizedBox(height: 6),
                  DifficultySummary(
                    diffs: map.latestVersion?.diffs ?? const [],
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 8,
                children: [
                  Tooltip(
                    message: resultDownloadZipTooltip,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => onDownloadZip(map),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('下载 ZIP'),
                    ),
                  ),
                  Tooltip(
                    message: resultInstallTooltip,
                    child: FilledButton.tonalIcon(
                      onPressed: busy ? null : () => onInstall(map),
                      icon: const Icon(Icons.download),
                      label: const Text('下载并安装'),
                    ),
                  ),
                ],
              ),
            ),
          if (results.isEmpty)
            const _EmptyState(text: '搜索 BeatSaver 后会在这里显示谱面。'),
        ],
      ),
    );
  }
}

class _SelectedTargetsPanel extends StatelessWidget {
  const _SelectedTargetsPanel({
    required this.selectedMaps,
    required this.busy,
    required this.stopRequested,
    required this.onRemove,
    required this.onClear,
    required this.onImport,
    required this.onExport,
    required this.onStart,
    required this.onStop,
  });

  final List<BeatSaverMap> selectedMaps;
  final bool busy;
  final bool stopRequested;
  final ValueChanged<BeatSaverMap> onRemove;
  final VoidCallback onClear;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedTargetsTitleForTest(selectedMaps.length),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Tooltip(
                      message: busy
                          ? queueStopTooltip
                          : selectedTargetsStartTooltip,
                      child: FilledButton.icon(
                        onPressed:
                            selectedTargetsStartEnabledForTest(
                              selectedCount: selectedMaps.length,
                              busy: busy,
                              stopRequested: stopRequested,
                            )
                            ? onStart
                            : selectedTargetsStopEnabledForTest(
                                busy: busy,
                                stopRequested: stopRequested,
                              )
                            ? onStop
                            : null,
                        icon: Icon(
                          busy ? Icons.stop_circle_outlined : Icons.play_arrow,
                        ),
                        label: Text(
                          selectedTargetsPrimaryButtonLabelForTest(
                            busy: busy,
                            stopRequested: stopRequested,
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: selectedTargetsImportTooltip,
                      child: TextButton.icon(
                        onPressed: busy ? null : onImport,
                        icon: const Icon(Icons.file_open),
                        label: const Text('导入'),
                      ),
                    ),
                    Tooltip(
                      message: selectedTargetsExportTooltip,
                      child: TextButton.icon(
                        onPressed: busy || selectedMaps.isEmpty
                            ? null
                            : onExport,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('导出'),
                      ),
                    ),
                    Tooltip(
                      message: selectedTargetsClearTooltip,
                      child: TextButton.icon(
                        onPressed: busy || selectedMaps.isEmpty
                            ? null
                            : onClear,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('清空'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (selectedMaps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final map in selectedMaps)
                    InputChip(
                      label: Text('${map.id} ${_mapTitle(map)}'),
                      onDeleted: busy ? null : () => onRemove(map),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataSourceTabs extends StatelessWidget {
  const _DataSourceTabs({
    required this.initialTabIndex,
    required this.queryController,
    required this.uploaderController,
    required this.beastSaberUrlController,
    required this.beastSaberStartPageController,
    required this.scoreSaberMinStarController,
    required this.scoreSaberMaxStarController,
    required this.localCacheSaverController,
    required this.localCacheStatus,
    required this.hasLocalCacheDeletedAudit,
    required this.localCacheSnapshotProgress,
    required this.hashCacheStatus,
    required this.zipCacheEntries,
    required this.onlinePlaylistController,
    required this.manualMapsController,
    required this.skipMapsController,
    required this.busy,
    required this.searchOrder,
    required this.pageSize,
    required this.regexSearchMode,
    required this.onSearch,
    required this.onSearchUploader,
    required this.onSearchScoreSaber,
    required this.onSearchBeastSaber,
    required this.onReadLocalCache,
    required this.onPickLocalCacheSaverFile,
    required this.onBuildLocalCacheSnapshot,
    required this.onResumeLocalCacheSnapshot,
    required this.onUpdateLocalCacheSnapshot,
    required this.onAuditLocalCacheDeleted,
    required this.onExportLocalCacheDeletedAudit,
    required this.onPauseLocalCacheSnapshot,
    required this.onAddLocalCacheToTargets,
    required this.onAddLocalCacheToSkip,
    required this.onExportLocalCache,
    required this.onExportLocalCacheSummary,
    required this.onClearLocalCache,
    required this.onExportHashCache,
    required this.onClearHashCache,
    required this.onRefreshZipCache,
    required this.onAddZipCacheToTargets,
    required this.onAddZipCacheToSkip,
    required this.onExportZipCache,
    required this.onImportOnlinePlaylist,
    required this.onSearchOrderChanged,
    required this.onPageSizeChanged,
    required this.onRegexSearchModeChanged,
    required this.onClearFilters,
    required this.onAddManualMapsToResults,
    required this.onAddManualMapsToSkip,
    required this.onInstallManualMaps,
    required this.onPickManualListFile,
    required this.onImportTargets,
    required this.onExportResultsList,
  });

  final int initialTabIndex;
  final TextEditingController queryController;
  final TextEditingController uploaderController;
  final TextEditingController beastSaberUrlController;
  final TextEditingController beastSaberStartPageController;
  final TextEditingController scoreSaberMinStarController;
  final TextEditingController scoreSaberMaxStarController;
  final TextEditingController localCacheSaverController;
  final _LocalCacheStatus? localCacheStatus;
  final bool hasLocalCacheDeletedAudit;
  final LocalCacheSnapshotProgress? localCacheSnapshotProgress;
  final _HashCacheStatus? hashCacheStatus;
  final List<ZipCacheEntryUiModel> zipCacheEntries;
  final TextEditingController onlinePlaylistController;
  final TextEditingController manualMapsController;
  final TextEditingController skipMapsController;
  final bool busy;
  final BeatSaverSearchOrder searchOrder;
  final int pageSize;
  final bool regexSearchMode;
  final VoidCallback onSearch;
  final VoidCallback onSearchUploader;
  final VoidCallback onSearchScoreSaber;
  final VoidCallback onSearchBeastSaber;
  final VoidCallback onReadLocalCache;
  final VoidCallback onPickLocalCacheSaverFile;
  final VoidCallback onBuildLocalCacheSnapshot;
  final VoidCallback onResumeLocalCacheSnapshot;
  final VoidCallback onUpdateLocalCacheSnapshot;
  final VoidCallback onAuditLocalCacheDeleted;
  final VoidCallback onExportLocalCacheDeletedAudit;
  final VoidCallback onPauseLocalCacheSnapshot;
  final VoidCallback onAddLocalCacheToTargets;
  final VoidCallback onAddLocalCacheToSkip;
  final VoidCallback onExportLocalCache;
  final VoidCallback onExportLocalCacheSummary;
  final VoidCallback onClearLocalCache;
  final VoidCallback onExportHashCache;
  final VoidCallback onClearHashCache;
  final VoidCallback onRefreshZipCache;
  final Future<void> Function(List<ZipCacheEntryUiModel> entries)
  onAddZipCacheToTargets;
  final ValueChanged<List<ZipCacheEntryUiModel>> onAddZipCacheToSkip;
  final VoidCallback onExportZipCache;
  final VoidCallback onImportOnlinePlaylist;
  final ValueChanged<BeatSaverSearchOrder> onSearchOrderChanged;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<bool> onRegexSearchModeChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onAddManualMapsToResults;
  final VoidCallback onAddManualMapsToSkip;
  final VoidCallback onInstallManualMaps;
  final VoidCallback onPickManualListFile;
  final VoidCallback onImportTargets;
  final VoidCallback onExportResultsList;

  @override
  Widget build(BuildContext context) {
    final identifiableZipCacheEntries = zipCacheEntries
        .where((entry) => entry.mapId != null)
        .toList(growable: false);

    return DefaultTabController(
      length: 7,
      initialIndex: initialTabIndex.clamp(0, 6),
      key: ValueKey('data-source-tabs-$initialTabIndex'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'BeatSaver'),
              Tab(text: '谱师'),
              Tab(text: 'ScoreSaber'),
              Tab(text: 'BEASTSABER'),
              Tab(text: '本地缓存'),
              Tab(text: '歌曲列表'),
              Tab(text: '手动'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 156,
            child: TabBarView(
              children: [
                _DataSourcePane(
                  children: [
                    _InlineLabeledField(
                      label: '搜索词',
                      width: 300,
                      child: TextField(
                        controller: queryController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          hintText: '搜索关键词',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onSearch(),
                      ),
                    ),
                    _SearchOrderField(
                      searchOrder: searchOrder,
                      busy: busy,
                      onChanged: onSearchOrderChanged,
                    ),
                    _PageSizeField(
                      pageSize: pageSize,
                      busy: busy,
                      onChanged: onPageSizeChanged,
                    ),
                    Tooltip(
                      message: '联网搜索：请求 BeatSaver 文本搜索接口，并按当前筛选条件显示结果。',
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('搜索'),
                      ),
                    ),
                    _CompactCheckItem(
                      label: '正则',
                      selected: regexSearchMode,
                      onChanged: busy ? null : onRegexSearchModeChanged,
                    ),
                    Tooltip(
                      message: clearFiltersTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onClearFilters,
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('清空筛选'),
                      ),
                    ),
                  ],
                ),
                _DataSourcePane(
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: uploaderController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: '谱师名或上传者 ID',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onSearchUploader(),
                      ),
                    ),
                    _PageSizeField(
                      pageSize: pageSize,
                      busy: busy,
                      onChanged: onPageSizeChanged,
                    ),
                    Tooltip(
                      message: '联网搜索：按谱师名或上传者 ID 请求 BeatSaver 谱师谱面。',
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSearchUploader,
                        icon: const Icon(Icons.person_search),
                        label: const Text('谱师谱面'),
                      ),
                    ),
                  ],
                ),
                _DataSourcePane(
                  children: [
                    _PageSizeField(
                      pageSize: pageSize,
                      busy: busy,
                      onChanged: onPageSizeChanged,
                    ),
                    _CompactNumberField(
                      controller: scoreSaberMinStarController,
                      enabled: !busy,
                      label: '难度最低',
                      onSubmitted: onSearchScoreSaber,
                    ),
                    _CompactNumberField(
                      controller: scoreSaberMaxStarController,
                      enabled: !busy,
                      label: '难度最高',
                      onSubmitted: onSearchScoreSaber,
                    ),
                    const Chip(label: Text('Ranked')),
                    Tooltip(
                      message: '联网搜索：请求 ScoreSaber ranked 谱面，再转 BeatSaver 详情。',
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSearchScoreSaber,
                        icon: const Icon(Icons.leaderboard),
                        label: const Text('ScoreSaber'),
                      ),
                    ),
                  ],
                ),
                _DataSourcePane(
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: beastSaberUrlController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: '第一页地址',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onSearchBeastSaber(),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: beastSaberStartPageController,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '开始页数',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onSearchBeastSaber(),
                      ),
                    ),
                    Tooltip(
                      message:
                          '联网搜索：读取 BEASTSABER 页面并用预览 hash 查询 BeatSaver 详情。',
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSearchBeastSaber,
                        icon: const Icon(Icons.public),
                        label: const Text('开始'),
                      ),
                    ),
                  ],
                ),
                _DataSourcePane(
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: localCacheSaverController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'LocalCache.saver',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onReadLocalCache(),
                      ),
                    ),
                    Tooltip(
                      message: localCachePickTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onPickLocalCacheSaverFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('选择数据缓存'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheReadTooltip,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onReadLocalCache,
                        icon: const Icon(Icons.manage_search),
                        label: const Text('读取数据缓存'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheRebuildTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onBuildLocalCacheSnapshot,
                        icon: const Icon(Icons.cloud_sync),
                        label: const Text('重建快照'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheResumeTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onResumeLocalCacheSnapshot,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('继续快照'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheIncrementalTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onUpdateLocalCacheSnapshot,
                        icon: const Icon(Icons.update),
                        label: const Text('增量更新'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheDeletedAuditTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onAuditLocalCacheDeleted,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('审计删除'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheDeletedExportTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || !hasLocalCacheDeletedAudit
                            ? null
                            : onExportLocalCacheDeletedAudit,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('导出删除'),
                      ),
                    ),
                    Tooltip(
                      message: localCachePauseTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? onPauseLocalCacheSnapshot : null,
                        icon: const Icon(Icons.pause),
                        label: const Text('暂停快照'),
                      ),
                    ),
                    if (localCacheSnapshotProgress != null)
                      Chip(
                        label: Text(
                          '快照 ${localCacheSnapshotProgress!.pagesFetched} 页 / '
                          '${localCacheSnapshotProgress!.fetchedMaps} 张',
                        ),
                      ),
                    Tooltip(
                      message: localCacheAddToTargetsTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || localCacheStatus == null
                            ? null
                            : onAddLocalCacheToTargets,
                        icon: const Icon(Icons.playlist_add_check),
                        label: const Text('数据入本次'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheAddToSkipTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || localCacheStatus == null
                            ? null
                            : onAddLocalCacheToSkip,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('数据入跳过'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheExportTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || localCacheStatus == null
                            ? null
                            : onExportLocalCache,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('导出数据'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheSummaryTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || localCacheStatus == null
                            ? null
                            : onExportLocalCacheSummary,
                        icon: const Icon(Icons.summarize_outlined),
                        label: const Text('导出摘要'),
                      ),
                    ),
                    Tooltip(
                      message: localCacheClearTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || localCacheStatus == null
                            ? null
                            : onClearLocalCache,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('清空数据'),
                      ),
                    ),
                    Chip(
                      label: Text(
                        localCacheStatus == null
                            ? '数据未读取'
                            : '数据 ${localCacheStatus!.maps}',
                      ),
                    ),
                    if (localCacheStatus != null)
                      Chip(label: Text(_formatBytes(localCacheStatus!.bytes))),
                    if (localCacheStatus != null)
                      Chip(
                        label: Text(
                          localCacheStatus!.generatedAt == null
                              ? '修改 ${_formatDate(localCacheStatus!.modified)}'
                              : '生成 ${_formatDate(localCacheStatus!.generatedAt!)}',
                        ),
                      ),
                    if (localCacheStatus != null)
                      Chip(
                        label: Text(
                          localCacheAgeLabelForTest(
                            generatedAt: localCacheStatus!.generatedAt,
                            modified: localCacheStatus!.modified,
                            now: DateTime.now(),
                          ),
                        ),
                      ),
                    if (localCacheStatus?.incrementalUpdatedAt != null)
                      Chip(
                        label: Text(
                          localCacheIncrementalLabelForTest(
                            updatedAt: localCacheStatus!.incrementalUpdatedAt!,
                            added: localCacheStatus!.incrementalAdded,
                            updated: localCacheStatus!.incrementalUpdated,
                          ),
                        ),
                      ),
                    Chip(label: Text('Hash ${hashCacheStatus?.entries ?? 0}')),
                    if (hashCacheStatus != null &&
                        hashCacheStatus!.cacheDate.isNotEmpty)
                      Chip(label: Text('Hash日期 ${hashCacheStatus!.cacheDate}')),
                    Tooltip(
                      message: hashCacheExportTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onExportHashCache,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('导出Hash'),
                      ),
                    ),
                    Tooltip(
                      message: hashCacheClearTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onClearHashCache,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('清空Hash'),
                      ),
                    ),
                    Chip(label: Text('ZIP ${zipCacheEntries.length}')),
                    Chip(
                      label: Text('可识别 ${identifiableZipCacheEntries.length}'),
                    ),
                    Tooltip(
                      message: zipCacheScanTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onRefreshZipCache,
                        icon: const Icon(Icons.refresh),
                        label: const Text('扫描 ZIP'),
                      ),
                    ),
                    Tooltip(
                      message: zipCacheAddToTargetsTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || identifiableZipCacheEntries.isEmpty
                            ? null
                            : () => onAddZipCacheToTargets(
                                identifiableZipCacheEntries,
                              ),
                        icon: const Icon(Icons.playlist_add_check),
                        label: const Text('ZIP 入本次'),
                      ),
                    ),
                    Tooltip(
                      message: zipCacheAddToSkipTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || identifiableZipCacheEntries.isEmpty
                            ? null
                            : () => onAddZipCacheToSkip(
                                identifiableZipCacheEntries,
                              ),
                        icon: const Icon(Icons.skip_next),
                        label: const Text('ZIP 入跳过'),
                      ),
                    ),
                    Tooltip(
                      message: zipCacheExportTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy || zipCacheEntries.isEmpty
                            ? null
                            : onExportZipCache,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('导出 ZIP'),
                      ),
                    ),
                  ],
                ),
                _DataSourcePane(
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: onlinePlaylistController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: '在线歌单/链接',
                          hintText: 'BeatSaver playlist ID 或链接',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onImportOnlinePlaylist(),
                      ),
                    ),
                    Tooltip(
                      message:
                          '联网导入：按 BeatSaver 在线歌单 ID/链接读取歌单，并把筛选后的谱面加入本次列表。',
                      child: FilledButton.icon(
                        onPressed: busy ? null : onImportOnlinePlaylist,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('歌单入本次'),
                      ),
                    ),
                    Tooltip(
                      message: manualPickListTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onPickManualListFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('读取列表'),
                      ),
                    ),
                    Tooltip(
                      message: manualImportTargetsTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onImportTargets,
                        icon: const Icon(Icons.playlist_add_check),
                        label: const Text('列表入本次'),
                      ),
                    ),
                    Tooltip(
                      message: manualExportResultsTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onExportResultsList,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('导出结果'),
                      ),
                    ),
                  ],
                ),
                _DataSourcePane(
                  children: [
                    SizedBox(
                      width: 520,
                      child: TextField(
                        controller: manualMapsController,
                        enabled: !busy,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '手动 ID/链接',
                          hintText: '支持 133ee、https://beatsaver.com/maps/133ee',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: skipMapsController,
                        enabled: !busy,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '跳过歌曲',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: manualAddToTargetsTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onAddManualMapsToResults,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('加入本次'),
                      ),
                    ),
                    Tooltip(
                      message: manualAddToSkipTooltip,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onAddManualMapsToSkip,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('加入跳过'),
                      ),
                    ),
                    Tooltip(
                      message: manualInstallTooltip,
                      child: FilledButton.tonalIcon(
                        onPressed: busy ? null : onInstallManualMaps,
                        icon: const Icon(Icons.download),
                        label: const Text('安装手动输入'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataSourcePane extends StatelessWidget {
  const _DataSourcePane({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

String _workspaceHelpTitle(_Workspace workspace) {
  return workspaceHelpTitleForTest(workspace.toWorkspaceForTest());
}

List<WorkspaceHelpSectionForTest> _workspaceHelpSections(_Workspace workspace) {
  return workspaceHelpSectionsForTest(workspace.toWorkspaceForTest());
}

String _searchOrderLabel(BeatSaverSearchOrder order) {
  return searchOrderLabelForTest(order);
}

String _formatDuration(int seconds) {
  return formatDurationForTest(seconds);
}

String _formatDownloads(int downloads) {
  return formatDownloadsForTest(downloads);
}

String _formatBytes(int bytes) {
  return formatBytesForTest(bytes);
}

String _mapTitle(BeatSaverMap map) {
  return mapTitleForTest(map);
}

bool _matchesSearchRegex(BeatSaverMap map, RegExp regex) {
  return matchesSearchRegexForTest(map, regex);
}

bool _matchesFieldFilterTokens(
  BeatSaverMap map,
  Set<String> tokens, {
  required bool title,
  required bool songName,
  required bool songAuthor,
  required bool mapper,
  required bool description,
  required bool tags,
}) {
  return matchesFieldFilterTokensForTest(
    map,
    tokens,
    title: title,
    songName: songName,
    songAuthor: songAuthor,
    mapper: mapper,
    description: description,
    tags: tags,
  );
}

bool _matchesFieldFilterRegex(
  BeatSaverMap map,
  RegExp regex, {
  required bool title,
  required bool songName,
  required bool songAuthor,
  required bool mapper,
  required bool description,
  required bool tags,
}) {
  return matchesFieldFilterRegexForTest(
    map,
    regex,
    title: title,
    songName: songName,
    songAuthor: songAuthor,
    mapper: mapper,
    description: description,
    tags: tags,
  );
}

bool _matchesChinesePreset(BeatSaverMap map) {
  return matchesChinesePresetForTest(map);
}

int? _parseInt(String value) {
  return parseIntForTest(value);
}

double? _parseDouble(String value) {
  return parseDoubleForTest(value);
}

double? _parseRatio(String value) {
  return parseRatioForTest(value);
}

DateTime? _parseDate(String value) {
  return parseDateForTest(value);
}

Set<String> _splitFilterTokens(String value) {
  return splitFilterTokensForTest(value);
}

bool _diffsContainAllComponents(
  List<BeatSaverDifficulty> diffs,
  Set<String> components,
) {
  return diffsContainAllComponentsForTest(diffs, components);
}

bool _diffsContainAnyComponent(
  List<BeatSaverDifficulty> diffs,
  Set<String> components,
) {
  return diffsContainAnyComponentForTest(diffs, components);
}

String _stringSetting(Map<String, dynamic> json, String key, String fallback) {
  return settingStringForTest(json, key, fallback);
}

List<String> _stringListSetting(Map<String, dynamic> json, String key) {
  return settingStringListForTest(json, key);
}

bool _boolSetting(Map<String, dynamic> json, String key, bool fallback) {
  return settingBoolForTest(json, key, fallback);
}

int _intSetting(Map<String, dynamic> json, String key, int fallback) {
  return settingIntForTest(json, key, fallback);
}

double _doubleSetting(Map<String, dynamic> json, String key, double fallback) {
  return settingDoubleForTest(json, key, fallback);
}

_DownloadMode _downloadModeSetting(
  Map<String, dynamic> json,
  _DownloadMode fallback,
) {
  return downloadModeFromSettingForTest(
    json['downloadMode']?.toString(),
    fallback: fallback.toDownloadModeForTest(),
  ).toDownloadMode();
}

_Workspace _workspaceSetting(Map<String, dynamic> json, _Workspace fallback) {
  return workspaceFromSettingForTest(
    json['workspace']?.toString(),
    fallback: fallback.toWorkspaceForTest(),
  ).toWorkspace();
}

String _downloadModeLabel(_DownloadMode mode) {
  return downloadModeLabelForTest(mode.toDownloadModeForTest());
}

List<String> _parseBeatSaverIds(String input) {
  return parseBeatSaverIdsForTest(input);
}

int? _parseBeatSaverPlaylistId(String input) {
  return parseBeatSaverPlaylistIdForTest(input);
}

Uri _beastSaberPageUrl(String firstPageUrl, int pageNumber) {
  return beastSaberPageUrlForTest(firstPageUrl, pageNumber);
}

List<String> _parseBeastSaberPreviewHashes(String html) {
  return parseBeastSaberPreviewHashesForTest(html);
}

bool get _windowManagerSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> _minimizeStartupWindow() async {
  await windowManager.minimize();
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (startupMinimizeNeedsRetryForTest(
    isMinimizedAfterFirstAttempt: await windowManager.isMinimized(),
  )) {
    await windowManager.minimize();
  }
}

Future<String> _readTextFromUrl(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'text/html,*/*');
    request.headers.set(HttpHeaders.userAgentHeader, 'Beat Saber Song Toolkit');
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Request failed with HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }
    return body;
  } finally {
    client.close(force: true);
  }
}

Future<ReleaseInfo> _fetchLatestRelease(Uri releaseUrl) async {
  final override = releaseFetcherOverrideForTest;
  if (override != null) {
    return override(releaseUrl);
  }
  final body = await _readTextFromUrl(releaseUrl);
  final decoded = jsonDecode(body);
  return releaseInfoFromJsonForTest(decoded);
}

QueueEntrySnapshotForTest _queueEntrySnapshotForTest(_QueueEntry entry) {
  return QueueEntrySnapshotForTest(
    id: entry.id,
    task: QueueTaskForTest.values.byName(entry.task.name),
    status: QueueStatusForTest.values.byName(entry.status.name),
  );
}

String? _zipCacheMapId(String fileName) {
  return zipCacheMapIdForTest(fileName);
}

bool _diffsMatchDifficulties(
  List<BeatSaverDifficulty> diffs,
  Set<String> filters, {
  required bool matchAll,
}) {
  return diffsMatchDifficultiesForTest(diffs, filters, matchAll: matchAll);
}

bool _diffsMatchCharacteristics(
  List<BeatSaverDifficulty> diffs,
  Set<String> filters,
) {
  return diffsMatchCharacteristicsForTest(diffs, filters);
}

bool _hasAllStandardDifficulties(List<BeatSaverDifficulty> diffs) {
  return hasAllStandardDifficultiesForTest(diffs);
}

double _diffStars(BeatSaverDifficulty diff) {
  return difficultyStarsForTest(diff);
}

String _formatDate(DateTime dateTime) {
  return exportDateForTest(dateTime);
}

String _formatDateTime(DateTime dateTime) {
  return formatDateTimeForTest(dateTime);
}

String? _imageMimeType(String path) {
  return playlistImageMimeTypeForTest(path);
}

String _playlistSyncMissingQueueId(PlaylistSyncEntry entry) {
  final key = playlistSyncEntryKeyForTest(entry);
  if (key.isNotEmpty) {
    return 'missing:$key';
  }
  return 'missing:${identityHashCode(entry)}';
}

const selectedSaveTooltip =
    '保存所选：按当前“歌曲列表/下载歌曲”输出开关导出列表或下载 ZIP；下载 ZIP 会联网或复用本地缓存。';
const selectedDownloadZipTooltip =
    '联网下载：把所选谱面的 ZIP 保存到当前 ZIP 下载目录；本地缓存命中时优先复用。';
const selectedPackZipTooltip = '打包 ZIP：把所选谱面打包到指定 ZIP；缺少本地歌曲时会按当前下载方式联网补齐。';
const selectedInstallTooltip = '联网安装：把所选谱面安装到当前安装目录；本地歌曲目录命中时优先复制。';
const resultDownloadZipTooltip = '联网下载：下载该谱面 ZIP 到当前 ZIP 下载目录；本地缓存命中时优先复用。';
const resultInstallTooltip = '联网安装：下载或复制该谱面并写入当前安装目录。';
const manualInstallTooltip = '联网安装：解析手动输入的 BeatSaver ID/链接后下载或复制歌曲，并写入当前安装目录。';
const donateAuthorTooltip = '捐助作者：查看原作者项目和捐助说明，不内置收款码或自动跳转。';
const selectedTargetsStartTooltip = '开始：按当前下载/安装设置处理“本次歌曲”列表，可联网下载或优先复制本地歌曲。';
const selectedTargetsImportTooltip = '导入：从本地歌曲列表文件读取 BeatSaver ID/链接并加入本次歌曲列表。';
const selectedTargetsExportTooltip = '导出：把当前“本次歌曲”列表保存为本地文本文件，不下载歌曲。';
const selectedTargetsClearTooltip = '清空：仅清空当前“本次歌曲”列表，不删除本地文件。';
const readLocalDataOnStartupTooltip = '启动后读入本地：启动时离线扫描安装目录和 ZIP 缓存。';
const autoStartOnStartupTooltip = '启动后自动开始：启动时处理“本次歌曲”列表，可能联网下载或安装歌曲。';
const autoPackOnCompleteTooltip = '完成后自动打包：批量安装完成后把已安装歌曲打包为 ZIP。';
const autoExtractOnCompleteTooltip = '完成后自动解压：批量下载 ZIP 完成后自动安装到当前安装目录。';
const autoExitOnCompleteTooltip = '完成后自动退出：批量任务成功完成且未停止时自动关闭程序。';
const profileSaveTooltip = '保存配置：把当前界面设置保存到 settings.json 的配置预设。';
const profileDeleteTooltip = '删除配置：从 settings.json 移除当前配置预设，执行前会确认；不会删除歌曲或缓存。';
const installedAddFilteredToTargetsTooltip =
    '当前加入本次：把当前过滤结果中可识别 BeatSaver ID 的本地歌曲加入本次列表，不移动文件。';
const installedAddFilteredToSkipTooltip =
    '当前加入跳过：把当前过滤结果中可识别 BeatSaver ID 的本地歌曲加入跳过列表。';
const installedExportCurrentTooltip = '导出当前：把当前过滤后的本地曲库列表保存为文本文件。';
const installedExportPlaylistTooltip =
    '导出歌单：把当前过滤结果中有 BeatSaver ID 且有 info.dat 的歌曲导出为 .bplist。';
const installedExportFavoritesTooltip =
    '导出收藏：读取 Beat Saber PlayerData.dat 收藏记录，并导出为 .bplist。';
const installedSingleDeleteTooltip = '删除已安装歌曲：直接删除该本地歌曲目录，执行前会确认；不会自动备份或修改歌单。';
const duplicateSelectTooltip = '选择重复：选择当前重复候选中建议删除的歌曲目录。';
const duplicateClearTooltip = '清空重复选择：取消当前重复候选选择，不修改文件。';
const duplicateBackupDeleteTooltip = '备份删除重复：先备份选中的重复歌曲目录，再删除原目录；执行前会再次确认。';
const pathCorrectionSelectTooltip = '选择建议：选择当前筛选下可见的路径重命名建议。';
const pathCorrectionClearTooltip = '清空选择：取消当前路径建议选择，不修改文件。';
const pathCorrectionBatchRenameTooltip = '批量重命名：按当前命名模板重命名选中的歌曲目录；执行前会再次确认。';
const pathCorrectionSingleRenameTooltip = '重命名：只重命名这一首歌曲目录，不覆盖已有目标目录；执行前会再次确认。';
const gameDirectoryInspectTooltip =
    '检测游戏目录：检查 Beat Saber.exe、CustomLevels、SongCore 和 PlaylistManager 状态。';
const songCoreReadTooltip =
    '读取列表：读取 SongCore UserData\\SongCore\\folders.xml 保存列表。';
const songCoreSaveTooltip =
    '保存列表：把当前本地歌曲目录写入 SongCore folders.xml，写回前会自动备份原 XML。';
const songCoreCopyXmlTooltip = '复制XML路径：复制当前 SongCore folders.xml 文件路径。';
const songCoreCopyBackupTooltip = '复制备份目录：复制 SongCore folders.xml 自动备份目录路径。';
const playlistSyncFilterTooltip = '同步状态：筛选当前歌单与本地曲库的一一对比结果。';
const playlistSyncTableExpandTooltip = '扩大对比表格高度，便于查看更多歌单条目。';
const playlistSyncTableCollapseTooltip = '把对比表格恢复为普通高度。';
const playlistSyncExportTooltip = '导出当前筛选后的对比表格，内容与当前同步状态筛选一致。';
const playlistSyncAddMissingTooltip =
    '联网解析：把当前筛选中本地无、歌单有且能通过 BeatSaver ID/hash 解析的歌曲加入本次；不下载、不修改歌单。';
const playlistSyncDownloadMissingTooltip =
    '联网下载：解析当前筛选中本地无、歌单有的歌曲并下载 ZIP；不安装、不修改歌单。';
const playlistSyncInstallMissingTooltip =
    '联网安装：解析当前筛选中本地无、歌单有的歌曲并下载安装到安装目录；不修改歌单。';
const playlistSyncSelectCurrentTooltip = '选择当前筛选结果中的所有歌单条目。';
const playlistSyncSelectMissingEggTooltip = '选择本地目录存在但缺少 .egg 音频文件的歌单条目。';
const playlistSyncSelectNameMismatchTooltip =
    '选择 BeatSaver 名称和本地 info.dat 歌名不一致的条目。';
const playlistSyncClearSelectionTooltip = '清空当前已选的歌单同步条目，不修改歌单或本地文件。';
const playlistSyncRemoveFromPlaylistTooltip =
    '仅移出歌单：备份并修改 .bplist，只移除所选条目，不删除本地歌曲目录。';
const playlistSyncBackupDeleteTooltip = '备份删除所选：备份歌单和本地歌曲目录后，删除所选本地歌曲并同步移出歌单。';
const playlistSyncLocalOnlyExportTooltip = '导出本地存在但不在当前歌单中的歌曲清单。';
const playlistSyncLocalOnlyAddToTargetsTooltip =
    '把本地存在但不在当前歌单中、且能识别 BeatSaver ID 的歌曲加入本次列表。';
const playlistSyncLocalOnlyAddToSkipTooltip =
    '把本地存在但不在当前歌单中、且能识别 BeatSaver ID 的歌曲加入跳过列表。';
const pickInstallDirectoryTooltip =
    '浏览安装目录：选择 Beat Saber CustomLevels 或目标安装目录。';
const pickLocalSongsDirectoryTooltip = '浏览本地歌曲：选择可优先复制的本地歌曲目录，可在输入框中配置多个目录。';
const pickGameDirectoryTooltip =
    '浏览游戏目录：选择 Beat Saber 根目录，用于检测 SongCore 和 PlaylistManager。';
const pickSkipExistingDirectoryTooltip = '浏览跳过目录：选择用于“跳过已有”检查的额外目录。';
const androidDirectoryTooltip =
    'Android 目录：打开 Android 目录授权，用于写入 Quest/Android 目录。';
const pickZipDownloadDirectoryTooltip = '浏览 ZIP 目录：选择 ZIP 下载保存目录。';
const pickPlaylistFileTooltip = '选择歌单：选择要读取、安装、同步或覆盖的本地 .bplist 文件。';
const pickPlaylistSaveTooltip = '保存到：选择导出 .bplist 或列表文件的保存位置。';
const pickPlaylistCoverTooltip = '选择封面：选择本地图片作为导出 .bplist 的封面。';
const exportPlaylistTooltip = '导出歌单：把当前本次歌曲列表导出为 .bplist，不下载歌曲。';
const installPlaylistTooltip = '安装歌单：读取本地 .bplist 并按当前下载/安装设置批量安装。';
const playlistToTargetsTooltip = '歌单入本次：读取本地 .bplist 并加入本次歌曲列表，不下载、不安装。';
const pickArchiveSaveTooltip = 'ZIP 保存到：选择“打包 ZIP”的输出文件路径。';
const exportInstalledZipTooltip = '打包 ZIP：把当前本次或已安装歌曲打包为 ZIP；缺本地文件时可能联网补齐。';
const acgIncludePresetTooltip = 'ACG 白名单：填入常用 ACG/二次元封面包含标签预设。';
const acgExcludePresetTooltip = 'ACG 黑名单：填入常用非目标封面排除标签预设。';
const clearFiltersTooltip = '清空筛选：重置当前搜索/高级筛选条件，不清空本次歌曲列表。';
const previousPageTooltip = '上一页：切换到当前结果源的上一页，不下载或修改列表。';
const nextPageTooltip = '下一页：切换到当前结果源的下一页，不下载或修改列表。';
const manualPickListTooltip = '读取列表：选择本地文本列表文件，并把内容读入手动输入框。';
const manualImportTargetsTooltip = '列表入本次：从已读取的文本列表导入 BeatSaver ID/链接到本次歌曲列表。';
const manualExportResultsTooltip = '导出结果：把当前结果列表导出为本地文本文件，不下载歌曲。';
const manualAddToTargetsTooltip = '加入本次：把手动输入的 BeatSaver ID/链接加入本次歌曲列表，不下载歌曲。';
const manualAddToSkipTooltip = '加入跳过：把手动输入的 BeatSaver ID/链接加入跳过列表。';
const localCachePickTooltip = '选择数据缓存：选择本地 LocalCache.saver 文件。';
const localCacheReadTooltip = '读取数据缓存：离线读取 LocalCache.saver，并用于本地缓存搜索和筛选。';
const localCacheRebuildTooltip =
    '联网维护：从 BeatSaver /maps/latest 重新构建 LocalCache.saver，会限速并支持暂停/继续。';
const localCacheResumeTooltip =
    '联网维护：继续未完成的 BeatSaver 快照构建；没有断点且缓存未过期时会复用本地文件。';
const localCacheIncrementalTooltip =
    '联网维护：需要已有 LocalCache.saver；按最新时间从 BeatSaver 拉取新增/更新谱面。';
const localCacheDeletedAuditTooltip =
    '联网审计：需要已有 LocalCache.saver；读取 BeatSaver 删除候选并标记命中项；不会修改缓存。';
const localCacheDeletedExportTooltip =
    '导出删除：导出最近一次审计删除候选报告，不修改 LocalCache.saver。';
const localCachePauseTooltip = '暂停快照：请求正在构建的 LocalCache.saver 快照任务在安全点暂停。';
const localCacheAddToTargetsTooltip = '数据入本次：把当前本地缓存筛选结果加入本次列表，不下载歌曲。';
const localCacheAddToSkipTooltip = '数据入跳过：把当前本地缓存筛选结果加入跳过列表。';
const localCacheExportTooltip = '导出数据：把当前本地缓存筛选结果导出为文本列表。';
const localCacheSummaryTooltip = '导出摘要：导出当前 LocalCache.saver 的统计摘要。';
const localCacheClearTooltip = '清空数据：只清空当前已读取的本地缓存结果，不删除 LocalCache.saver。';
const hashCacheExportTooltip = '导出Hash：导出本地 BeatSaver hash 详情缓存。';
const hashCacheClearTooltip =
    '清空Hash：清空本地 hash 详情缓存文件，执行前会确认；不影响 LocalCache.saver。';
const coverLabelCacheExportTooltip = '导出封面缓存：把当前封面标签识别缓存保存为 JSON 文件。';
const coverLabelCacheClearTooltip =
    '清空封面缓存：删除本地封面标签缓存文件，执行前会确认；不删除歌曲或 LocalCache.saver。';

class _InstalledPanel extends StatelessWidget {
  const _InstalledPanel({
    required this.entries,
    required this.filterController,
    required this.filterMode,
    required this.directoryNameTemplate,
    required this.asciiDirectoryNames,
    required this.gameDirectoryStatus,
    required this.songCoreFolderEntries,
    required this.songCoreLastBackupDirectory,
    required this.busy,
    required this.onFilterModeChanged,
    required this.onAddToTargets,
    required this.onAddFilteredToTargets,
    required this.onAddFilteredToSkip,
    required this.onExportFiltered,
    required this.onExportFilteredPlaylist,
    required this.onExportFavoritesPlaylist,
    required this.onInspectGameDirectory,
    required this.onRefreshSongCoreFolderEntries,
    required this.onSaveSongCoreFolderList,
    required this.onRemoveSongCoreFolderEntry,
    required this.onCopySongCoreFoldersFilePath,
    required this.onCopySongCoreBackupDirectory,
    required this.onDelete,
    required this.onApplyPathCorrection,
    required this.selectedPathCorrectionKeys,
    required this.onSelectedPathCorrectionKeysChanged,
    required this.onApplySelectedPathCorrections,
    required this.selectedDuplicateKeys,
    required this.onSelectedDuplicateKeysChanged,
    required this.onDeleteSelectedDuplicates,
  });

  final List<InstalledSongEntry> entries;
  final TextEditingController filterController;
  final InstalledFilterModeForTest filterMode;
  final String directoryNameTemplate;
  final bool asciiDirectoryNames;
  final BeatSaberGameDirectoryStatus? gameDirectoryStatus;
  final List<SongCoreFolderEntry> songCoreFolderEntries;
  final String? songCoreLastBackupDirectory;
  final bool busy;
  final ValueChanged<InstalledFilterModeForTest> onFilterModeChanged;
  final Future<void> Function(InstalledSongEntry entry) onAddToTargets;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onAddFilteredToTargets;
  final ValueChanged<List<InstalledSongEntry>> onAddFilteredToSkip;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onExportFiltered;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onExportFilteredPlaylist;
  final Future<void> Function() onExportFavoritesPlaylist;
  final Future<void> Function() onInspectGameDirectory;
  final Future<void> Function() onRefreshSongCoreFolderEntries;
  final Future<void> Function() onSaveSongCoreFolderList;
  final Future<void> Function(SongCoreFolderEntry entry)
  onRemoveSongCoreFolderEntry;
  final Future<void> Function() onCopySongCoreFoldersFilePath;
  final Future<void> Function() onCopySongCoreBackupDirectory;
  final Future<void> Function(InstalledSongEntry entry) onDelete;
  final Future<void> Function(InstalledPathCorrection correction)
  onApplyPathCorrection;
  final Set<String> selectedPathCorrectionKeys;
  final ValueChanged<Set<String>> onSelectedPathCorrectionKeysChanged;
  final Future<void> Function(List<InstalledPathCorrection> corrections)
  onApplySelectedPathCorrections;
  final Set<String> selectedDuplicateKeys;
  final ValueChanged<Set<String>> onSelectedDuplicateKeysChanged;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onDeleteSelectedDuplicates;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '已安装',
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: filterController,
        builder: (context, value, _) {
          final filtered = _filterInstalledEntries(
            entries,
            query: value.text,
            mode: filterMode,
          );
          final summary = installedSummaryForTest(
            entries.map(installedEntrySnapshotForTest),
            filteredCount: filtered.length,
          );
          final filteredWithIds = filtered
              .where((entry) => entry.mapId != null && entry.mapId!.isNotEmpty)
              .toList(growable: false);
          final exportablePlaylistEntries = filteredWithIds
              .where((entry) => entry.hasInfoDat)
              .toList(growable: false);
          final duplicateGroups = findInstalledDuplicateGroups(entries);
          final corrections = suggestInstalledPathCorrections(
            entries,
            template: directoryNameTemplate,
            asciiOnly: asciiDirectoryNames,
          );
          final gameStatus = gameDirectoryStatus;
          final songCoreActionState = songCoreFolderActionStateForTest(
            busy: busy,
            isBeatSaberDirectory: gameStatus?.isBeatSaberDirectory ?? false,
            isSongCoreInstalled: gameStatus?.isSongCoreInstalled ?? false,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(summary.totalLabel)),
                  Chip(label: Text(summary.filteredLabel)),
                  Chip(label: Text(summary.normalLabel)),
                  if (summary.missingInfo > 0)
                    Chip(label: Text(summary.missingInfoLabel)),
                  if (summary.missingInfoWithAudio > 0)
                    Chip(label: Text(summary.missingInfoWithAudioLabel)),
                  if (summary.missingId > 0)
                    Chip(label: Text(summary.missingIdLabel)),
                  if (duplicateGroups.isNotEmpty)
                    Chip(label: Text('重复 ${duplicateGroups.length} 组')),
                  if (corrections.isNotEmpty)
                    Chip(label: Text('路径建议 ${corrections.length}')),
                ],
              ),
              const SizedBox(height: 12),
              _SongCoreControls(
                gameStatus: gameStatus,
                songCoreActionState: songCoreActionState,
                songCoreFolderCount: songCoreFolderEntries.length,
                hasBackupDirectory:
                    songCoreLastBackupDirectory != null &&
                    songCoreLastBackupDirectory!.isNotEmpty,
                busy: busy,
                onInspectGameDirectory: onInspectGameDirectory,
                onRefreshSongCoreFolderEntries: onRefreshSongCoreFolderEntries,
                onSaveSongCoreFolderList: onSaveSongCoreFolderList,
                onCopySongCoreFoldersFilePath: onCopySongCoreFoldersFilePath,
                onCopySongCoreBackupDirectory: onCopySongCoreBackupDirectory,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: filterController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: '过滤已安装',
                        hintText: '歌名 / 作者 / 制作者 / ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<InstalledFilterModeForTest>(
                      initialValue: filterMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '状态',
                        border: OutlineInputBorder(),
                      ),
                      items: InstalledFilterModeForTest.values
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(
                                installedFilterModeLabelForTest(mode),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: busy
                          ? null
                          : (mode) {
                              if (mode != null) {
                                onFilterModeChanged(mode);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Tooltip(
                      message: installedAddFilteredToTargetsTooltip,
                      child: OutlinedButton.icon(
                        onPressed:
                            installedFilteredIdActionEnabledForTest(
                              entryCount: filteredWithIds.length,
                              busy: busy,
                            )
                            ? () => onAddFilteredToTargets(filteredWithIds)
                            : null,
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text('当前加入本次(${filteredWithIds.length})'),
                      ),
                    ),
                    Tooltip(
                      message: installedAddFilteredToSkipTooltip,
                      child: OutlinedButton.icon(
                        onPressed:
                            installedFilteredIdActionEnabledForTest(
                              entryCount: filteredWithIds.length,
                              busy: busy,
                            )
                            ? () => onAddFilteredToSkip(filteredWithIds)
                            : null,
                        icon: const Icon(Icons.skip_next),
                        label: Text('当前加入跳过(${filteredWithIds.length})'),
                      ),
                    ),
                    Tooltip(
                      message: installedExportCurrentTooltip,
                      child: OutlinedButton.icon(
                        onPressed:
                            installedExportCurrentEnabledForTest(
                              filteredCount: filtered.length,
                              busy: busy,
                            )
                            ? () => onExportFiltered(filtered)
                            : null,
                        icon: const Icon(Icons.ios_share),
                        label: Text('导出当前(${filtered.length})'),
                      ),
                    ),
                    Tooltip(
                      message: installedExportPlaylistTooltip,
                      child: OutlinedButton.icon(
                        onPressed:
                            installedExportPlaylistEnabledForTest(
                              exportableCount: exportablePlaylistEntries.length,
                              busy: busy,
                            )
                            ? () => onExportFilteredPlaylist(filtered)
                            : null,
                        icon: const Icon(Icons.featured_play_list_outlined),
                        label: Text(
                          '导出歌单(${exportablePlaylistEntries.length})',
                        ),
                      ),
                    ),
                    Tooltip(
                      message: installedExportFavoritesTooltip,
                      child: OutlinedButton.icon(
                        onPressed:
                            installedFavoritesExportEnabledForTest(busy: busy)
                            ? onExportFavoritesPlaylist
                            : null,
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('导出收藏'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (songCoreFolderEntries.isNotEmpty) ...[
                _SongCoreFolderList(
                  entries: songCoreFolderEntries,
                  busy: busy,
                  onRemove: onRemoveSongCoreFolderEntry,
                ),
                const SizedBox(height: 12),
              ],
              if (duplicateGroups.isNotEmpty || corrections.isNotEmpty) ...[
                _InstalledLibraryAdvice(
                  duplicateGroups: duplicateGroups,
                  corrections: corrections,
                  busy: busy,
                  onApplyPathCorrection: onApplyPathCorrection,
                  selectedPathCorrectionKeys: selectedPathCorrectionKeys,
                  onSelectedPathCorrectionKeysChanged:
                      onSelectedPathCorrectionKeysChanged,
                  onApplySelectedPathCorrections:
                      onApplySelectedPathCorrections,
                  selectedDuplicateKeys: selectedDuplicateKeys,
                  onSelectedDuplicateKeysChanged:
                      onSelectedDuplicateKeysChanged,
                  onDeleteSelectedDuplicates: onDeleteSelectedDuplicates,
                ),
                const SizedBox(height: 12),
              ],
              for (final entry in filtered)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.title ?? entry.directoryName),
                  subtitle: Text(
                    '${entry.mapId ?? '-'} | '
                    '${entry.info?.songAuthorName ?? '-'} | '
                    '${entry.info?.levelAuthorName ?? '-'} | '
                    '${installedEntryStatusLabelForTest(installedEntrySnapshotForTest(entry))}\n'
                    '目录：${entry.directoryName}\n'
                    '路径：${entry.directory.path}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '加入本次',
                        onPressed: busy || entry.mapId == null
                            ? null
                            : () => onAddToTargets(entry),
                        icon: const Icon(Icons.playlist_add),
                      ),
                      IconButton(
                        tooltip: installedSingleDeleteTooltip,
                        onPressed: busy ? null : () => onDelete(entry),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              if (entries.isEmpty)
                const _EmptyState(text: '扫描目录后会在这里显示已安装歌曲。')
              else if (filtered.isEmpty)
                const _EmptyState(text: '没有匹配的已安装歌曲。'),
            ],
          );
        },
      ),
    );
  }
}

class _InstalledLibraryAdvice extends StatefulWidget {
  const _InstalledLibraryAdvice({
    required this.duplicateGroups,
    required this.corrections,
    required this.busy,
    required this.onApplyPathCorrection,
    required this.selectedPathCorrectionKeys,
    required this.onSelectedPathCorrectionKeysChanged,
    required this.onApplySelectedPathCorrections,
    required this.selectedDuplicateKeys,
    required this.onSelectedDuplicateKeysChanged,
    required this.onDeleteSelectedDuplicates,
  });

  final List<InstalledDuplicateGroup> duplicateGroups;
  final List<InstalledPathCorrection> corrections;
  final bool busy;
  final Future<void> Function(InstalledPathCorrection correction)
  onApplyPathCorrection;
  final Set<String> selectedPathCorrectionKeys;
  final ValueChanged<Set<String>> onSelectedPathCorrectionKeysChanged;
  final Future<void> Function(List<InstalledPathCorrection> corrections)
  onApplySelectedPathCorrections;
  final Set<String> selectedDuplicateKeys;
  final ValueChanged<Set<String>> onSelectedDuplicateKeysChanged;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onDeleteSelectedDuplicates;

  @override
  State<_InstalledLibraryAdvice> createState() =>
      _InstalledLibraryAdviceState();
}

class _InstalledLibraryAdviceState extends State<_InstalledLibraryAdvice> {
  InstalledPathCorrectionFilterMode _pathCorrectionFilterMode =
      InstalledPathCorrectionFilterMode.abnormal;

  @override
  Widget build(BuildContext context) {
    final duplicateCandidates = installedDuplicateRemovalCandidates(
      widget.duplicateGroups,
    );
    final selectedDuplicateEntries = duplicateCandidates
        .where(
          (entry) => widget.selectedDuplicateKeys.contains(
            installedDuplicateEntryKeyForTest(entry),
          ),
        )
        .toList(growable: false);
    final visibleCorrections = filterInstalledPathCorrectionsForTest(
      widget.corrections,
      _pathCorrectionFilterMode,
    );
    final selectedVisibleCorrections = visibleCorrections
        .where(
          (correction) => widget.selectedPathCorrectionKeys.contains(
            installedPathCorrectionKeyForTest(correction),
          ),
        )
        .toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('本地曲库管理'),
                if (widget.duplicateGroups.isNotEmpty)
                  Chip(label: Text('重复 ${widget.duplicateGroups.length} 组')),
                if (widget.corrections.isNotEmpty)
                  Chip(
                    label: Text(
                      '路径建议 ${widget.corrections.length}，当前 ${visibleCorrections.length}',
                    ),
                  ),
                if (widget.selectedPathCorrectionKeys.isNotEmpty)
                  Chip(
                    label: Text(
                      installedSelectionSummaryForTest(
                        label: '',
                        selectedCount: widget.selectedPathCorrectionKeys.length,
                        validCount: selectedVisibleCorrections.length,
                      ),
                    ),
                  ),
                if (widget.selectedDuplicateKeys.isNotEmpty)
                  Chip(
                    label: Text(
                      installedSelectionSummaryForTest(
                        label: '重复',
                        selectedCount: widget.selectedDuplicateKeys.length,
                        validCount: selectedDuplicateEntries.length,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.duplicateGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Tooltip(
                    message: duplicateSelectTooltip,
                    child: OutlinedButton.icon(
                      onPressed:
                          installedVisibleSelectionEnabledForTest(
                            visibleCount: duplicateCandidates.length,
                            busy: widget.busy,
                          )
                          ? () {
                              final keys = {
                                ...widget.selectedDuplicateKeys,
                                for (final entry in duplicateCandidates)
                                  installedDuplicateEntryKeyForTest(entry),
                              };
                              widget.onSelectedDuplicateKeysChanged(keys);
                            }
                          : null,
                      icon: const Icon(Icons.select_all),
                      label: Text('选择重复(${duplicateCandidates.length})'),
                    ),
                  ),
                  Tooltip(
                    message: duplicateClearTooltip,
                    child: OutlinedButton.icon(
                      onPressed:
                          installedSelectionActionEnabledForTest(
                            selectedCount: widget.selectedDuplicateKeys.length,
                            busy: widget.busy,
                          )
                          ? () =>
                                widget.onSelectedDuplicateKeysChanged(const {})
                          : null,
                      icon: const Icon(Icons.clear),
                      label: const Text('清空重复选择'),
                    ),
                  ),
                  Tooltip(
                    message: duplicateBackupDeleteTooltip,
                    child: FilledButton.icon(
                      onPressed:
                          installedSelectionActionEnabledForTest(
                            selectedCount: selectedDuplicateEntries.length,
                            busy: widget.busy,
                          )
                          ? () => widget.onDeleteSelectedDuplicates(
                              selectedDuplicateEntries,
                            )
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      label: Text('备份删除重复(${selectedDuplicateEntries.length})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final group in widget.duplicateGroups.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_installedDuplicateKindLabel(group.kind)} ${group.value}：'
                    '${group.entries.map((entry) => entry.directoryName).join(' / ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              _InstalledAdviceScrollBox(
                enabled: duplicateCandidates.length > 5,
                child: Column(
                  children: [
                    for (final entry in duplicateCandidates)
                      _InstalledAdviceRow(
                        checked: widget.selectedDuplicateKeys.contains(
                          installedDuplicateEntryKeyForTest(entry),
                        ),
                        busy: widget.busy,
                        text: '建议删除：${entry.directoryName}',
                        onChanged: (selected) {
                          final key = installedDuplicateEntryKeyForTest(entry);
                          final keys = {...widget.selectedDuplicateKeys};
                          if (selected ?? false) {
                            keys.add(key);
                          } else {
                            keys.remove(key);
                          }
                          widget.onSelectedDuplicateKeysChanged(keys);
                        },
                      ),
                  ],
                ),
              ),
              if (widget.duplicateGroups.length > 3)
                Text(
                  '还有 ${widget.duplicateGroups.length - 3} 组重复未显示。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (duplicateCandidates.length > 5)
                Text(
                  installedAdviceScrollHintForTest(
                    label: '重复候选',
                    count: duplicateCandidates.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            if (widget.corrections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child:
                        DropdownButtonFormField<
                          InstalledPathCorrectionFilterMode
                        >(
                          initialValue: _pathCorrectionFilterMode,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '路径建议筛选',
                            border: OutlineInputBorder(),
                          ),
                          items: InstalledPathCorrectionFilterMode.values
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(
                                    installedPathCorrectionFilterModeLabelForTest(
                                      mode,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: widget.busy
                              ? null
                              : (mode) {
                                  if (mode != null) {
                                    setState(() {
                                      _pathCorrectionFilterMode = mode;
                                    });
                                  }
                                },
                        ),
                  ),
                  Tooltip(
                    message: pathCorrectionSelectTooltip,
                    child: OutlinedButton.icon(
                      onPressed:
                          installedVisibleSelectionEnabledForTest(
                            visibleCount: visibleCorrections.length,
                            busy: widget.busy,
                          )
                          ? () {
                              final keys = {
                                ...widget.selectedPathCorrectionKeys,
                                for (final correction in visibleCorrections)
                                  installedPathCorrectionKeyForTest(correction),
                              };
                              widget.onSelectedPathCorrectionKeysChanged(keys);
                            }
                          : null,
                      icon: const Icon(Icons.select_all),
                      label: Text('选择建议(${visibleCorrections.length})'),
                    ),
                  ),
                  Tooltip(
                    message: pathCorrectionClearTooltip,
                    child: OutlinedButton.icon(
                      onPressed:
                          installedSelectionActionEnabledForTest(
                            selectedCount:
                                widget.selectedPathCorrectionKeys.length,
                            busy: widget.busy,
                          )
                          ? () => widget.onSelectedPathCorrectionKeysChanged(
                              const {},
                            )
                          : null,
                      icon: const Icon(Icons.clear),
                      label: const Text('清空选择'),
                    ),
                  ),
                  Tooltip(
                    message: pathCorrectionBatchRenameTooltip,
                    child: FilledButton.icon(
                      onPressed:
                          installedSelectionActionEnabledForTest(
                            selectedCount: selectedVisibleCorrections.length,
                            busy: widget.busy,
                          )
                          ? () => widget.onApplySelectedPathCorrections(
                              selectedVisibleCorrections,
                            )
                          : null,
                      icon: const Icon(Icons.drive_file_rename_outline),
                      label: Text(
                        '批量重命名(${selectedVisibleCorrections.length})',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (visibleCorrections.isEmpty)
                Text(
                  '当前筛选下没有路径建议；切换到“全部”可查看命名模板差异。',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                _InstalledAdviceScrollBox(
                  enabled: visibleCorrections.length > 5,
                  child: Column(
                    children: [
                      for (final correction in visibleCorrections)
                        _InstalledAdviceRow(
                          checked: widget.selectedPathCorrectionKeys.contains(
                            installedPathCorrectionKeyForTest(correction),
                          ),
                          busy: widget.busy,
                          text:
                              '${correction.entry.directoryName} -> '
                              '${correction.expectedDirectoryName}',
                          action: Tooltip(
                            message: pathCorrectionSingleRenameTooltip,
                            child: TextButton.icon(
                              onPressed: widget.busy
                                  ? null
                                  : () => widget.onApplyPathCorrection(
                                      correction,
                                    ),
                              icon: const Icon(Icons.drive_file_rename_outline),
                              label: const Text('重命名'),
                            ),
                          ),
                          onChanged: (selected) {
                            final key = installedPathCorrectionKeyForTest(
                              correction,
                            );
                            final keys = {...widget.selectedPathCorrectionKeys};
                            if (selected ?? false) {
                              keys.add(key);
                            } else {
                              keys.remove(key);
                            }
                            widget.onSelectedPathCorrectionKeysChanged(keys);
                          },
                        ),
                    ],
                  ),
                ),
              if (visibleCorrections.length > 5)
                Text(
                  installedAdviceScrollHintForTest(
                    label: '路径建议',
                    count: visibleCorrections.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstalledAdviceScrollBox extends StatelessWidget {
  const _InstalledAdviceScrollBox({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: enabled ? 360 : double.infinity),
      child: SingleChildScrollView(child: child),
    );
  }
}

class _InstalledAdviceRow extends StatelessWidget {
  const _InstalledAdviceRow({
    required this.checked,
    required this.busy,
    required this.text,
    required this.onChanged,
    this.action,
  });

  final bool checked;
  final bool busy;
  final String text;
  final ValueChanged<bool?> onChanged;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: checked, onChanged: busy ? null : onChanged),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (action != null) ...[action!],
        ],
      ),
    );
  }
}

bool _installedPathCorrectionIsAbnormal(InstalledPathCorrection correction) {
  return installedPathCorrectionIsAbnormalForTest(correction);
}

String _installedDuplicateKindLabel(InstalledDuplicateKind kind) {
  return installedDuplicateKindLabelForTest(kind);
}

class _SongCoreControls extends StatelessWidget {
  const _SongCoreControls({
    required this.gameStatus,
    required this.songCoreActionState,
    required this.songCoreFolderCount,
    required this.hasBackupDirectory,
    required this.busy,
    required this.onInspectGameDirectory,
    required this.onRefreshSongCoreFolderEntries,
    required this.onSaveSongCoreFolderList,
    required this.onCopySongCoreFoldersFilePath,
    required this.onCopySongCoreBackupDirectory,
  });

  final BeatSaberGameDirectoryStatus? gameStatus;
  final SongCoreFolderActionState songCoreActionState;
  final int songCoreFolderCount;
  final bool hasBackupDirectory;
  final bool busy;
  final Future<void> Function() onInspectGameDirectory;
  final Future<void> Function() onRefreshSongCoreFolderEntries;
  final Future<void> Function() onSaveSongCoreFolderList;
  final Future<void> Function() onCopySongCoreFoldersFilePath;
  final Future<void> Function() onCopySongCoreBackupDirectory;

  @override
  Widget build(BuildContext context) {
    final status = gameStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('SongCore'),
            if (status == null)
              const Chip(label: Text('游戏目录未检测'))
            else ...[
              Builder(
                builder: (context) {
                  final chipState = gameDirectoryChipStateForTest(
                    isBeatSaberDirectory: status.isBeatSaberDirectory,
                    path: status.gameDirectory.path,
                  );
                  final chip = Chip(label: Text(chipState.label));
                  return chipState.tooltip.isEmpty
                      ? chip
                      : Tooltip(message: chipState.tooltip, child: chip);
                },
              ),
              Builder(
                builder: (context) {
                  final chipState = songCoreInstallChipStateForTest(
                    installed: status.isSongCoreInstalled,
                    path: status.songCorePluginFile.path,
                  );
                  final chip = Chip(label: Text(chipState.label));
                  return chipState.tooltip.isEmpty
                      ? chip
                      : Tooltip(message: chipState.tooltip, child: chip);
                },
              ),
              Builder(
                builder: (context) {
                  final chipState = playlistManagerInstallChipStateForTest(
                    installed: status.isPlaylistManagerInstalled,
                    path: status.playlistManagerPluginFile.path,
                  );
                  final chip = Chip(label: Text(chipState.label));
                  return chipState.tooltip.isEmpty
                      ? chip
                      : Tooltip(message: chipState.tooltip, child: chip);
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tooltip(
                message:
                    gameDirectoryInspectDisabledReasonForTest(
                      busy: busy,
                    ).isEmpty
                    ? gameDirectoryInspectTooltip
                    : gameDirectoryInspectDisabledReasonForTest(busy: busy),
                child: OutlinedButton.icon(
                  onPressed: gameDirectoryInspectEnabledForTest(busy: busy)
                      ? onInspectGameDirectory
                      : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('检测游戏目录'),
                ),
              ),
              Tooltip(
                message: songCoreActionState.enabled
                    ? songCoreReadTooltip
                    : songCoreActionState.disabledReason,
                child: OutlinedButton.icon(
                  onPressed: songCoreActionState.enabled
                      ? onRefreshSongCoreFolderEntries
                      : null,
                  icon: const Icon(Icons.list_alt),
                  label: Text('读取列表($songCoreFolderCount)'),
                ),
              ),
              Tooltip(
                message: songCoreActionState.enabled
                    ? songCoreSaveTooltip
                    : songCoreActionState.disabledReason,
                child: FilledButton.icon(
                  onPressed: songCoreActionState.enabled
                      ? onSaveSongCoreFolderList
                      : null,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('保存列表'),
                ),
              ),
              Tooltip(
                message: songCoreCopyXmlTooltip,
                child: OutlinedButton.icon(
                  onPressed: status == null
                      ? null
                      : onCopySongCoreFoldersFilePath,
                  icon: const Icon(Icons.copy),
                  label: const Text('复制XML路径'),
                ),
              ),
              Tooltip(
                message: songCoreCopyBackupTooltip,
                child: OutlinedButton.icon(
                  onPressed: hasBackupDirectory
                      ? onCopySongCoreBackupDirectory
                      : null,
                  icon: const Icon(Icons.copy_all),
                  label: const Text('复制备份目录'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SongCoreFolderList extends StatelessWidget {
  const _SongCoreFolderList({
    required this.entries,
    required this.busy,
    required this.onRemove,
  });

  final List<SongCoreFolderEntry> entries;
  final bool busy;
  final Future<void> Function(SongCoreFolderEntry entry) onRemove;

  @override
  Widget build(BuildContext context) {
    final listHeight = entries.length <= 3 ? null : 360.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('SongCore 保存列表'),
                Chip(label: Text('${entries.length} 项')),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: listHeight ?? double.infinity,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      if (index > 0) const Divider(height: 1),
                      _SongCoreFolderTile(
                        entry: entries[index],
                        busy: busy,
                        onRemove: onRemove,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (entries.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  songCoreFolderListScrollHintForTest(count: entries.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SongCoreFolderTile extends StatelessWidget {
  const _SongCoreFolderTile({
    required this.entry,
    required this.busy,
    required this.onRemove,
  });

  final SongCoreFolderEntry entry;
  final bool busy;
  final Future<void> Function(SongCoreFolderEntry entry) onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(entry.name.isEmpty ? entry.path : entry.name),
      subtitle: Text(
        'Pack ${entry.pack} | WIP ${entry.wip ? '是' : '否'}\n'
        '路径：${entry.path}'
        '${entry.imagePath.isEmpty ? '' : '\n封面：${entry.imagePath}'}',
      ),
      isThreeLine: entry.imagePath.isNotEmpty,
      trailing: IconButton(
        tooltip: '移除保存列表条目',
        onPressed: songCoreFolderRemoveEnabledForTest(busy: busy)
            ? () => onRemove(entry)
            : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
    );
  }
}

class _PlaylistSyncPanel extends StatelessWidget {
  const _PlaylistSyncPanel({
    required this.entries,
    required this.localOnlyInstalledEntries,
    required this.selectedEntryKeys,
    required this.filterMode,
    required this.tableExpanded,
    required this.busy,
    required this.onFilterModeChanged,
    required this.onTableExpandedChanged,
    required this.onExport,
    required this.onExportLocalOnly,
    required this.onAddLocalOnlyToTargets,
    required this.onAddLocalOnlyToSkip,
    required this.onAddMissingToTargets,
    required this.onDownloadMissingZips,
    required this.onInstallMissing,
    required this.onDelete,
    required this.onRemoveFromPlaylist,
    required this.onEntrySelectionChanged,
    required this.onSelectEntries,
    required this.onClearEntries,
  });

  final List<PlaylistSyncEntry> entries;
  final List<InstalledSongEntry> localOnlyInstalledEntries;
  final Set<String> selectedEntryKeys;
  final PlaylistSyncFilterModeForTest filterMode;
  final bool tableExpanded;
  final bool busy;
  final ValueChanged<PlaylistSyncFilterModeForTest> onFilterModeChanged;
  final ValueChanged<bool> onTableExpandedChanged;
  final Future<void> Function(List<PlaylistSyncEntry> entries) onExport;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onExportLocalOnly;
  final Future<void> Function(List<InstalledSongEntry> entries)
  onAddLocalOnlyToTargets;
  final ValueChanged<List<InstalledSongEntry>> onAddLocalOnlyToSkip;
  final Future<void> Function(List<PlaylistSyncEntry> entries)
  onAddMissingToTargets;
  final Future<void> Function(List<PlaylistSyncEntry> entries)
  onDownloadMissingZips;
  final Future<void> Function(List<PlaylistSyncEntry> entries) onInstallMissing;
  final Future<void> Function(List<PlaylistSyncEntry> entries) onDelete;
  final Future<void> Function(List<PlaylistSyncEntry> entries)
  onRemoveFromPlaylist;
  final void Function(PlaylistSyncEntry entry, bool selected)
  onEntrySelectionChanged;
  final ValueChanged<List<PlaylistSyncEntry>> onSelectEntries;
  final ValueChanged<List<PlaylistSyncEntry>> onClearEntries;

  @override
  Widget build(BuildContext context) {
    final filtered = _filterPlaylistSyncEntries(entries, filterMode);
    final installed = entries.where((entry) => entry.isInstalled).length;
    final missing = entries.length - installed;
    final nameMatched = entries
        .where(
          (entry) => entry.matchType == PlaylistSyncMatchType.normalizedName,
        )
        .length;
    final hashMatched = entries
        .where((entry) => entry.matchType == PlaylistSyncMatchType.localHash)
        .length;
    final missingEgg = entries
        .where((entry) => entry.isInstalled && !entry.hasEgg)
        .length;
    final selectedAll = filtered
        .where((entry) {
          return selectedEntryKeys.contains(playlistSyncEntryKeyForTest(entry));
        })
        .toList(growable: false);
    final selectedInstalled = selectedAll
        .where((entry) => entry.isInstalled)
        .toList(growable: false);
    final missingEntries = filtered
        .where((entry) => !entry.isInstalled)
        .toList(growable: false);
    final missingEggEntries = filtered
        .where((entry) => entry.isInstalled && !entry.hasEgg)
        .toList(growable: false);
    final nameMismatchEntries = filtered
        .where(playlistSyncNameMismatchForTest)
        .toList(growable: false);
    final nameMismatches = filtered
        .where(playlistSyncNameMismatchForTest)
        .length;
    return _Section(
      title: '歌单同步',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text('条目 ${entries.length}')),
              Chip(label: Text('本地存在 $installed')),
              Chip(label: Text('缺失 $missing')),
              if (localOnlyInstalledEntries.isNotEmpty)
                Chip(
                  label: Text('本地有，歌单无 ${localOnlyInstalledEntries.length}'),
                ),
              if (nameMatched > 0) Chip(label: Text('名称辅助匹配 $nameMatched')),
              if (hashMatched > 0) Chip(label: Text('Hash匹配 $hashMatched')),
              if (missingEgg > 0) Chip(label: Text('缺 egg $missingEgg')),
              if (nameMismatches > 0)
                Chip(label: Text('名称不一致 $nameMismatches')),
              Chip(label: Text('已选 ${selectedAll.length}')),
              Tooltip(
                message: playlistSyncFilterTooltip,
                child: SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<PlaylistSyncFilterModeForTest>(
                    initialValue: filterMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '同步状态',
                      border: OutlineInputBorder(),
                    ),
                    items: PlaylistSyncFilterModeForTest.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(
                              playlistSyncFilterModeLabelForTest(mode),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (mode) {
                            if (mode != null) {
                              onFilterModeChanged(mode);
                            }
                          },
                  ),
                ),
              ),
              Tooltip(
                message: tableExpanded
                    ? playlistSyncTableCollapseTooltip
                    : playlistSyncTableExpandTooltip,
                child: OutlinedButton.icon(
                  onPressed: () => onTableExpandedChanged(!tableExpanded),
                  icon: Icon(
                    tableExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  label: Text(tableExpanded ? '收起表格' : '扩大表格'),
                ),
              ),
              Tooltip(
                message: playlistSyncExportTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncExportEnabledForTest(
                        filteredCount: filtered.length,
                        busy: busy,
                      )
                      ? () => onExport(filtered)
                      : null,
                  icon: const Icon(Icons.ios_share),
                  label: Text('导出当前(${filtered.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncAddMissingTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncSelectEnabledForTest(
                        deletableCount: missingEntries.length,
                        busy: busy,
                      )
                      ? () => onAddMissingToTargets(missingEntries)
                      : null,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: Text('缺失加入本次(${missingEntries.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncDownloadMissingTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncSelectEnabledForTest(
                        deletableCount: missingEntries.length,
                        busy: busy,
                      )
                      ? () => onDownloadMissingZips(missingEntries)
                      : null,
                  icon: const Icon(Icons.download_outlined),
                  label: Text('下载缺失(${missingEntries.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncInstallMissingTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncSelectEnabledForTest(
                        deletableCount: missingEntries.length,
                        busy: busy,
                      )
                      ? () => onInstallMissing(missingEntries)
                      : null,
                  icon: const Icon(Icons.install_desktop_outlined),
                  label: Text('安装缺失(${missingEntries.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncSelectCurrentTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncSelectEnabledForTest(
                        deletableCount: filtered.length,
                        busy: busy,
                      )
                      ? () => onSelectEntries(filtered)
                      : null,
                  icon: const Icon(Icons.select_all),
                  label: Text('选择当前(${filtered.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncSelectMissingEggTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncSelectEnabledForTest(
                        deletableCount: missingEggEntries.length,
                        busy: busy,
                      )
                      ? () => onSelectEntries(missingEggEntries)
                      : null,
                  icon: const Icon(Icons.music_off_outlined),
                  label: Text('选择缺 egg(${missingEggEntries.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncSelectNameMismatchTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncSelectEnabledForTest(
                        deletableCount: nameMismatchEntries.length,
                        busy: busy,
                      )
                      ? () => onSelectEntries(nameMismatchEntries)
                      : null,
                  icon: const Icon(Icons.drive_file_rename_outline),
                  label: Text('选择名称不一致(${nameMismatchEntries.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncClearSelectionTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncClearSelectionEnabledForTest(
                        selectedCount: selectedAll.length,
                        busy: busy,
                      )
                      ? () => onClearEntries(selectedAll)
                      : null,
                  icon: const Icon(Icons.deselect),
                  label: Text('清空所选(${selectedAll.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncRemoveFromPlaylistTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncPlaylistRemoveEnabledForTest(
                        selectedCount: selectedAll.length,
                        busy: busy,
                      )
                      ? () => onRemoveFromPlaylist(selectedAll)
                      : null,
                  icon: const Icon(Icons.playlist_remove),
                  label: Text('仅移出歌单(${selectedAll.length})'),
                ),
              ),
              Tooltip(
                message: playlistSyncBackupDeleteTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      playlistSyncInstalledDeleteEnabledForTest(
                        selectedInstalledCount: selectedInstalled.length,
                        busy: busy,
                      )
                      ? () => onDelete(selectedInstalled)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('备份删除所选(${selectedInstalled.length})'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (localOnlyInstalledEntries.isNotEmpty) ...[
            _PlaylistSyncLocalOnlyList(
              entries: localOnlyInstalledEntries,
              busy: busy,
              onExport: onExportLocalOnly,
              onAddToTargets: onAddLocalOnlyToTargets,
              onAddToSkip: onAddLocalOnlyToSkip,
            ),
            const SizedBox(height: 12),
          ],
          if (entries.isEmpty)
            const _EmptyState(text: '选择歌单和安装目录后，可扫描歌单与本地歌曲的差异。')
          else if (filtered.isEmpty)
            const _EmptyState(text: '没有匹配的歌单同步条目。')
          else
            _PlaylistSyncComparisonTable(
              entries: filtered,
              selectedEntryKeys: selectedEntryKeys,
              expanded: tableExpanded,
              enabled: !busy,
              onChanged: onEntrySelectionChanged,
            ),
        ],
      ),
    );
  }
}

class _PlaylistSyncTableCell extends StatelessWidget {
  const _PlaylistSyncTableCell({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle.merge(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PlaylistSyncCellText extends StatelessWidget {
  const _PlaylistSyncCellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}

class _PlaylistSyncStatusCell extends StatelessWidget {
  const _PlaylistSyncStatusCell({required this.entry});

  final PlaylistSyncEntry entry;

  @override
  Widget build(BuildContext context) {
    final mismatch = playlistSyncNameMismatchForTest(entry);
    final reason = playlistSyncMissingReasonForTest(entry);
    final status = mismatch
        ? '名称不一致'
        : entry.isInstalled
        ? '本地存在'
        : '缺失：$reason';
    if (!mismatch) {
      return _PlaylistSyncCellText(status);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'BeatSaver 名称与本地 info.dat 歌名不一致',
          child: Icon(
            Icons.warning_amber,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 4),
        const Text('名称不一致'),
      ],
    );
  }
}

class _PlaylistSyncLocalOnlyList extends StatelessWidget {
  const _PlaylistSyncLocalOnlyList({
    required this.entries,
    required this.busy,
    required this.onExport,
    required this.onAddToTargets,
    required this.onAddToSkip,
  });

  final List<InstalledSongEntry> entries;
  final bool busy;
  final Future<void> Function(List<InstalledSongEntry> entries) onExport;
  final Future<void> Function(List<InstalledSongEntry> entries) onAddToTargets;
  final ValueChanged<List<InstalledSongEntry>> onAddToSkip;

  @override
  Widget build(BuildContext context) {
    final entriesWithIds = entries
        .where((entry) => entry.mapId != null && entry.mapId!.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '本地有，歌单无歌曲 ${entries.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Tooltip(
              message: playlistSyncLocalOnlyExportTooltip,
              child: OutlinedButton.icon(
                onPressed:
                    installedExportCurrentEnabledForTest(
                      filteredCount: entries.length,
                      busy: busy,
                    )
                    ? () => onExport(entries)
                    : null,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text('导出本地有，歌单无(${entries.length})'),
              ),
            ),
            Tooltip(
              message: playlistSyncLocalOnlyAddToTargetsTooltip,
              child: OutlinedButton.icon(
                onPressed:
                    installedFilteredIdActionEnabledForTest(
                      entryCount: entriesWithIds.length,
                      busy: busy,
                    )
                    ? () => onAddToTargets(entriesWithIds)
                    : null,
                icon: const Icon(Icons.playlist_add_check),
                label: Text('加入本次(${entriesWithIds.length})'),
              ),
            ),
            Tooltip(
              message: playlistSyncLocalOnlyAddToSkipTooltip,
              child: OutlinedButton.icon(
                onPressed:
                    installedFilteredIdActionEnabledForTest(
                      entryCount: entriesWithIds.length,
                      busy: busy,
                    )
                    ? () => onAddToSkip(entriesWithIds)
                    : null,
                icon: const Icon(Icons.skip_next),
                label: Text('加入跳过(${entriesWithIds.length})'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final entry in entries.take(5))
          Text(
            '${entry.title ?? entry.directoryName} | ID ${entry.mapId ?? '-'}',
          ),
        if (entries.length > 5) Text('还有 ${entries.length - 5} 个本地有，歌单无歌曲未显示。'),
      ],
    );
  }
}

Widget playlistSyncComparisonTableForTest({
  required List<PlaylistSyncEntry> entries,
  Set<String> selectedEntryKeys = const {},
  bool expanded = false,
  bool enabled = true,
  void Function(PlaylistSyncEntry entry, bool selected)? onChanged,
}) {
  return _PlaylistSyncComparisonTable(
    entries: entries,
    selectedEntryKeys: selectedEntryKeys,
    expanded: expanded,
    enabled: enabled,
    onChanged: onChanged ?? (_, _) {},
  );
}

class _PlaylistSyncComparisonTable extends StatefulWidget {
  const _PlaylistSyncComparisonTable({
    required this.entries,
    required this.selectedEntryKeys,
    required this.expanded,
    required this.enabled,
    required this.onChanged,
  });

  final List<PlaylistSyncEntry> entries;
  final Set<String> selectedEntryKeys;
  final bool expanded;
  final bool enabled;
  final void Function(PlaylistSyncEntry entry, bool selected) onChanged;

  @override
  State<_PlaylistSyncComparisonTable> createState() =>
      _PlaylistSyncComparisonTableState();
}

class _PlaylistSyncComparisonTableState
    extends State<_PlaylistSyncComparisonTable> {
  static const double _selectWidth = 64;
  static const double _playlistWidth = 280;
  static const double _installedWidth = 280;
  static const double _matchWidth = 118;
  static const double _statusWidth = 176;
  static const double _eggWidth = 92;
  static const double _headerHeight = 44;
  static const double _rowHeight = 72;
  static const double _tableWidth =
      _selectWidth +
      _playlistWidth +
      _installedWidth +
      _matchWidth +
      _statusWidth +
      _eggWidth;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = viewportHeight * (widget.expanded ? 0.82 : 0.62);
    final minimumHeight = widget.expanded ? 520.0 : 360.0;
    final maximumHeight = widget.expanded ? 920.0 : 720.0;
    final tableHeight = (_headerHeight + widget.entries.length * _rowHeight)
        .clamp(160.0, maxHeight.clamp(minimumHeight, maximumHeight))
        .toDouble();
    return SizedBox(
      key: const ValueKey('playlist-sync-comparison-table'),
      height: tableHeight,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          key: const ValueKey('playlist-sync-table-horizontal-scroll'),
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _tableWidth,
            child: Column(
              children: [
                const _PlaylistSyncTableHeader(),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      key: const ValueKey(
                        'playlist-sync-table-vertical-scroll',
                      ),
                      controller: _verticalController,
                      itemExtent: _rowHeight,
                      itemCount: widget.entries.length,
                      itemBuilder: (context, index) {
                        final entry = widget.entries[index];
                        return _PlaylistSyncTableRow(
                          entry: entry,
                          selected: widget.selectedEntryKeys.contains(
                            playlistSyncEntryKeyForTest(entry),
                          ),
                          enabled: widget.enabled,
                          onChanged: (selected) =>
                              widget.onChanged(entry, selected),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSyncTableHeader extends StatelessWidget {
  const _PlaylistSyncTableHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Row(
        children: const [
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._selectWidth,
            height: _PlaylistSyncComparisonTableState._headerHeight,
            child: Text('选择'),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._playlistWidth,
            height: _PlaylistSyncComparisonTableState._headerHeight,
            child: Text('歌单歌曲'),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._installedWidth,
            height: _PlaylistSyncComparisonTableState._headerHeight,
            child: Text('实际歌曲'),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._matchWidth,
            height: _PlaylistSyncComparisonTableState._headerHeight,
            child: Text('匹配'),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._statusWidth,
            height: _PlaylistSyncComparisonTableState._headerHeight,
            child: Text('状态/原因'),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._eggWidth,
            height: _PlaylistSyncComparisonTableState._headerHeight,
            child: Text('Egg'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSyncTableRow extends StatelessWidget {
  const _PlaylistSyncTableRow({
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final PlaylistSyncEntry entry;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.24)
            : null,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._selectWidth,
            height: _PlaylistSyncComparisonTableState._rowHeight,
            child: Checkbox(
              value: selected,
              onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            ),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._playlistWidth,
            height: _PlaylistSyncComparisonTableState._rowHeight,
            child: _PlaylistSyncCellText(
              playlistSyncPlaylistLabelForTest(entry),
            ),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._installedWidth,
            height: _PlaylistSyncComparisonTableState._rowHeight,
            child: _PlaylistSyncCellText(
              playlistSyncInstalledLabelForTest(entry),
            ),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._matchWidth,
            height: _PlaylistSyncComparisonTableState._rowHeight,
            child: Text(playlistSyncMatchLabelForTest(entry.matchType)),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._statusWidth,
            height: _PlaylistSyncComparisonTableState._rowHeight,
            child: _PlaylistSyncStatusCell(entry: entry),
          ),
          _PlaylistSyncTableCell(
            width: _PlaylistSyncComparisonTableState._eggWidth,
            height: _PlaylistSyncComparisonTableState._rowHeight,
            child: Text(entry.hasEgg ? '含 egg' : '缺 egg'),
          ),
        ],
      ),
    );
  }
}

List<PlaylistSyncEntry> _filterPlaylistSyncEntries(
  List<PlaylistSyncEntry> entries,
  PlaylistSyncFilterModeForTest mode,
) {
  return filterPlaylistSyncEntriesForTest(entries, mode);
}

String _playlistSyncTitle(PlaylistSyncEntry entry) {
  return playlistSyncTitleForTest(entry);
}

enum _Workspace { search, library, playlistSync }

List<InstalledSongEntry> _filterInstalledEntries(
  List<InstalledSongEntry> entries, {
  required String query,
  required InstalledFilterModeForTest mode,
}) {
  final tokens = _splitFilterTokens(query);
  return filterInstalledEntriesForTest(entries, tokens: tokens, mode: mode);
}

enum _QueueTask { install, downloadZip, resolveMissing }

enum _DownloadMode { localCache, zeyuCache, api }

enum _ResultSource { textSearch, uploader, scoreSaber, beastSaber, localCache }

extension on _Workspace {
  WorkspaceForTest toWorkspaceForTest() {
    return WorkspaceForTest.values.byName(name);
  }
}

extension on WorkspaceForTest {
  _Workspace toWorkspace() {
    return _Workspace.values.byName(name);
  }
}

extension on _ResultSource {
  ResultSourceForTest toResultSourceForTest() {
    return ResultSourceForTest.values.byName(name);
  }
}

extension on _DownloadMode {
  DownloadModeForTest toDownloadModeForTest() {
    return DownloadModeForTest.values.byName(name);
  }
}

extension on DownloadModeForTest {
  _DownloadMode toDownloadMode() {
    return _DownloadMode.values.byName(name);
  }
}

class _ZipDownloadSummary {
  const _ZipDownloadSummary({
    required this.downloaded,
    required this.skipped,
    required this.stopped,
    required this.failed,
  });

  final int downloaded;
  final int skipped;
  final int stopped;
  final int failed;
}

class _InstallSummary {
  const _InstallSummary({
    required this.installed,
    required this.skipped,
    required this.stopped,
    required this.failed,
  });

  final int installed;
  final int skipped;
  final int stopped;
  final int failed;
}

class _MapLookupResult {
  const _MapLookupResult({required this.maps, required this.failed});

  final List<BeatSaverMap> maps;
  final int failed;
}

class _LocalCachePage {
  const _LocalCachePage({
    required this.maps,
    required this.total,
    required this.totalPages,
  });

  final List<BeatSaverMap> maps;
  final int total;
  final int totalPages;
}

class _LocalCacheStatus {
  const _LocalCacheStatus({
    required this.path,
    required this.bytes,
    required this.modified,
    required this.generatedAt,
    required this.incrementalUpdatedAt,
    required this.incrementalAdded,
    required this.incrementalUpdated,
    required this.maps,
  });

  final String path;
  final int bytes;
  final DateTime modified;
  final DateTime? generatedAt;
  final DateTime? incrementalUpdatedAt;
  final int incrementalAdded;
  final int incrementalUpdated;
  final int maps;
}

class _LocalCacheDeletedAuditState {
  const _LocalCacheDeletedAuditState({
    required this.cachePath,
    required this.result,
  });

  final String cachePath;
  final LocalCacheDeletedAuditResult result;
}

class _LocalCacheFilterCache {
  const _LocalCacheFilterCache({
    required this.source,
    required this.signature,
    required this.maps,
  });

  final List<BeatSaverMap> source;
  final String signature;
  final List<BeatSaverMap> maps;
}

class _HashCacheStatus {
  const _HashCacheStatus({
    required this.path,
    required this.entries,
    required this.cacheDate,
  });

  final String path;
  final int entries;
  final String cacheDate;
}

class _PlaylistSyncMissingResolvedMap {
  const _PlaylistSyncMissingResolvedMap({
    required this.entry,
    required this.map,
  });

  final PlaylistSyncEntry entry;
  final BeatSaverMap map;
}

class _PlaylistSyncMissingResolveResult {
  const _PlaylistSyncMissingResolveResult({
    required this.items,
    required this.failed,
    this.hashCacheStatus,
  });

  final List<_PlaylistSyncMissingResolvedMap> items;
  final int failed;
  final _HashCacheStatus? hashCacheStatus;

  List<BeatSaverMap> get maps =>
      items.map((item) => item.map).toList(growable: false);
}

enum _QueueStatus { waiting, running, completed, skipped, failed }

class _QueueEntry {
  const _QueueEntry({
    required this.id,
    required this.title,
    required this.task,
    required this.status,
    this.message,
  });

  final String id;
  final String title;
  final _QueueTask task;
  final _QueueStatus status;
  final String? message;

  _QueueEntry copyWith({
    String? title,
    _QueueTask? task,
    _QueueStatus? status,
    String? message,
    bool clearMessage = false,
  }) {
    return _QueueEntry(
      id: id,
      title: title ?? this.title,
      task: task ?? this.task,
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}
