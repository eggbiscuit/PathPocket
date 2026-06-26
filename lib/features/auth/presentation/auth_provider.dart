import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart' as config;
import '../../../core/platform/tab_sync.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/app_database.dart' show AppDatabase, databaseProvider;
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

const String _accessTokenKey = 'auth.token';
const String _refreshTokenKey = 'auth.refresh';
const String _userKey = 'auth.user';

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
  return config.useMock ? MockAuthRepository() : RemoteAuthRepository();
});

/// What's blocking login after a valid credential submission.
enum AuthBlocker { none, emailNotVerified, pendingApproval, rejected }

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.blocker = AuthBlocker.none,
    this.registerSuccess = false,
  });

  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final AuthBlocker blocker;
  /// True briefly after a successful registration (shows the "check your email" screen).
  final bool registerSuccess;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    AuthBlocker? blocker,
    bool? registerSuccess,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      blocker: blocker ?? (clearError ? AuthBlocker.none : this.blocker),
      registerSuccess: registerSuccess ?? this.registerSuccess,
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
    unawaited(_restoreSession());
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final token = await _tokens.read(_accessTokenKey);
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

  Future<void> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.register(email, password, displayName: displayName);
      state = state.copyWith(isLoading: false, registerSuccess: true);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      blocker: AuthBlocker.none,
    );
    try {
      final session = await _repo.login(email, password);
      await _saveSession(session);
      state = state.copyWith(
        user: session.user,
        isLoading: false,
        blocker: AuthBlocker.none,
      );
      _tabSync.publish(UserChangedEvent(session.user.id));
    } on AuthException catch (e) {
      AuthBlocker blocker = AuthBlocker.none;
      if (e.isPendingApproval) blocker = AuthBlocker.pendingApproval;
      if (e.isEmailNotVerified) blocker = AuthBlocker.emailNotVerified;
      if (e.isRejected) blocker = AuthBlocker.rejected;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
        blocker: blocker,
      );
    }
  }

  Future<void> logout() async {
    await _localLogout(broadcast: true);
  }

  Future<void> clearRegisterSuccess() async {
    state = state.copyWith(registerSuccess: false);
  }

  Future<void> _localLogout({required bool broadcast}) async {
    await ref.read(_logoutHookRegistryProvider).runAll();
    await _tokens.delete(_accessTokenKey);
    await _tokens.delete(_refreshTokenKey);
    await _tokens.delete(_userKey);
    state = const AuthState();
    if (broadcast) _tabSync.publish(const LoggedOutEvent());
  }

  Future<void> _saveSession(AuthSession session) async {
    await _tokens.write(_accessTokenKey, session.accessToken);
    await _tokens.write(_refreshTokenKey, session.refreshToken);
    await _tokens.write(_userKey, jsonEncode(session.user.toJson()));
    await _persistUser(session.user);
  }

  Future<void> _persistUser(User user) {
    return _db.upsertUser(db.UsersCompanion.insert(
      id: user.id,
      email: user.email,
      displayName: Value(user.displayName),
      role: Value(user.role.name),
      status: Value(user.status.name),
    ));
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider.select((s) => s.user));
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider.select((s) => s.user?.isAdmin ?? false));
});
