enum SlideStatus { uploading, ready, failed }

SlideStatus _statusFromString(String s) {
  switch (s) {
    case 'ready':
      return SlideStatus.ready;
    case 'failed':
      return SlideStatus.failed;
    default:
      return SlideStatus.uploading;
  }
}

/// A whole-slide image uploaded by the current user. Mirrors the backend
/// `SlideOut` schema; list/metadata come from the backend (no local Drift row).
class WsiSlide {
  const WsiSlide({
    required this.id,
    required this.originalFilename,
    required this.fmt,
    required this.fileSize,
    required this.status,
    required this.createdAt,
    this.width,
    this.height,
  });

  final String id;
  final String originalFilename;
  final String fmt;
  final int fileSize;
  final SlideStatus status;
  final DateTime createdAt;
  final int? width;
  final int? height;

  bool get isReady => status == SlideStatus.ready;

  factory WsiSlide.fromJson(Map<String, dynamic> json) => WsiSlide(
        id: json['id'] as String,
        originalFilename: json['original_filename'] as String,
        fmt: json['fmt'] as String,
        fileSize: (json['file_size'] as num).toInt(),
        status: _statusFromString(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
      );
}
