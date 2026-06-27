import 'package:flutter/material.dart';

const logExportTooltip = '导出日志：把当前显示和缓存的操作日志保存为本地文本文件。';
const logClearTooltip = '清空日志：只清空应用内日志显示和缓存，不删除歌曲或 ZIP 文件。';

class LogPanel extends StatelessWidget {
  const LogPanel({
    super.key,
    required this.logs,
    required this.cachedLogCount,
    required this.paused,
    required this.busy,
    required this.onTogglePause,
    required this.onExport,
    required this.onClear,
  });

  final List<String> logs;
  final int cachedLogCount;
  final bool paused;
  final bool busy;
  final VoidCallback onTogglePause;
  final VoidCallback onExport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _LogSection(
      title: '操作日志',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 140,
                  child: Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: !paused,
                      onChanged: (value) {
                        final realtime = value ?? true;
                        if (realtime == paused) {
                          onTogglePause();
                        }
                      },
                      title: const Text('实时输出'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Tooltip(
                  message: logExportTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy || (logs.isEmpty && cachedLogCount == 0)
                        ? null
                        : onExport,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('导出日志'),
                  ),
                ),
                Tooltip(
                  message: logClearTooltip,
                  child: OutlinedButton.icon(
                    onPressed: busy || (logs.isEmpty && cachedLogCount == 0)
                        ? null
                        : onClear,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清空日志'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (paused) ...[
            Text(
              '日志输出已暂停，缓存 $cachedLogCount 条。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: logs.isEmpty
                ? const _LogEmptyState(text: '搜索、下载、安装和错误信息会显示在这里。')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 8),
                    itemBuilder: (context, index) => Text(
                      logs[index],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
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

class _LogEmptyState extends StatelessWidget {
  const _LogEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
