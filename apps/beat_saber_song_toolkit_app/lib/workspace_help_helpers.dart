import 'settings_helpers.dart';

class WorkspaceHelpSectionForTest {
  const WorkspaceHelpSectionForTest({required this.title, required this.body});

  final String title;
  final String body;
}

String workspaceHelpTitleForTest(WorkspaceForTest workspace) {
  return switch (workspace) {
    WorkspaceForTest.search => '找歌下载帮助',
    WorkspaceForTest.library => '本地曲库帮助',
    WorkspaceForTest.playlistSync => '歌单同步帮助',
  };
}

List<WorkspaceHelpSectionForTest> workspaceHelpSectionsForTest(
  WorkspaceForTest workspace,
) {
  return switch (workspace) {
    WorkspaceForTest.search => const [
      WorkspaceHelpSectionForTest(
        title: '输入格式',
        body:
            '手动输入支持 BeatSaver ID、bsr:// 链接和 beatsaver.com/maps 链接；'
            '多首歌曲可用换行、逗号或空格分隔。',
      ),
      WorkspaceHelpSectionForTest(
        title: '运行逻辑',
        body:
            '开始会处理“本次歌曲”列表；保存所选会按“歌曲列表”和“下载歌曲”'
            '两个输出开关分别导出列表或下载 ZIP。跳过已有会检查安装目录和额外跳过目录，'
            '本地歌曲目录命中时会优先复制。启动后自动开始等同于启动时执行“开始”，'
            '可能联网下载或安装歌曲。',
      ),
      WorkspaceHelpSectionForTest(
        title: '联网入口',
        body:
            'BeatSaver 搜索、谱师谱面、ScoreSaber、BEASTSABER 和在线歌单都会访问外部服务；'
            '封面标签开启后会访问 GCP Vision，检查更新会访问配置的 release API。'
            '本地缓存读取、歌曲列表导入和手动列表处理是离线操作。',
      ),
      WorkspaceHelpSectionForTest(
        title: '本地缓存',
        body:
            '“本地缓存”页签支持读取原版 LocalCache.saver 数据缓存，并保留已下载 ZIP 文件缓存扫描。'
            '同目录 LocalCache.time 会作为生成时间显示；读取后会生成轻量索引，加速 hash 匹配和简单关键词搜索。'
            '原远程数据缓存接口已不可用；读取 LocalCache.saver 是离线操作，'
            '重建快照、继续快照、增量更新和审计删除是显式联网维护操作。'
            '当前可用 BeatSaver 官方 /maps/latest 构建可恢复、可暂停、限速的本地快照，'
            '默认 15 天内不重复重建。审计删除只导出候选，不会修改缓存；'
            '-fastlog 会在启动时读取配置中的 LocalCache.saver 路径。'
            '“泽宇缓存(兼容)”入口仅保留原版兼容选项，当前环境默认不视为可靠下载源。',
      ),
      WorkspaceHelpSectionForTest(
        title: '禁止商用',
        body:
            '导出的 bplist 默认描述沿用原版禁止商用说明；本项目优先复刻原版工作流，'
            '不替代 BeatSaver、ScoreSaber 或相关平台规则。',
      ),
    ],
    WorkspaceForTest.library => const [
      WorkspaceHelpSectionForTest(
        title: '扫描曲库',
        body:
            '选择 Beat Saber 安装目录后扫描 CustomLevels，列表会区分正常歌曲、缺少 ID、缺少 info.dat、'
            '以及只有音频但缺 info.dat 的半坏目录。',
      ),
      WorkspaceHelpSectionForTest(
        title: '整理与导出',
        body:
            '本地曲库可把当前过滤结果加入本次、加入跳过或导出歌单；路径建议和重复歌曲操作都会先确认，'
            '删除类操作会写入备份目录。',
      ),
      WorkspaceHelpSectionForTest(
        title: 'SongCore 列表',
        body:
            '检测游戏目录后可读取、保存和移除 SongCore folders.xml 曲包列表。移除列表项只修改 folders.xml，'
            '不会删除实际歌曲目录。',
      ),
    ],
    WorkspaceForTest.playlistSync => const [
      WorkspaceHelpSectionForTest(
        title: '扫描对比',
        body:
            '选择 .bplist 歌单和安装目录后扫描，结果表按歌单条目与实际本地歌曲一一对比，'
            '优先显示 ID、hash、名称、匹配方式和异常状态。',
      ),
      WorkspaceHelpSectionForTest(
        title: '处理缺失',
        body:
            '缺失条目可以联网解析后加入本次、下载 ZIP 或安装到本地；这些操作不会修改 .bplist。'
            '缺失条目也可以仅移出歌单；已安装条目可备份删除本地目录并同步移出歌单。'
            'Hash 匹配用于真实样本里只有 hash 的歌单条目。',
      ),
      WorkspaceHelpSectionForTest(
        title: '导出差异',
        body:
            '导出当前会保存当前筛选后的表格行；导出“本地有，歌单无”只导出本地存在但不在当前歌单中的歌曲；'
            '`本地有，歌单无` 区块里的 `加入本次/加入跳过` 会把这些歌曲合并到本次列表或跳过列表。',
      ),
    ],
  };
}
