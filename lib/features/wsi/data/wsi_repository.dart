import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config.dart' as config;
import '../../../core/storage/secure_token_store.dart';
import '../domain/wsi_slide.dart';

class WsiException implements Exception {
  const WsiException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => 'WsiException[$code]: $message';
}

/// Talks to the backend `/wsi` endpoints. Same Dio conventions as
/// [RemoteAuthRepository]: ngrok-skip header + Bearer token from the store.
class WsiRepository {
  WsiRepository(this._tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': 'true'}));

  final SecureTokenStore _tokens;
  final Dio _dio;

  String get _base => config.backendBaseUrl;

  Future<String?> _token() => _tokens.read('auth.token');

  String slideBaseUrl(String id) => '$_base/wsi/slides/$id';
  String dziUrl(String id) => '$_base/wsi/slides/$id/dzi';

  WsiException _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        return WsiException(
          detail['message'] as String? ?? '请求失败',
          code: detail['code'] as String?,
        );
      }
      if (detail is String) return WsiException(detail);
    }
    return WsiException('网络请求失败：${e.message ?? e.type.name}');
  }

  Future<List<WsiSlide>> list() async {
    try {
      final token = await _token();
      final resp = await _dio.get(
        '$_base/wsi/slides',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (resp.data as List)
          .map((e) => WsiSlide.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<WsiSlide> upload(
    Uint8List bytes,
    String filename, {
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final token = await _token();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final resp = await _dio.post(
        '$_base/wsi/slides',
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          // Large uploads (hundreds of MB) must not hit a timeout.
          sendTimeout: null,
          receiveTimeout: null,
        ),
      );
      return WsiSlide.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final token = await _token();
      await _dio.delete(
        '$_base/wsi/slides/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// Fetches a slide thumbnail as bytes. Needed because the endpoint requires a
  /// Bearer header, so a plain `Image.network` can't authenticate.
  Future<Uint8List> thumbnail(String id) async {
    final token = await _token();
    final resp = await _dio.get<List<int>>(
      '$_base/wsi/slides/$id/thumbnail',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(resp.data ?? const []);
  }
}
