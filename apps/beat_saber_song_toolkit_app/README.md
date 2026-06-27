# Beat Saber Song Toolkit App

Flutter desktop/mobile UI for Beat Saber Song Toolkit.

## Verify

Run from this directory:

```powershell
D:\Software\flutter\bin\flutter.bat analyze
D:\Software\flutter\bin\flutter.bat test test\widget_test.dart
```

Build the Windows release only when GUI/release validation is needed:

```powershell
D:\Software\flutter\bin\flutter.bat build windows --release
```

The release executable is:

```text
build\windows\x64\runner\Release\Beat Saber Song Toolkit.exe
```

Routine app work should stop at `flutter analyze` and focused widget tests.
Before final GUI sign-off, follow:

```text
..\..\docs\FINAL_ACCEPTANCE_CHECKLIST_CN.md
```

## Mainland China Mirrors

Use mirrors before running Flutter or Dart commands when network access to
official upstreams is slow:

```powershell
$env:PUB_HOSTED_URL="https://mirrors.cloud.tencent.com/dart-pub"
$env:FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
```

The Android Gradle project also prefers Aliyun Maven mirrors before official
Google/Maven Central repositories.

## Android Notes

- Package name remains `app.beatspider.reborn` for compatibility unless a future
  release explicitly migrates Android identity.
- Android label: `Beat Saber Song Toolkit`
- Network permission: `android.permission.INTERNET`

Android and Meta Quest builds require Android SDK:

```powershell
D:\Software\flutter\bin\flutter.bat doctor -v
D:\Software\flutter\bin\flutter.bat build apk --debug
```

The UI currently uses typed filesystem paths. Desktop workflows are the main
verified target; Quest custom song folder access still needs full Android
Storage Access Framework write integration before release use.
