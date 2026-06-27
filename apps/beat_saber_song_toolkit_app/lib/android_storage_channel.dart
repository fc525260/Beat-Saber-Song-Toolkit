import 'dart:io';

import 'package:flutter/services.dart';

class AndroidStorageChannel {
  const AndroidStorageChannel();

  static const _channel = MethodChannel('app.beatspider.reborn/storage');

  bool get isSupported => Platform.isAndroid;

  Future<String?> pickDirectory() async {
    if (!isSupported) {
      return null;
    }
    return _channel.invokeMethod<String>('pickDirectory');
  }

  Future<void> writeFile({
    required String treeUri,
    required String relativePath,
    required List<int> bytes,
  }) async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('writeFile', {
      'treeUri': treeUri,
      'relativePath': relativePath,
      'bytes': Uint8List.fromList(bytes),
    });
  }
}
