import 'package:web/web.dart' as web;

import 'secure_token_store.dart';

class _WebSessionTokenStore implements SecureTokenStore {
  @override
  Future<String?> read(String key) async {
    final value = web.window.sessionStorage.getItem(key);
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    web.window.sessionStorage.setItem(key, value);
  }

  @override
  Future<void> delete(String key) async {
    web.window.sessionStorage.removeItem(key);
  }

  @override
  Future<void> clear() async {
    web.window.sessionStorage.clear();
  }
}

SecureTokenStore createPlatformSecureTokenStore(SecureTokenStore _mobileStore) =>
    _WebSessionTokenStore();
