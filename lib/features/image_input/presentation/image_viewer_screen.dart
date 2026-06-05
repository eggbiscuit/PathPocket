import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Full-screen pinch-zoom image viewer.
///
/// Supports both in-memory [bytes] and a network [uri] (data:// or https://).
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen._({this.bytes, this.uri, this.heroTag});

  final Uint8List? bytes;
  final String? uri;
  final String? heroTag;

  factory ImageViewerScreen.fromBytes({
    required Uint8List bytes,
    String? heroTag,
  }) =>
      ImageViewerScreen._(bytes: bytes, heroTag: heroTag);

  factory ImageViewerScreen.fromUri({
    required String uri,
    String? heroTag,
  }) =>
      ImageViewerScreen._(uri: uri, heroTag: heroTag);

  @override
  Widget build(BuildContext context) {
    final ImageProvider imageProvider;
    if (bytes != null) {
      imageProvider = MemoryImage(bytes!);
    } else if (uri!.startsWith('data:')) {
      imageProvider = MemoryImage(_decodeDataUri(uri!));
    } else {
      imageProvider = NetworkImage(uri!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PhotoView(
        imageProvider: imageProvider,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        heroAttributes: heroTag != null
            ? PhotoViewHeroAttributes(tag: heroTag!)
            : null,
        loadingBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  static Uint8List _decodeDataUri(String dataUri) {
    // data:[<mime>][;base64],<data>
    final comma = dataUri.indexOf(',');
    if (comma == -1) return Uint8List(0);
    final b64 = dataUri.substring(comma + 1);
    return Uri.parse('data:application/octet-stream;base64,$b64')
        .data!
        .contentAsBytes();
  }
}
