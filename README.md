# Beat Saber Song Toolkit

Beat Saber Song Toolkit 是一个面向 Beat Saber 自定义歌曲的 Flutter/Dart 工具箱，当前版本为 `0.1.0`。它提供歌曲搜索下载、歌单同步、本地曲库管理和本地缓存维护能力。

本项目参考并整合了以下项目的主要使用场景：

- [WGzeyu/BeatSpider](https://github.com/WGzeyu/BeatSpider)
- [WGzeyu/Beat-Saber-Song-Folder-Manager](https://github.com/WGzeyu/Beat-Saber-Song-Folder-Manager)
- [fc525260/Beat-Saber-Playlist-File-Sync](https://github.com/fc525260/Beat-Saber-Playlist-File-Sync)

## 功能概览

- **找歌下载**：搜索 BeatSaver 歌曲，加入本次列表或跳过列表，下载 ZIP，安装歌曲，并可导出歌单。
- **本地曲库**：扫描已安装歌曲，识别缺失 `info.dat`、重复歌曲、路径建议，支持导出 `.bplist`、读取收藏、管理 SongCore `folders.xml`。
- **歌单同步**：将 `.bplist` 与本地曲库逐项对比，区分“本地有，歌单有”“本地无，歌单有”“本地有，歌单无”，并支持缺失歌曲的保守下载/安装流程。
- **本地缓存**：读取、校验、构建和增量更新 `LocalCache.saver`，支持暂停/恢复快照构建，并以报告形式审计 BeatSaver deleted 数据。
- **CLI 与 smoke 工具**：提供命令行入口和一组离线 smoke 脚本，便于回归验证核心逻辑。

## 项目结构

```text
.
├── apps/beat_saber_song_toolkit_app/   # Flutter GUI 应用
├── bin/beat_saber_song_toolkit.dart    # CLI 入口
├── lib/                                # Dart 核心库
├── tool/                               # smoke / 维护脚本
├── test/                               # 根包测试
├── docs/                               # 公开文档与验收清单
└── .github/workflows/                  # GitHub Actions 构建配置
```

Windows release 构建完成后的可执行文件位于：

```text
apps/beat_saber_song_toolkit_app/build/windows/x64/runner/Release/Beat Saber Song Toolkit.exe
```

本地构建产物、缓存文件、真实样本和私有交接资料不会进入仓库。

## 安装与使用

### 下载发行版

建议从 GitHub Releases 下载 Windows x64 压缩包，解压后运行：

```text
Beat Saber Song Toolkit.exe
```

当前仓库通过 GitHub Actions 构建 Windows 发行包。构建产物不会提交到源码仓库。

### 从源码运行

需要先安装 Flutter，并确保 `flutter` 与 `dart` 命令可在终端中使用。

```powershell
git clone https://github.com/fc525260/Beat-Saber-Song-Toolkit.git
cd Beat-Saber-Song-Toolkit
flutter pub get
```

运行桌面应用：

```powershell
cd apps/beat_saber_song_toolkit_app
flutter run -d windows
```

构建 Windows release：

```powershell
cd apps/beat_saber_song_toolkit_app
flutter build windows --release
```

中国大陆网络环境下，如果访问官方源较慢，可在运行依赖安装或构建命令前设置镜像：

```powershell
$env:PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"
$env:FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
```

## CLI 示例

从仓库根目录运行：

```powershell
dart run bin/beat_saber_song_toolkit.dart --help
dart run bin/beat_saber_song_toolkit.dart --query "camellia" --allow-network
dart run bin/beat_saber_song_toolkit.dart --download-id 1520 --out downloads --allow-network
dart run bin/beat_saber_song_toolkit.dart --install-id 1520 --install-out songs --allow-network
dart run bin/beat_saber_song_toolkit.dart --list-installed --install-out songs
dart run bin/beat_saber_song_toolkit.dart --export-bplist playlists/songs.bplist --install-out songs
```

安全限制：

- 搜索、下载、安装、导入等联网操作必须显式传入 `--allow-network`。
- 删除本地歌曲目录必须显式传入 `--yes-delete`。
- 常规分析、测试和 smoke 命令默认离线，不会访问 BeatSaver。

## 本地缓存

`LocalCache.saver` 是用于离线查询 BeatSaver 谱面信息的本地快照文件。项目支持：

- 读取已有 `LocalCache.saver`；
- 通过 BeatSaver `/maps/latest` 构建完整快照；
- 暂停并恢复快照构建；
- 基于现有快照进行增量更新；
- 校验缓存结构；
- 审计 `/maps/deleted` 候选项并导出报告。

缓存更新是显式维护操作，不会在普通测试中自动联网。deleted 审计只生成报告，不会自动删除缓存条目。

常用离线检查：

```powershell
dart run tool/local_cache_inspect.dart LocalCache.saver
dart run tool/local_cache_validate.dart --cache=LocalCache.saver
```

需要联网更新时，明确传入 `--allow-network`：

```powershell
dart run tool/local_cache_update.dart --cache=LocalCache.saver --allow-network
```

## 开发与测试

根包检查：

```powershell
dart analyze
dart test
dart run tool/toolbox_smoke.dart
```

Flutter 应用检查：

```powershell
cd apps/beat_saber_song_toolkit_app
flutter analyze
flutter test test/widget_test.dart
```

最终 release 人工验收可参考：

```text
docs/FINAL_ACCEPTANCE_CHECKLIST_CN.md
```

## 配置位置

Windows 下，应用配置默认保存在：

```text
%APPDATA%/BeatSaberSongToolkit
```

如果旧版 `%APPDATA%/BeatSpiderReborn/settings.json` 存在，首次启动时可能会导入旧配置以兼容历史数据。

## 外部依赖边界

以下能力需要用户自行提供或等待外部服务可用：

- 项目自己的 release update API URL；
- GCP Vision API key；
- 原版 BeatSpider default playlist cover sample；
- 泽宇缓存兼容域名。

`泽宇缓存(兼容)` 仅作为兼容入口保留，不应视为当前默认可靠数据源。

## 致谢

感谢 WGzeyu 的 BeatSpider 与 Beat Saber Song Folder Manager，以及 fc525260 的 Beat Saber Playlist File Sync。本项目在这些项目的使用场景基础上，用 Flutter/Dart 重新实现并扩展为统一工具箱。

本项目开发过程由 GPT-5.5 全程辅助完成。

## 免责声明

本项目是非官方工具，与 Beat Games、Meta、Beat Saber 或 BeatSaver 没有关联。请遵守相关平台、游戏和谱面作者的使用规则。联网功能会访问第三方服务，请自行确认网络环境与使用风险。
