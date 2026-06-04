import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web/web.dart' as web;

/// Cross-platform secure(-ish) token storage.
///
/// - Mobile/desktop: backed by [FlutterSecureStorage] (Keychain on iOS,
///   EncryptedSharedPreferences on Android, etc.).
/// - Web: backed by `sessionStorage` so tokens are scoped per-tab. This is the
///   right default for the mock phase since it makes multi-tab user-isolation
///   testing trivial. Switch to HttpOnly cookies set by the backend once a
///   real auth service is wired up.
abstract class SecureTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class _MobileSecureTokenStore implements SecureTokenStore {
  _MobileSecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> clear() => _storage.deleteAll();
}

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

SecureTokenStore createSecureTokenStore() {
  if (kIsWeb) return _WebSessionTokenStore();
  return _MobileSecureTokenStore();
}

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  throw UnimplementedError(
    'secureTokenStoreProvider must be overridden in main() with a value '
    'returned by createSecureTokenStore().',
  );
});
