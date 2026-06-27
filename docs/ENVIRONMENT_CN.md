# Mainland China Development Environment

This project should prefer mirrors because access to upstream Flutter, Dart,
Gradle, Google Maven, and Maven Central can be slow or blocked in mainland
China.

## PowerShell Session

Run these before `flutter` or `dart` commands:

```powershell
$env:PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"
$env:FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
```

## Android Gradle

The Flutter app's Android project prefers Aliyun Maven mirrors first:

- `https://maven.aliyun.com/repository/google`
- `https://maven.aliyun.com/repository/central`
- `https://maven.aliyun.com/repository/public`
- `https://maven.aliyun.com/repository/gradle-plugin`

Official repositories are kept as fallback.

## Current Toolchain Status

As of the last local check:

- Visual Studio Build Tools 2022 is installed with C++ desktop build tools.
- Android SDK is installed through Scoop `android-clt`.
- Android SDK path is configured:

```powershell
flutter config --android-sdk D:\scoop\apps\android-clt\current
```

- OpenJDK 17 is installed through Scoop `openjdk17`.
- Debug APK builds successfully:

```text
apps/beat_saber_song_toolkit_app/build/app/outputs/flutter-apk/app-debug.apk
```

- Windows debug build succeeds:

```text
apps/beat_saber_song_toolkit_app/build/windows/x64/runner/Debug/Beat Saber Song Toolkit.exe
```

Remaining gaps:

- Quest/Android device testing needs a connected device visible in `adb devices`.

Use:

```powershell
flutter doctor -v
```

to verify both.
