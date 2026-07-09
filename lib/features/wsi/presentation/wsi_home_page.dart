import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../domain/wsi_slide.dart';
import 'wsi_providers.dart';

class WsiHomePage extends ConsumerWidget {
  const WsiHomePage({super.key});

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['svs', 'tiff', 'tif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    await ref.read(uploadControllerProvider.notifier).uploadPicked(result.files.first);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final upload = ref.watch(uploadControllerProvider);
    final slides = ref.watch(slidesProvider);

    return Scaffold(
      backgroundColor: p.bgPage,
      appBar: AppBar(
        backgroundColor: p.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textSecondary),
          onPressed: () => context.go('/'),
        ),
        title: Text('全切片图像', style: TextStyle(color: p.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UploadBar(upload: upload, onPick: () => _pickAndUpload(ref)),
          const Divider(height: 1),
          Expanded(
            child: slides.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('加载失败：$e', style: TextStyle(color: p.error)),
              ),
              data: (list) => _SlideList(slides: list),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}

class _SlideList extends StatelessWidget {
  const _SlideList({required this.slides});
  final List<WsiSlide> slides;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (slides.isEmpty) {
      return Center(
        child: Text('还没有切片，点击右上角上传。',
            style: TextStyle(color: p.textTertiary, fontSize: 14)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: slides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _SlideCard(slide: slides[i]),
    );
  }
}

class _UploadBar extends StatelessWidget {
  const _UploadBar({required this.upload, required this.onPick});
  final UploadState upload;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '支持 .svs / .tiff 格式，上传后可平移缩放预览。',
                  style: TextStyle(color: p.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: upload.isUploading ? null : onPick,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(upload.isUploading ? '上传中…' : '上传切片'),
              ),
            ],
          ),
          if (upload.isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: upload.progress),
            ),
            const SizedBox(height: 4),
            Text('${(upload.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: p.textTertiary, fontSize: 12)),
          ],
          if (upload.error != null) ...[
            const SizedBox(height: 8),
            Text(upload.error!, style: TextStyle(color: p.error, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _SlideCard extends ConsumerWidget {
  const _SlideCard({required this.slide});
  final WsiSlide slide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final ready = slide.isReady;
    return Material(
      color: p.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: ready ? () => context.push('/wsi/view/${slide.id}') : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(slideId: slide.id, ready: ready),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slide.originalFilename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      ready && slide.width != null
                          ? '${slide.width}×${slide.height} · ${_formatSize(slide.fileSize)} · ${slide.fmt}'
                          : _formatSize(slide.fileSize),
                      style: TextStyle(color: p.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('处理中',
                      style: TextStyle(color: p.textTertiary, fontSize: 12)),
                ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: p.textTertiary, size: 20),
                tooltip: '删除',
                onPressed: () async {
                  await ref.read(wsiRepositoryProvider).delete(slide.id);
                  ref.invalidate(slidesProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.slideId, required this.ready});
  final String slideId;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    Widget placeholder(Widget child) => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.bgInput,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: child,
        );
    if (!ready) {
      return placeholder(
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.textTertiary),
        ),
      );
    }
    return FutureBuilder(
      future: ref.read(wsiRepositoryProvider).thumbnail(slideId),
      builder: (_, snap) {
        if (snap.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.memory(snap.data!, width: 56, height: 56, fit: BoxFit.cover),
          );
        }
        return placeholder(
          Icon(Icons.biotech_outlined, color: p.textTertiary, size: 22),
        );
      },
    );
  }
}
