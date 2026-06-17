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
            backgroundColor: context.palette.error,
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
    final p = context.palette;

    final options = _isMobile
        ? [
            (
              icon: Icons.photo_library_outlined,
              label: '相册',
              onTap: () => _handle(() => service.pickFromGallery()),
            ),
            (
              icon: Icons.camera_alt_outlined,
              label: '拍摄',
              onTap: () => _handle(() => service.pickFromCamera()),
            ),
          ]
        : [
            (
              icon: Icons.folder_open_outlined,
              label: '文件',
              onTap: () => _handle(() => service.pickFromGallery()),
            ),
            (
              icon: Icons.content_paste_outlined,
              label: '剪贴板',
              onTap: () => _handle(() => service.pasteFromClipboard()),
            ),
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _loading
            ? SizedBox(
                height: 96,
                child: Center(
                  child: CircularProgressIndicator(color: p.primary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: p.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (final o in options)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _IconCard(
                            icon: o.icon,
                            label: o.label,
                            onTap: o.onTap,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: p.primary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.caption(context)),
        ],
      ),
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
