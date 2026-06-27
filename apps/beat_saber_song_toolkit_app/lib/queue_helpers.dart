enum QueueTaskForTest { install, downloadZip, resolveMissing }

enum QueueStatusForTest { waiting, running, completed, skipped, failed }

class QueueEntrySnapshotForTest {
  const QueueEntrySnapshotForTest({
    required this.id,
    this.title,
    this.task = QueueTaskForTest.install,
    required this.status,
    this.message,
  });

  final String id;
  final String? title;
  final QueueTaskForTest task;
  final QueueStatusForTest status;
  final String? message;
}

class QueueSummaryForTest {
  const QueueSummaryForTest({
    required this.waiting,
    required this.running,
    required this.completed,
    required this.skipped,
    required this.failed,
  });

  final int waiting;
  final int running;
  final int completed;
  final int skipped;
  final int failed;

  int get clearable => completed + skipped;

  String get label =>
      '等待 $waiting，处理中 $running，完成 $completed，跳过 $skipped，失败 $failed';
}

QueueSummaryForTest queueSummaryForTest(
  Iterable<QueueEntrySnapshotForTest> queue,
) {
  var waiting = 0;
  var running = 0;
  var completed = 0;
  var skipped = 0;
  var failed = 0;
  for (final entry in queue) {
    switch (entry.status) {
      case QueueStatusForTest.waiting:
        waiting += 1;
      case QueueStatusForTest.running:
        running += 1;
      case QueueStatusForTest.completed:
        completed += 1;
      case QueueStatusForTest.skipped:
        skipped += 1;
      case QueueStatusForTest.failed:
        failed += 1;
    }
  }
  return QueueSummaryForTest(
    waiting: waiting,
    running: running,
    completed: completed,
    skipped: skipped,
    failed: failed,
  );
}

String queueStatusLabelForTest(QueueStatusForTest status) {
  return switch (status) {
    QueueStatusForTest.waiting => '等待',
    QueueStatusForTest.running => '处理中',
    QueueStatusForTest.completed => '完成',
    QueueStatusForTest.skipped => '跳过',
    QueueStatusForTest.failed => '失败',
  };
}

String queueStatusDetailForTest(QueueStatusForTest status) {
  return switch (status) {
    QueueStatusForTest.waiting => '等待处理',
    QueueStatusForTest.running => '正在处理',
    QueueStatusForTest.completed => '已完成',
    QueueStatusForTest.skipped => '已跳过',
    QueueStatusForTest.failed => '未记录失败原因',
  };
}

String queueTaskLabelForTest(QueueTaskForTest task) {
  return switch (task) {
    QueueTaskForTest.install => '安装',
    QueueTaskForTest.downloadZip => '下载 ZIP',
    QueueTaskForTest.resolveMissing => '解析缺失',
  };
}

String queueEntrySubtitleForTest({
  required QueueTaskForTest task,
  required String id,
  required QueueStatusForTest status,
  String? message,
}) {
  return '${queueTaskLabelForTest(task)} | $id\n'
      '${message ?? queueStatusDetailForTest(status)}';
}

class RetryQueueEntryForTest {
  const RetryQueueEntryForTest({required this.id, required this.task});

  final String id;
  final QueueTaskForTest task;
}

List<RetryQueueEntryForTest> retryQueueEntriesForTest(
  Iterable<QueueEntrySnapshotForTest> queue,
) {
  return queue
      .where(
        (entry) =>
            entry.status == QueueStatusForTest.failed &&
            entry.task != QueueTaskForTest.resolveMissing,
      )
      .map((entry) => RetryQueueEntryForTest(id: entry.id, task: entry.task))
      .toList(growable: false);
}

List<String> queueIdsAfterClearingFinishedForTest(
  Iterable<QueueEntrySnapshotForTest> queue,
) {
  return queue
      .where(
        (entry) =>
            entry.status != QueueStatusForTest.completed &&
            entry.status != QueueStatusForTest.skipped,
      )
      .map((entry) => entry.id)
      .toList(growable: false);
}

List<String> queueIdsToMarkSkippedForTest({
  required Iterable<String> queueIds,
  required Iterable<String> requestedIds,
}) {
  final existing = queueIds.toSet();
  return requestedIds.where(existing.contains).toSet().toList(growable: false);
}
