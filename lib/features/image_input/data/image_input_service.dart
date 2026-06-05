import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../domain/pending_image.dart';

class ImageInputService {
  ImageInputService();

  final _picker = ImagePicker();

  String _newId() => 'img_${DateTime.now().microsecondsSinceEpoch}';

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Pick from device gallery (mobile) or file dialog (web/desktop).
  Future<PendingImage?> pickFromGallery() async {
    if (_isMobile) {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (xFile == null) return null;
      final bytes = await xFile.readAsBytes();
      return PendingImage(
        id: _newId(),
        bytes: bytes,
        mimeType: xFile.mimeType ?? 'image/jpeg',
        fileName: xFile.name,
      );
    }
    return _pickWithFilePicker();
  }

  /// Open camera — mobile only, returns null on other platforms.
  Future<PendingImage?> pickFromCamera() async {
    if (!_isMobile) return null;
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    final bytes = await xFile.readAsBytes();
    return PendingImage(
      id: _newId(),
      bytes: bytes,
      mimeType: xFile.mimeType ?? 'image/jpeg',
      fileName: xFile.name,
    );
  }

  /// Read an image from the system clipboard (Ctrl+V / ⌘V).
  Future<PendingImage?> pasteFromClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;
    final reader = await clipboard.read();

    final formats = <SimpleFileFormat>[
      Formats.png,
      Formats.jpeg,
      Formats.gif,
      Formats.webp,
    ];

    final format = formats.firstWhere(
      (f) => reader.canProvide(f),
      orElse: () => Formats.png,
    );
    if (!reader.canProvide(format)) return null;

    final completer = Completer<Uint8List?>();
    reader.getFile(format, (file) async {
      try {
        final bytes = await file.readAll();
        completer.complete(bytes);
      } catch (e) {
        completer.complete(null);
      }
    }, onError: (e) => completer.complete(null));

    final bytes = await completer.future;
    if (bytes == null) return null;
    return PendingImage(
      id: _newId(),
      bytes: bytes,
      mimeType: _mimeOf(format),
    );
  }

  /// Wrap raw bytes from a drag-drop event into a [PendingImage].
  PendingImage fromDroppedBytes(Uint8List bytes, String mimeType) {
    return PendingImage(id: _newId(), bytes: bytes, mimeType: mimeType);
  }

  // ---- private helpers ----

  Future<PendingImage?> _pickWithFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return null;
    return PendingImage(
      id: _newId(),
      bytes: file.bytes!,
      mimeType: _mimeFromExtension(file.extension),
      fileName: file.name,
    );
  }

  String _mimeOf(SimpleFileFormat format) {
    if (format == Formats.png) return 'image/png';
    if (format == Formats.jpeg) return 'image/jpeg';
    if (format == Formats.gif) return 'image/gif';
    return 'image/webp';
  }

  String _mimeFromExtension(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

final imageInputServiceProvider = Provider<ImageInputService>((ref) {
  return ImageInputService();
});
