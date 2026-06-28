import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart' as config;
import '../../../core/storage/secure_token_store.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.status,
    this.displayName,
  });

  final String id;
  final String email;
  final String status;
  final String? displayName;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        email: json['email'] as String,
        status: json['status'] as String,
        displayName: json['display_name'] as String?,
      );
}

class AdminPanelState {
  const AdminPanelState({
    this.users = const [],
    this.isLoading = false,
    this.errorMessage,
    this.processingId,
  });

  final List<AdminUser> users;
  final bool isLoading;
  final String? errorMessage;
  final String? processingId;

  AdminPanelState copyWith({
    List<AdminUser>? users,
    bool? isLoading,
    String? errorMessage,
    String? processingId,
    bool clearError = false,
    bool clearProcessing = false,
  }) {
    return AdminPanelState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingId:
          clearProcessing ? null : (processingId ?? this.processingId),
    );
  }
}

class AdminPanelNotifier extends Notifier<AdminPanelState> {
  @override
  AdminPanelState build() {
    // Load all users (not just pending) so admins can see the full picture.
    // Deferred so the first `state` read happens after build() returns —
    // reading state synchronously inside build() throws "uninitialized provider".
    Future.microtask(_load);
    return const AdminPanelState(isLoading: true);
  }

  Future<String?> _token() =>
      ref.read(secureTokenStoreProvider).read('auth.token');

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _token();
      final resp = await Dio().get(
        '${config.backendBaseUrl}/admin/users',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        }),
      );
      final users = (resp.data as List)
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(users: users, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载失败：${e.message ?? e.type.name}',
      );
    }
  }

  Future<void> refresh() => _load();

  Future<void> approve(String userId) => _setStatus(userId, 'approve');

  Future<void> reject(String userId) => _setStatus(userId, 'reject');

  Future<void> _setStatus(String userId, String action) async {
    state = state.copyWith(processingId: userId);
    try {
      final token = await _token();
      final resp = await Dio().post(
        '${config.backendBaseUrl}/admin/users/$userId/$action',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        }),
      );
      final updated = AdminUser.fromJson(resp.data as Map<String, dynamic>);
      state = state.copyWith(
        users: [
          for (final u in state.users)
            if (u.id == userId) updated else u
        ],
        clearProcessing: true,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        clearProcessing: true,
        errorMessage: '操作失败：${e.message ?? e.type.name}',
      );
    }
  }
}

final adminPanelProvider =
    NotifierProvider<AdminPanelNotifier, AdminPanelState>(
  AdminPanelNotifier.new,
);
