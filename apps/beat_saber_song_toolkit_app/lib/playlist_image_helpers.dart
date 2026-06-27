import 'dart:convert';
import 'dart:io';

import 'package:beat_saber_song_toolkit/beat_saber_song_toolkit.dart';
import 'package:image/image.dart' as img;

Future<String?> playlistImageDataUrlForTest(File file) async {
  final mimeType = playlistImageMimeTypeForTest(file.path);
  final bytes = await file.readAsBytes();
  if (mimeType == null) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return null;
    }
    return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(image))}';
  }
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

String? playlistImageMimeTypeForTest(String path) {
  return playlistImageMimeType(path);
}
