import 'dart:async';
import 'dart:convert';

import '../domain/user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthRepository {
  Future<void> sendSmsCode(String phone);
  Future<AuthSession> verifySmsCode(String phone, String code);
  Future<AuthSession> loginWithPassword(String phone, String password);
}

/// Mock implementation used while no backend exists.
///
/// - Accepts any 11-digit Chinese mobile phone number.
/// - SMS code is fixed to `123456` (any code triggers logging but only the
///   fixed one passes verification).
/// - Issues a fake JWT-shaped token (base64url header.payload.signature) that
///   the rest of the app can ferry through interceptors without special-casing.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  static const String _validCode = '123456';

  static final RegExp _phoneRegex = RegExp(r'^1[3-9]\d{9}$');

  void _assertPhone(String phone) {
    if (!_phoneRegex.hasMatch(phone)) {
      throw const AuthException('请输入有效的手机号');
    }
  }

  @override
  Future<void> sendSmsCode(String phone) async {
    _assertPhone(phone);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<AuthSession> verifySmsCode(String phone, String code) async {
    _assertPhone(phone);
    if (code != _validCode) {
      await Future.delayed(const Duration(milliseconds: 300));
      throw const AuthException('验证码错误（mock 模式下固定为 123456）');
    }
    await Future.delayed(const Duration(milliseconds: 500));
    return _issueSession(phone);
  }

  @override
  Future<AuthSession> loginWithPassword(String phone, String password) async {
    _assertPhone(phone);
    if (password.length < 6) {
      throw const AuthException('密码至少 6 位');
    }
    await Future.delayed(const Duration(milliseconds: 500));
    return _issueSession(phone);
  }

  AuthSession _issueSession(String phone) {
    final user = User(
      id: 'u_$phone',
      phone: phone,
      displayName: '医生 ${phone.substring(phone.length - 4)}',
    );
    final token = _fakeJwt(user);
    return AuthSession(user: user, token: token);
  }

  String _fakeJwt(User user) {
    String b64(Map<String, dynamic> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final header = b64({'alg': 'none', 'typ': 'JWT'});
    final payload = b64({
      'sub': user.id,
      'phone': user.phone,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return '$header.$payload.mock';
  }
}
