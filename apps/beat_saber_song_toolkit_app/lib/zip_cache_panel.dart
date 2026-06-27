import 'package:flutter/material.dart';

import 'output_helpers.dart';
import 'status_helpers.dart';
import 'zip_cache_helpers.dart';

const zipCacheScanTooltip = '扫描 ZIP：离线扫描当前 ZIP 下载目录，识别已下载歌曲包。';
const zipCacheExportTooltip = '导出 ZIP 缓存列表：把扫描到的 ZIP 文件信息保存为本地文本文件。';
const zipCacheAddToTargetsTooltip =
    'ZIP 入本次：把可识别 BeatSaver ID 的 ZIP 缓存歌曲加入本次列表，不下载或安装。';
const zipCacheAddToSkipTooltip = 'ZIP 入跳过：把可识别 BeatSaver ID 的 ZIP 缓存歌曲加入跳过列表。';

class ZipCacheEntryUiModel extends ZipCacheEntryForTest {
  const ZipCacheEntryUiModel({
    required super.name,
    required super.path,
    required super.bytes,
    required super.modified,
  });
}

Widget zipCachePanelForTest({
  required List<ZipCacheEntryForTest> entries,
  bool busy = false,
  VoidCallback? onRefresh,
  Future<void> Function(List<ZipCacheEntryForTest> entries)? onExport,
  Future<void> Function(List<ZipCacheEntryForTest> entries)? onAddToTargets,
  ValueChanged<List<ZipCacheEntryForTest>>? onAddToSkip,
}) {
  final panelEntries = entries
      .map(
        (entry) => ZipCacheEntryUiModel(
          name: entry.name,
          path: entry.path,
          bytes: entry.bytes,
          modified: entry.modified,
        ),
      )
      .toList(growable: false);
  return ZipCachePanel(
    entries: panelEntries,
    busy: busy,
    onRefresh: onRefresh ?? () {},
    onExport: (entries) async {
      await (onExport ?? (_) async {})(entries);
    },
    onAddToTargets: (entries) async {
      await (onAddToTargets ?? (_) async {})(entries);
    },
    onAddToSkip: (entries) {
      (onAddToSkip ?? (_) {})(entries);
    },
  );
}

class ZipCachePanel extends StatelessWidget {
  const ZipCachePanel({
    super.key,
    required this.entries,
    required this.busy,
    required this.onRefresh,
    required this.onExport,
    required this.onAddToTargets,
    required this.onAddToSkip,
  });

  final List<ZipCacheEntryUiModel> entries;
  final bool busy;
  final VoidCallback onRefresh;
  final Future<void> Function(List<ZipCacheEntryUiModel> entries) onExport;
  final Future<void> Function(List<ZipCacheEntryUiModel> entries)
  onAddToTargets;
  final ValueChanged<List<ZipCacheEntryUiModel>> onAddToSkip;

  @override
  Widget build(BuildContext context) {
    final summary = zipCacheSummaryForTest(entries);
    final recognized = entries
        .where((entry) => entry.mapId != null)
        .toList(growable: false);
    return _ZipCacheSection(
      title: 'ZIP 缓存',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text(summary.filesLabel)),
              Chip(label: Text(summary.recognizedLabel)),
              Chip(label: Text(summary.sizeLabel)),
              Tooltip(
                message: zipCacheScanTooltip,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('扫描 ZIP'),
                ),
              ),
              Tooltip(
                message: zipCacheExportTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      zipCacheExportEnabledForTest(
                        entryCount: entries.length,
                        busy: busy,
                      )
                      ? () => onExport(entries)
                      : null,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('导出列表'),
                ),
              ),
              Tooltip(
                message: zipCacheAddToTargetsTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      zipCacheRecognizedActionEnabledForTest(
                        recognizedCount: recognized.length,
                        busy: busy,
                      )
                      ? () => onAddToTargets(recognized)
                      : null,
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text('加入本次(${recognized.length})'),
                ),
              ),
              Tooltip(
                message: zipCacheAddToSkipTooltip,
                child: OutlinedButton.icon(
                  onPressed:
                      zipCacheRecognizedActionEnabledForTest(
                        recognizedCount: recognized.length,
                        busy: busy,
                      )
                      ? () => onAddToSkip(recognized)
                      : null,
                  icon: const Icon(Icons.skip_next),
                  label: Text('加入跳过(${recognized.length})'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const _ZipCacheEmptyState(text: '扫描 ZIP 下载目录后会在这里显示缓存文件。')
          else
            for (final entry in entries.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.name),
                subtitle: Text(
                  '${formatBytesForTest(entry.bytes)} | '
                  '${exportDateForTest(entry.modified)}\n'
                  '${entry.mapId == null ? '未识别 BeatSaver ID' : 'ID ${entry.mapId}'} | '
                  '${entry.path}',
                ),
                isThreeLine: true,
                trailing: entry.mapId == null
                    ? null
                    : Wrap(
                        spacing: 8,
                        children: [
                          Tooltip(
                            message: zipCacheAddToTargetsTooltip,
                            child: OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => onAddToTargets([entry]),
                              icon: const Icon(Icons.playlist_add_check),
                              label: const Text('加入本次'),
                            ),
                          ),
                          Tooltip(
                            message: zipCacheAddToSkipTooltip,
                            child: OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => onAddToSkip([entry]),
                              icon: const Icon(Icons.skip_next),
                              label: const Text('跳过'),
                            ),
                          ),
                        ],
                      ),
              ),
          if (entries.length > 20)
            Text('还有 ${entries.length - 20} 个 ZIP 文件未显示。'),
        ],
      ),
    );
  }
}

class _ZipCacheSection extends StatelessWidget {
  const _ZipCacheSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ZipCacheEmptyState extends StatelessWidget {
  const _ZipCacheEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
