import 'package:flutter/material.dart';

import 'queue_helpers.dart';
import 'status_helpers.dart';

const queueStopTooltip = '停止队列：请求当前批量下载/安装在正在处理的歌曲完成后停止。';
const queueRetryFailedTooltip = '重试失败项：重新派发当前队列中失败的下载/安装任务。';
const queueClearFinishedTooltip = '清空完成项：从队列显示中移除已完成、已跳过或已停止的任务。';
const queueClearAllTooltip = '清空队列：清除当前队列显示，不会删除已下载或已安装的文件。';

Widget queuePanelForTest({
  required List<QueueEntrySnapshotForTest> entries,
  bool busy = false,
  bool stopRequested = false,
  VoidCallback? onStop,
  VoidCallback? onRetryFailed,
  VoidCallback? onClearFinished,
  VoidCallback? onClearQueue,
}) {
  return QueuePanel(
    entries: entries,
    busy: busy,
    stopRequested: stopRequested,
    onStop: onStop ?? () {},
    onRetryFailed: onRetryFailed ?? () {},
    onClearFinished: onClearFinished ?? () {},
    onClearQueue: onClearQueue ?? () {},
  );
}

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.entries,
    required this.busy,
    required this.stopRequested,
    required this.onStop,
    required this.onRetryFailed,
    required this.onClearFinished,
    required this.onClearQueue,
  });

  final List<QueueEntrySnapshotForTest> entries;
  final bool busy;
  final bool stopRequested;
  final VoidCallback onStop;
  final VoidCallback onRetryFailed;
  final VoidCallback onClearFinished;
  final VoidCallback onClearQueue;

  @override
  Widget build(BuildContext context) {
    final summary = queueSummaryForTest(entries);
    final retryableFailed = retryQueueEntriesForTest(entries).length;
    return _QueueSection(
      title: '下载队列',
      child: entries.isEmpty
          ? const _QueueEmptyState(text: '批量下载或安装时会在这里显示队列状态。')
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(summary.label),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Tooltip(
                        message: queueStopTooltip,
                        child: OutlinedButton.icon(
                          onPressed:
                              queueStopEnabledForTest(
                                busy: busy,
                                stopRequested: stopRequested,
                              )
                              ? onStop
                              : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(stopRequested ? '停止已请求' : '停止队列'),
                        ),
                      ),
                      Tooltip(
                        message: queueRetryFailedTooltip,
                        child: OutlinedButton.icon(
                          onPressed:
                              queueRetryFailedEnabledForTest(
                                failedCount: retryableFailed,
                                busy: busy,
                              )
                              ? onRetryFailed
                              : null,
                          icon: const Icon(Icons.refresh),
                          label: Text('重试失败项($retryableFailed)'),
                        ),
                      ),
                      Tooltip(
                        message: queueClearFinishedTooltip,
                        child: OutlinedButton.icon(
                          onPressed:
                              queueClearFinishedEnabledForTest(
                                clearableCount: summary.clearable,
                                busy: busy,
                              )
                              ? onClearFinished
                              : null,
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('清空完成项'),
                        ),
                      ),
                      Tooltip(
                        message: queueClearAllTooltip,
                        child: OutlinedButton.icon(
                          onPressed: queueClearAllEnabledForTest(busy: busy)
                              ? onClearQueue
                              : null,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('清空队列'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _queueStatusIcon(entry.status),
                      color: _queueStatusColor(context, entry.status),
                    ),
                    title: Text(entry.title ?? entry.id),
                    subtitle: Text(
                      queueEntrySubtitleForTest(
                        task: entry.task,
                        id: entry.id,
                        status: entry.status,
                        message: entry.message,
                      ),
                    ),
                    trailing: Text(queueStatusLabelForTest(entry.status)),
                  ),
              ],
            ),
    );
  }
}

IconData _queueStatusIcon(QueueStatusForTest status) {
  return switch (status) {
    QueueStatusForTest.waiting => Icons.schedule,
    QueueStatusForTest.running => Icons.downloading,
    QueueStatusForTest.completed => Icons.check_circle_outline,
    QueueStatusForTest.skipped => Icons.skip_next,
    QueueStatusForTest.failed => Icons.error_outline,
  };
}

Color _queueStatusColor(BuildContext context, QueueStatusForTest status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    QueueStatusForTest.completed => Colors.green,
    QueueStatusForTest.failed => scheme.error,
    QueueStatusForTest.running => scheme.primary,
    QueueStatusForTest.skipped => scheme.tertiary,
    QueueStatusForTest.waiting => scheme.onSurfaceVariant,
  };
}

class _QueueSection extends StatelessWidget {
  const _QueueSection({required this.title, required this.child});

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

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState({required this.text});

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
