# Beat Saber Song Toolkit 最终验收清单

更新时间：2026-06-21。

本清单用于彻底收工前的最终 GUI / release 验收。普通继续开发时仍以离线核心、测试和文档收口为主；只有用户明确要求 GUI / release，或进入最终统一验收阶段，才执行 Windows release 构建和可见 exe 检查。人工点击记录属于本地验收资料，不随公开仓库发布。

## 最近 release 证据

- 2026-06-20：`flutter build windows --release` 成功，`Beat Saber Song Toolkit.exe` 标题为 `Beat Saber Song Toolkit v0.1.0`。
- `data\app.so` 修改时间：`2026-06-20 23:37:57`；大小：`8242064` 字节。
- 用临时 `APPDATA` 截图验证默认启动、`本地曲库` 工作区恢复、`歌单同步` 工作区恢复，以及配置真实样本路径/Tech `.bplist`/项目内 `LocalCache.saver` 后的本地曲库和歌单同步恢复；用户真实 `%APPDATA%` 未写入，进程均已关闭。
- 截图：`release_acceptance_20260620_main.png`、`release_acceptance_20260620_library.png`、`release_acceptance_20260620_playlist_sync.png`、`release_acceptance_20260620_library_configured.png`、`release_acceptance_20260620_playlist_configured.png`。
- 本轮未联网，未在 GUI 中扫描真实样本；`readLocalDataOnStartup=false`。
- 2026-06-20 追加：最新 release 已验证 `readLocalDataOnStartup=true` 时，歌单同步工作区会启动后自动扫描真实 Tech 样本；截图 `release_acceptance_20260620_playlist_autoscan_tech.png` 显示共 100、本地存在 60、缺失 40、Hash 匹配 60、本地有歌单无 39。该轮未联网、未写真实样本目录、未写用户真实 `%APPDATA%`。`release_acceptance_20260620_playlist_autoscan_screen.png` 被外部窗口遮挡，`release_acceptance_20260620_playlist_autoscan_screen2.png` 使用了错误安装目录，均不作为正向验收证据。
- 2026-06-21 追加：最新 release 已验证 `readLocalDataOnStartup=true` 时，本地曲库工作区会启动后自动扫描真实 Tech 样本；截图 `release_acceptance_20260621_library_autoscan_tech.png` 显示已安装歌曲 102 首、正常 99、缺少 `info.dat` 3、缺 info 但有音频 3、路径建议 102，默认 `异常优先` 当前 3 条可见。该轮未联网、未写真实样本目录、未写用户真实 `%APPDATA%`。
- 2026-06-21 追加：最新 release 已验证 `-fastlog` 会离线读取项目根 `LocalCache.saver` 并自动切到 `本地缓存` 页签；截图 `release_acceptance_20260621_localcache_fastlog_tab.png` 显示读取 81962 张、151.8 MB、生成 2026-06-18、快照 2 天前，以及 `重建快照`、`继续快照`、`增量更新`、`审计删除`、`导出删除`、`数据入本次`、`数据入跳过`、`导出数据`、`导出摘要`、`清空数据` 等控件。该轮未联网、未写用户真实 `%APPDATA%`。
- 2026-06-21 追加：App focused 测试 `covers final file picker and export status checklist text` 已覆盖安装目录、本地歌曲目录、游戏目录、跳过目录、ZIP 目录、歌单文件、歌单保存、封面、ZIP 保存、歌曲列表文件、本次歌曲列表、LocalCache.saver、Android 目录的取消/成功状态文案，以及日志/结果/本次/已安装/ZIP 缓存/LocalCache 列表与摘要/deleted 报告/收藏歌单/已安装歌单/SongCore 路径复制的导出或复制状态。真实系统文件对话框的可见点击仍保留为人工验收项。
- 2026-06-21 追加：复跑 App focused 测试 `covers final destructive confirmation checklist text` 和 `formats destructive local management confirmation text`，确认单首删除、重复备份删除、路径重命名、歌单同步仅移出/备份删除、SongCore 条目移除、删除配置、清空封面缓存和清空 Hash 缓存等破坏性确认文案仍被自动化覆盖。真实 release 弹窗点击只保留为最终人工手感验收项。
- 2026-06-21 追加：App widget 测试 `clicks ZIP cache panel actions and shows feedback`、`clicks queue panel controls and shows feedback` 已直接点击生产 ZIP 缓存面板和下载队列面板的按钮，覆盖扫描、导出、加入本次、加入跳过、停止队列、重试失败项、清空完成项和清空队列的回调反馈。真实 release 阶段只需抽样确认按钮手感和布局。
- 2026-06-21 追加：App widget 测试 `scrolls long playlist sync table to the last row`、`expands playlist sync table height for long scans` 补强歌单同步长表体验，覆盖 100 行长表可滚到最后一行、表头纵向滚动后仍固定、默认/扩大表格高度会按视口变化。结合既有 `keeps playlist sync table header fixed while scrolling`，纵向滚动、横向滚动、固定表头和扩大表格均已有自动化覆盖。
- 2026-06-21 追加：基于当前代码重新执行 `flutter build windows --release` 成功，`data\app.so` 修改时间 `2026/6/21 6:59:51`、大小 `8242064` 字节；用临时 `APPDATA` 配置项目根 `LocalCache.saver` 并启动 `Beat Saber Song Toolkit.exe -fastlog`，窗口标题 `Beat Saber Song Toolkit v0.1.0`，进程响应正常，`PrintWindow=True`，像素抽样 `nonBlack=240`，截图 `release_acceptance_20260621_fastlog_rebuild.png`。验收后进程已关闭，未写用户真实 `%APPDATA%`，未访问 BeatSaver。
- 2026-06-21 追加：复用当前 release 和临时 `APPDATA`，分别启动到 `本地曲库` 与 `歌单同步` 并设置 `readLocalDataOnStartup=true` 自动扫描真实 Tech 样本；两个窗口标题均为 `Beat Saber Song Toolkit v0.1.0`、进程响应正常、`PrintWindow=True`、像素抽样 `nonBlack=240`。截图：`release_acceptance_20260621_library_autoscan_rebuild.png`、`release_acceptance_20260621_playlist_autoscan_rebuild.png`。该轮未联网、未写真实样本目录、未写用户真实 `%APPDATA%`。
- 2026-06-21 追加：启动参数 release 抽样通过。`Beat Saber Song Toolkit.exe -minimize` 启动后窗口标题正确、进程响应正常、Win32 `IsIconic=True`；`-local` 在 `本地曲库` 工作区使用真实 Tech 样本目录离线读入并截图 `release_acceptance_20260621_local_arg_library.png`；`-fastlog` 使用项目根 `LocalCache.saver` 离线读取并截图 `release_acceptance_20260621_fastlog_arg.png`。三项均使用临时 `APPDATA`，未联网、未写真实样本目录、未写用户真实配置。
- 2026-06-21 追加：尝试用 release 自动化打开破坏性确认弹窗时，Flutter Windows 未暴露可稳定点击的 UI Automation 控件，坐标点击存在误触风险；已保留临时曲库截图 `release_acceptance_20260621_delete_confirm_before.png` / `release_acceptance_20260621_delete_confirm_scrolled.png` 和一次错误点击定位截图 `release_acceptance_20260621_hash_clear_confirm.png`，这些不作为确认弹窗通过证据。破坏性确认文案仍由 focused widget 测试覆盖，release 真实弹窗点击保持人工抽验项。
- 2026-06-21 追加：新增安全人工验收启动器 `tool\release_manual_acceptance.dart`，用于以临时 `APPDATA` 启动 Windows release，并自动创建临时 `CustomLevels` 曲库，方便人工打开文件选择器和破坏性确认弹窗后取消。`--help` 非破坏退出和 `--mode=library` 实际启动 smoke 均已通过；启动器不请求 BeatSaver 网络，不写用户真实配置。
- 2026-06-21 追加：恢复后检查无残留 `Beat Saber Song Toolkit.exe`、`dart` 或 `flutter` 进程；复跑 `test\documentation_links_test.dart` 和 `test\tool_help_test.dart` 均通过。该轮未联网、未构建/启动 release。
- 2026-06-21 追加：人工验收启动器剩余模式抽样通过。`--mode=playlistSync`、`--mode=fastlog`、`--mode=search` 均能用临时 `APPDATA` 启动当前 release，窗口标题 `Beat Saber Song Toolkit v0.1.0`，进程响应正常，并已按 PID 关闭；验证后无 release/dart/flutter 残留进程，未联网、未写用户真实配置。
- 2026-06-21 追加：新增 `tool\release_manual_acceptance_smoke.dart`，把人工验收启动器四模式启动/响应/关闭流程固化为可复跑脚本；默认覆盖 `library`、`playlistSync`、`fastlog`、`search`，通过后删除临时启动目录。最新执行通过，四个模式窗口标题均为 `Beat Saber Song Toolkit v0.1.0` 且进程响应正常；未联网、未写用户真实配置、验证后无残留进程。
- 2026-06-21 追加：新增 `tool\final_acceptance_preflight.dart`，作为最终人工验收前的离线预检入口；默认运行文档锁定测试、tool help 测试、根包分析和 release 人工验收启动器四模式 smoke，并检查无 release 残留进程。最新执行通过，未联网、未写用户真实配置。
- 2026-06-21 追加：完成度审计复验通过。`dart run tool\final_acceptance_preflight.dart` 通过，覆盖文档锁定、tool help、根包分析和四模式 release 启动器 smoke；随后 `dart run tool\toolbox_smoke.dart` 通过，输出 `songCoreSmoke=passed`、`realSampleLibrarySmoke=passed`、`playlistSyncSmoke=passed`、`toolboxSmoke=passed`。本轮未联网，真实样本保持只读，破坏性操作只发生在系统临时目录；结束后无 `Beat Saber Song Toolkit.exe`、`dart`、`flutter` 残留进程。
- 2026-06-21 追加：人工 release 验收阶段性记录已保存在本地私有资料中。已通过/记录的项目包括首屏可见、主要文件/目录选择器、选择封面、删除确认、清空 Hash、ZIP 扫描、歌单同步长表和 LocalCache 离线工作区；Android 目录、清空封面缓存和 ZIP 导出/加入等因平台或空数据灰色按不适用记录；队列/ZIP 复杂按钮和部分依赖候选的破坏性弹窗按用户要求停止人工检验，后续实用测试中再反馈。人工停止后已关闭残留 release 进程，最终无 release/dart/flutter 残留。

## 已由自动化覆盖

- 三主线离线总控：`dart run tool\toolbox_smoke.dart`，默认 `allowNetwork=false`，覆盖 SongCore、本地曲库真实样本、歌单同步真实样本。
- SongCore 核心：目录/Mod 检测、`folders.xml` 保存/读取/移除、备份目录、XML 边界和未知字段保留。
- 本地曲库核心：真实样本只读导出、自动封面、重复项临时副本备份删除、路径重命名临时副本、半坏目录提示。
- 歌单同步核心：真实样本只读审计、hash-only 匹配、仅移出歌单、备份删除、缺失下载/安装的显式联网 smoke。
- LocalCache 核心：离线读取、索引、分页、增量/续跑状态、deleted 审计报告、结构校验；项目根 `LocalCache.saver` 的 inspect/validate 常规离线检查由 `test\local_cache_tool_test.dart` 覆盖且 `apiChecked=0`。
- CLI：`--help`、无参数错误用法、联网/删除门禁、`--list-installed` 空曲库离线成功、`--export-bplist` 临时曲库离线导出均由 `test\cli_safety_test.dart` 覆盖。
- GUI helper / widget：三工作区入口、帮助弹窗、按钮启用状态、tooltip、破坏性确认文案、路径选择/导出状态文案、默认导出文件名、检查更新弹窗解析、GCP 失败等待核心语义、本地曲库清单语义、歌单同步表格固定表头/纵横滚动结构；LocalCache/SongCore/封面缓存/Hash 缓存/deleted 报告等文件选择与导出状态也由 App widget 测试覆盖。
- Release 人工验收启动器：`tool\release_manual_acceptance_smoke.dart` 覆盖 `library`、`playlistSync`、`fastlog`、`search` 四个启动模式，验证 release 窗口标题、响应状态、进程关闭和临时目录清理，便于最终人工验收前快速确认启动器本身可用。
- 最终验收预检：`tool\final_acceptance_preflight.dart` 串联文档锁定、tool help、根包分析和 release 启动器四模式 smoke，适合人工点击前先跑一遍。
- 启动参数 helper：`-config/-c/--profile`、`-local/-fastlog/-start/-zip/-unzip/-exit/-minimize` 的解析和启动动作规划顺序由 App widget 测试覆盖；Windows release 实机行为仍在最终验收中确认。
- 安全门禁：CLI 联网命令必须 `--allow-network`，CLI 删除必须 `--yes-delete`；联网 smoke、缺失下载/安装 smoke 和 LocalCache 更新默认拒绝联网，并由集中 tool 门禁测试 `test\tool_network_gate_test.dart` 覆盖；全部 tool 的 `--help` 非破坏出口由 `test\tool_help_test.dart` 覆盖；真实样本相关 tool 的只读/临时目录约束由 `test\tool_real_sample_safety_test.dart` 锁定。
- 文档入口：README / 最终验收清单里的关键目录、脚本、缓存、真实样本路径、外部输入依赖边界和 `Beat Saber Song Toolkit v0.1.0` 产品身份由 `test\documentation_links_test.dart` 锁定。
- 人工验收记录：本地私有记录提供最终人手点击项目的结果表，覆盖文件/目录选择器、破坏性确认弹窗、队列/ZIP 手感、真实样本长表和 LocalCache 离线工作区。

## 最终 release 必测

以下项目需要在最终统一验收时使用 Windows release exe 验证：

当前剩余项摘要：本地代码/自动化层面的最终清单已基本收口；`final_acceptance_preflight` 和三主线 `toolbox_smoke` 已同时通过。仍需 release 真实环境抽样的是 Windows 系统文件/目录选择器、破坏性确认弹窗手感、队列/ZIP 按钮手感、真实样本扫描后的长表手感和少量人工观察项。外部输入依赖单独列在本文末尾，未提供 release API、GCP key、原版封面样本或真实 Beat Saber/SongCore 目录时不能宣称这些外部项完成。

1. 启动与基本显示（2026-06-20 已截图级通过）
   - `flutter build windows --release` 成功。
   - `Beat Saber Song Toolkit.exe` 可启动，窗口标题为 `Beat Saber Song Toolkit v0.1.0`。
   - 三个工作区首屏可见，主要按钮无挤压、无文字重叠。

2. 真实文件选择器（状态文案自动化已覆盖，系统对话框仍需人工点击）
   - 安装目录、本地歌曲目录、游戏目录、跳过目录、ZIP 目录、歌单路径、歌单保存路径、封面文件、LocalCache.saver、Android 目录等取消/成功状态文案已有 focused 测试覆盖。
   - 导出日志、导出结果、本次列表、当前过滤、收藏歌单、LocalCache 列表/摘要、deleted 报告、SongCore 路径复制等状态栏反馈已有 focused 测试覆盖。
   - 最终人工验收只需确认 Windows 系统文件/目录选择对话框本身能打开、取消和返回路径。

3. 破坏性确认弹窗（文案自动化已覆盖，最终只需 release 真实点击确认）
   - 自动化坐标点击在 Flutter Windows 上不稳定，不能作为通过证据；最终建议人工在临时目录/临时副本上抽样打开弹窗并取消。
   - 单首删除已安装歌曲。
   - 重复歌曲备份删除。
   - 单项/批量路径重命名。
   - 歌单同步仅移出歌单。
   - 歌单同步备份删除所选。
   - SongCore 保存列表移除条目。
   - 删除配置、清空封面缓存、清空 Hash 缓存。

4. 本地曲库工作区（工作区恢复和启动自动扫描已截图级通过）
   - 用真实样本安装目录扫描，确认半坏目录、重复项、路径建议筛选真实显示正常；半坏目录摘要、重复/路径建议语义已有 App widget 测试覆盖，最新 release 已截图确认真实 Tech 样本扫描后半坏目录摘要、路径建议筛选和前几条异常建议可见。
   - 当前过滤导出 `.bplist`，确认无 ID / 缺 `info.dat` 项跳过提示正常；跳过文案已有 App widget 测试覆盖。
   - 重复删除和路径重命名只在临时副本上验证，不直接修改真实样本。

5. 歌单同步工作区（工作区恢复和启动自动扫描已截图级通过，滚动结构自动化已覆盖）
   - 用真实样本 `.bplist` + 安装目录扫描，抽样确认表格固定表头、纵向滚动、横向滚动和筛选真实手感正常；固定表头、100 行滚到底、横向滚动同步和扩大表格高度已有 App widget 测试覆盖，最新 release 已截图确认真实 Tech 样本扫描后表头和首行可见。
   - 确认 `本地存在`、`本地缺失`、`Hash 匹配`、`名称不一致`、`缺 egg` 等状态显示清楚。
   - 仅移出歌单、备份删除所选只在临时副本上验证。

6. LocalCache 工作区（配置路径恢复和 `-fastlog` 页签可见性已截图级通过）
   - 使用项目根目录 `LocalCache.saver` 离线读取。
   - 检查快照年龄、增量信息、数据入本次/跳过、导出数据、导出摘要、审计删除导出按钮状态；最新 release 已截图确认离线读取后的数据量、快照年龄和主要控件可见。
   - 不在最终常规 GUI 验收中默认执行联网重建、增量或 deleted 审计，除非用户明确要求。

7. 队列与 ZIP 缓存（点击反馈自动化已覆盖，最终只需 release 手感抽验）
   - ZIP 缓存扫描、加入本次、加入跳过、导出入口可点击。
   - 停止队列、重试失败项、清空完成项、清空队列的点击反馈可读。

8. 启动参数（`-minimize` / `-local` / `-fastlog` 已做 release 抽样）
   - `-fastlog` 使用配置中的 `LocalCache.saver` 离线读取。
   - `-config`、`-local`、`-start`、`-zip`、`-unzip`、`-exit`、`-minimize` 保持既有 release 行为。

## 外部输入依赖

这些项目不能在没有外部条件时宣称完成：

- 项目自己的 release API 地址：当前默认留空；正式地址确定后，用 release exe 点击 `检查更新` 验证真实弹窗。
- GCP Vision API key：用户提供 key 后，验证真实封面识别、失败等待弹窗、封面缓存导出/清空。
- 泽宇缓存域名 `beatsaver.wgzeyu.vip`：当前仅保留兼容入口，不作为可靠默认源；域名恢复后再做真实下载验证。
- 原版默认 bplist 封面 `https://s.wgzeyu.com/BeatSpider/cover.jpg`：当前域名不可解析；域名恢复或用户提供样本后再补默认封面一致性。
- 用户真实 Beat Saber / SongCore 目录：如果用户愿意提供真实游戏目录，再人工验证 `folders.xml` 写入/读取/移除体验；否则只使用系统临时目录和真实样本副本验证。

## 验收命令建议

普通离线回归：

```powershell
D:\Software\flutter\bin\dart.bat run tool\final_acceptance_preflight.dart
D:\Software\flutter\bin\dart.bat run tool\toolbox_smoke.dart
D:\Software\flutter\bin\dart.bat analyze
cd apps\beat_saber_song_toolkit_app
D:\Software\flutter\bin\flutter.bat analyze
```

最终 release 构建：

```powershell
cd apps\beat_saber_song_toolkit_app
D:\Software\flutter\bin\flutter.bat build windows --release
```

release exe：

```text
apps\beat_saber_song_toolkit_app\build\windows\x64\runner\Release\Beat Saber Song Toolkit.exe
```

人工 GUI 验收启动器：

```powershell
D:\Software\flutter\bin\dart.bat run tool\release_manual_acceptance.dart --mode=library
D:\Software\flutter\bin\dart.bat run tool\release_manual_acceptance_smoke.dart
```

该命令使用临时 `APPDATA` 和临时 `CustomLevels` 曲库启动 release，适合打开破坏性确认弹窗后取消；也可使用 `--mode=playlistSync`、`--mode=fastlog` 或 `--mode=search` 做对应工作区抽样。
`release_manual_acceptance_smoke.dart` 会自动抽样四个启动模式并关闭窗口，适合作为人工点击前的启动器自检。
人工记录保存在本地私有资料中，不随公开仓库发布。
