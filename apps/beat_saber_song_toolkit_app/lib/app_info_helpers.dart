const appVersionForTest = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0',
);

String donateAuthorMessageForTest() =>
    '参考项目与原作者信息：\n'
    'WGzeyu / BeatSpider：\n'
    'https://github.com/WGzeyu/BeatSpider\n\n'
    'WGzeyu / Beat-Saber-Song-Folder-Manager：\n'
    'https://github.com/WGzeyu/Beat-Saber-Song-Folder-Manager\n\n'
    'fc525260 / Beat-Saber-Playlist-File-Sync：\n'
    'https://github.com/fc525260/Beat-Saber-Playlist-File-Sync\n\n'
    '本项目是把上述工作流重新整理为 Beat Saber Song Toolkit 的 Flutter/Dart 工具箱，'
    '全程由 GPT-5.5 协助完成。\n\n'
    '如果这个工具对你有用，可以赞助我一点，用于收回使用大模型的成本。';
