# Beat Saber Song Toolkit App

这是 Beat Saber Song Toolkit 的 Flutter 图形界面应用，主要验证目标是 Windows 桌面端。

## 常用命令

在本目录运行：

```powershell
flutter analyze
flutter test test/widget_test.dart
```

需要进行 GUI 或发行版验证时，再构建 Windows release：

```powershell
flutter build windows --release
```

构建完成后的可执行文件位于：

```text
build/windows/x64/runner/Release/Beat Saber Song Toolkit.exe
```

普通开发通常只需要运行 `flutter analyze` 和相关 widget 测试。最终 GUI 验收前参考：

```text
../../docs/FINAL_ACCEPTANCE_CHECKLIST_CN.md
```

## 网络镜像

如果当前网络访问 Flutter 或 pub.dev 较慢，可在运行依赖安装或构建命令前设置镜像：

```powershell
$env:PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"
$env:FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
```

Android Gradle 项目也配置了优先使用阿里云 Maven 镜像。

## Android 说明

- Android package name 当前仍为 `app.beatspider.reborn`，用于兼容历史工程结构。
- Android 应用名称为 `Beat Saber Song Toolkit`。
- Android 网络权限为 `android.permission.INTERNET`。

Android 和 Meta Quest 构建需要本机配置 Android SDK：

```powershell
flutter doctor -v
flutter build apk --debug
```

当前 UI 主要使用手动输入或选择文件系统路径。桌面端流程是主要已验证目标；Quest 自定义歌曲目录写入仍需要进一步完善 Android Storage Access Framework 集成后再作为正式能力使用。
