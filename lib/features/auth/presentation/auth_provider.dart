import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/tab_sync.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/app_database.dart' show AppDatabase, databaseProvider;
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

const String _tokenKey = 'auth.token';
const String _userKey = 'auth.user';

/// Hook used by other features (chat, conversations, ...) to register
/// teardown work that must complete before a user is logged out.
///
/// Logout is structured so that `await Future.wait(hooks)` runs before the
/// token is cleared and the new user takes over. This is what prevents
/// in-flight assistant streams of user A from writing into user B's
/// conversation history after a logout / user switch.
typedef LogoutHook = Future<void> Function();

class _LogoutHookRegistry {
  final List<LogoutHook> _hooks = [];

  void Function() register(LogoutHook hook) {
    _hooks.add(hook);
    return () => _hooks.remove(hook);
  }

  Future<void> runAll() async {
    if (_hooks.isEmpty) return;
    await Future.wait(_hooks.map((h) => h()).toList(growable: false));
  }
}

final _logoutHookRegistryProvider = Provider<_LogoutHookRegistry>(
  (ref) => _LogoutHookRegistry(),
);

void Function() registerLogoutHook(Ref ref, LogoutHook hook) =>
    ref.read(_logoutHookRegistryProvider).register(hook);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final User? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final SecureTokenStore _tokens;
  late final AppDatabase _db;
  late final TabSync _tabSync;
  StreamSubscription<TabSyncEvent>? _tabSub;

  @override
  AuthState build() {
    _repo = ref.read(authRepositoryProvider);
    _tokens = ref.read(secureTokenStoreProvider);
    _db = ref.read(databaseProvider);
    _tabSync = ref.read(tabSyncProvider);
    _tabSub = _tabSync.events.listen(_onTabEvent);
    ref.onDispose(() => _tabSub?.cancel());

    // Restore session from secure storage on app start.
    unawaited(_restoreSession());
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final token = await _tokens.read(_tokenKey);
    final userJson = await _tokens.read(_userKey);
    if (token == null || userJson == null) return;
    try {
      final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      await _persistUser(user);
      state = state.copyWith(user: user);
    } catch (_) {
      await _tokens.clear();
    }
  }

  void _onTabEvent(TabSyncEvent event) async {
    switch (event) {
      case LoggedOutEvent():
        await _localLogout(broadcast: false);
      case UserChangedEvent(:final userId):
        if (state.user?.id != userId) {
          await _localLogout(broadcast: false);
        }
    }
  }

  Future<void> sendSmsCode(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.sendSmsCode(phone);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      rethrow;
    }
  }

  Future<void> verifySmsCode(String phone, String code) async {
    await _completeLogin(() => _repo.verifySmsCode(phone, code));
  }

  Future<void> loginWithPassword(String phone, String password) async {
    await _completeLogin(() => _repo.loginWithPassword(phone, password));
  }

  Future<void> _completeLogin(Future<AuthSession> Function() doLogin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await doLogin();
      await _tokens.write(_tokenKey, session.token);
      await _tokens.write(_userKey, jsonEncode(session.user.toJson()));
      await _persistUser(session.user);
      state = state.copyWith(user: session.user, isLoading: false);
      _tabSync.publish(UserChangedEvent(session.user.id));
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _localLogout(broadcast: true);
  }

  /// Internal logout path used by both user-initiated logout and the
  /// cross-tab `LoggedOutEvent` listener.
  Future<void> _localLogout({required bool broadcast}) async {
    // Wait for in-flight per-user work (e.g. chat streams) to fully tear down
    // BEFORE clearing the token. This is the single most important contract
    // for multi-user state isolation.
    await ref.read(_logoutHookRegistryProvider).runAll();

    await _tokens.delete(_tokenKey);
    await _tokens.delete(_userKey);

    state = const AuthState();

    if (broadcast) {
      _tabSync.publish(const LoggedOutEvent());
    }
  }

  Future<void> _persistUser(User user) {
    return _db.upsertUser(db.UsersCompanion.insert(
      id: user.id,
      phone: user.phone,
      displayName: Value(user.displayName),
    ));
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider.select((s) => s.user));
});
