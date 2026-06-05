import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/theme.dart';
import '../data/image_input_service.dart';
import '../domain/pending_image.dart';
import 'roi_cropper_screen.dart';

/// Bottom sheet / modal for picking an image, with optional ROI crop.
///
/// Returns a [PendingImage] via [Navigator.pop] or null if cancelled.
class ImagePickerSheet extends ConsumerStatefulWidget {
  const ImagePickerSheet({super.key});

  @override
  ConsumerState<ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends ConsumerState<ImagePickerSheet> {
  bool _loading = false;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _handle(Future<PendingImage?> Function() pick) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final img = await pick();
      if (!mounted) return;
      if (img == null) {
        Navigator.pop(context);
        return;
      }
      final result = await _maybeCrop(img);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选取失败：$e'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<PendingImage> _maybeCrop(PendingImage img) async {
    final cropped = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => RoiCropperScreen(imageBytes: img.bytes),
        fullscreenDialog: true,
      ),
    );
    if (cropped == null) return img; // user skipped crop
    return img.copyWith(bytes: cropped);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(imageInputServiceProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (_isMobile) ...[
                    _Tile(
                      icon: Icons.photo_library_outlined,
                      label: '从相册选择',
                      onTap: () =>
                          _handle(() => service.pickFromGallery()),
                    ),
                    _Tile(
                      icon: Icons.camera_alt_outlined,
                      label: '拍摄照片',
                      onTap: () =>
                          _handle(() => service.pickFromCamera()),
                    ),
                  ] else ...[
                    _Tile(
                      icon: Icons.folder_open_outlined,
                      label: '从文件选择',
                      onTap: () =>
                          _handle(() => service.pickFromGallery()),
                    ),
                    _Tile(
                      icon: Icons.content_paste_outlined,
                      label: '从剪贴板粘贴',
                      onTap: () =>
                          _handle(() => service.pasteFromClipboard()),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// Drop target overlay that captures image files dragged onto the chat area.
///
/// Wraps [child] and calls [onDropped] when an image is dropped.
class ImageDropTarget extends ConsumerWidget {
  const ImageDropTarget({
    super.key,
    required this.child,
    required this.onDropped,
  });

  final Widget child;
  final void Function(PendingImage image) onDropped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb == false &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.linux) {
      return child; // drag-drop only meaningful on desktop/web
    }
    final service = ref.read(imageInputServiceProvider);
    return DropRegion(
      formats: Formats.standardFormats,
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onPerformDrop: (event) async {
        for (final item in event.session.items) {
          final reader = item.dataReader!;
          for (final format in [Formats.png, Formats.jpeg, Formats.webp]) {
            if (!reader.canProvide(format)) continue;
            reader.getFile(format, (file) async {
              final bytes = await file.readAll();
              final img = service.fromDroppedBytes(
                bytes,
                format == Formats.png
                    ? 'image/png'
                    : format == Formats.jpeg
                        ? 'image/jpeg'
                        : 'image/webp',
              );
              onDropped(img);
            });
            break;
          }
        }
      },
      child: child,
    );
  }
}
