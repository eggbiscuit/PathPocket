import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_token_store.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/wsi_repository.dart';
import '../domain/wsi_slide.dart';

final wsiRepositoryProvider = Provider<WsiRepository>((ref) {
  return WsiRepository(ref.read(secureTokenStoreProvider));
});

/// The current user's slides. Watches the user so switching accounts refetches
/// and never leaks another user's list.
final slidesProvider = FutureProvider.autoDispose<List<WsiSlide>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.watch(wsiRepositoryProvider).list();
});

class UploadState {
  const UploadState({this.isUploading = false, this.progress = 0, this.error});
  final bool isUploading;
  final double progress; // 0..1
  final String? error;

  UploadState copyWith({bool? isUploading, double? progress, String? error, bool clearError = false}) =>
      UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
      );
}

class UploadNotifier extends Notifier<UploadState> {
  CancelToken? _cancel;

  @override
  UploadState build() => const UploadState();

  Future<void> uploadPicked(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      state = state.copyWith(error: '无法读取文件内容');
      return;
    }
    await _upload(bytes, file.name);
  }

  Future<void> _upload(Uint8List bytes, String filename) async {
    _cancel = CancelToken();
    state = const UploadState(isUploading: true, progress: 0);
    try {
      await ref.read(wsiRepositoryProvider).upload(
            bytes,
            filename,
            cancelToken: _cancel,
            onProgress: (sent, total) {
              if (total > 0) {
                state = state.copyWith(progress: sent / total);
              }
            },
          );
      state = const UploadState(isUploading: false, progress: 1);
      ref.invalidate(slidesProvider);
    } on WsiException catch (e) {
      state = state.copyWith(isUploading: false, error: e.message);
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        state = const UploadState();
      } else {
        state = state.copyWith(isUploading: false, error: '上传失败');
      }
    }
  }

  void cancel() {
    _cancel?.cancel();
    state = const UploadState();
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);
