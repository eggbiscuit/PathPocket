import 'dart:typed_data';

/// A single image selected / pasted / dropped by the user, held in memory
/// until the message is sent. At send-time these are embedded as data-URIs
/// (mock) or uploaded to the backend (Phase 4).
class PendingImage {
  const PendingImage({
    required this.id,
    required this.bytes,
    required this.mimeType,
    this.width,
    this.height,
    this.fileName,
    this.roi,
  });

  final String id;
  final Uint8List bytes;
  final String mimeType;
  final int? width;
  final int? height;
  final String? fileName;

  /// Region of interest as fractional offsets {left, top, right, bottom}.
  final Map<String, double>? roi;

  PendingImage copyWith({
    Uint8List? bytes,
    Map<String, double>? roi,
    int? width,
    int? height,
  }) {
    return PendingImage(
      id: id,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      fileName: fileName,
      roi: roi ?? this.roi,
    );
  }

  /// Encode to a data-URI (used in mock mode instead of a CDN URL).
  String get dataUri {
    final b64 = _base64Encode(bytes);
    return 'data:$mimeType;base64,$b64';
  }

  static String _base64Encode(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final out = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      out.write(chars[(b0 >> 2) & 63]);
      out.write(chars[((b0 << 4) | (b1 >> 4)) & 63]);
      out.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 63] : '=');
      out.write(i + 2 < bytes.length ? chars[b2 & 63] : '=');
    }
    return out.toString();
  }
}
