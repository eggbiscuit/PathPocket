import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/config.dart' as config;
import '../domain/user.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;
  final String? code;

  bool get isPendingApproval => code == 'PENDING_APPROVAL';
  bool get isEmailNotVerified => code == 'EMAIL_NOT_VERIFIED';
  bool get isRejected => code == 'REJECTED';

  @override
  String toString() => 'AuthException[$code]: $message';
}

abstract class AuthRepository {
  Future<void> register(String email, String password, {String? displayName});
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> refresh(String refreshToken);
  Future<User> me(String accessToken);
}

/// Remote implementation backed by the PathPocket FastAPI backend.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              // Bypass ngrok's free-tier "Visit Site" interstitial, which
              // otherwise returns HTML instead of proxying to the backend.
              headers: {'ngrok-skip-browser-warning': 'true'},
            ));

  final Dio _dio;

  String get _base => config.backendBaseUrl;

  AuthException _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        return AuthException(
          detail['message'] as String? ?? '请求失败',
          code: detail['code'] as String?,
        );
      }
      if (detail is String) return AuthException(detail);
    }
    return AuthException('网络请求失败：${e.message ?? e.type.name}');
  }

  @override
  Future<void> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      await _dio.post('$_base/auth/register', data: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
      });
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    try {
      final resp = await _dio.post('$_base/auth/login', data: {
        'email': email,
        'password': password,
      });
      return _sessionFromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    try {
      final resp = await _dio.post(
        '$_base/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return _sessionFromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  @override
  Future<User> me(String accessToken) async {
    try {
      final resp = await _dio.get(
        '$_base/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return User.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  static AuthSession _sessionFromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

/// Mock used for widget tests and offline dev — no network required.
///
/// - Any well-formed email + password ≥ 6 chars succeeds immediately.
/// - Admin email pattern `admin@*` gets UserRole.admin.
class MockAuthRepository implements AuthRepository {
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  @override
  Future<void> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (!_emailRegex.hasMatch(email)) {
      throw const AuthException('请输入有效的邮箱地址');
    }
    if (password.length < 6) {
      throw const AuthException('密码至少 6 位');
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    if (!_emailRegex.hasMatch(email)) {
      throw const AuthException('请输入有效的邮箱地址');
    }
    if (password.length < 6) {
      throw const AuthException('邮箱或密码错误');
    }
    await Future.delayed(const Duration(milliseconds: 500));
    return _issueSession(email);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _issueSession('mock@pathpocket.dev');
  }

  @override
  Future<User> me(String accessToken) async {
    return const User(id: 'u_mock', email: 'mock@pathpocket.dev');
  }

  AuthSession _issueSession(String email) {
    final isAdmin = email.startsWith('admin@');
    final user = User(
      id: 'u_${email.replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      email: email,
      displayName: email.split('@').first,
      role: isAdmin ? UserRole.admin : UserRole.user,
      status: UserStatus.approved,
    );
    return AuthSession(
      user: user,
      accessToken: _fakeJwt(user),
      refreshToken: 'mock-refresh',
    );
  }

  String _fakeJwt(User user) {
    String b64(Map<String, dynamic> j) =>
        base64Url.encode(utf8.encode(jsonEncode(j))).replaceAll('=', '');
    final header = b64({'alg': 'none', 'typ': 'JWT'});
    final payload = b64({
      'sub': user.id,
      'email': user.email,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return '$header.$payload.mock';
  }
}
