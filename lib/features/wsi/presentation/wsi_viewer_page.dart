import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_token_store.dart';
import 'wsi_providers.dart';
import 'wsi_viewer_platform.dart' as platform;

/// Full-screen OpenSeadragon viewer for a single slide.
class WsiViewerPage extends ConsumerWidget {
  const WsiViewerPage({super.key, required this.slideId});
  final String slideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(wsiRepositoryProvider);
    final token = ref.read(secureTokenStoreProvider).read('auth.token');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('切片预览', style: TextStyle(fontSize: 16)),
      ),
      body: FutureBuilder<String?>(
        future: token,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = snap.data;
          if (t == null || t.isEmpty) {
            return const Center(
              child: Text('登录状态失效，请重新登录。',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          return platform.buildWsiViewer(
            viewType: 'wsi-osd-$slideId',
            dziUrl: repo.dziUrl(slideId),
            tileBase: repo.slideBaseUrl(slideId),
            token: t,
          );
        },
      ),
    );
  }
}
