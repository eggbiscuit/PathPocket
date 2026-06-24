// Widget smoke tests for PathPocket auth and shell flows.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pathpocket/app.dart';
import 'package:pathpocket/core/storage/app_database.dart';
import 'package:pathpocket/core/storage/secure_token_store.dart';
import 'package:pathpocket/features/settings/presentation/font_scale_provider.dart';
import 'package:pathpocket/features/settings/presentation/theme_provider.dart';

/// In-memory token store for tests — no platform channels needed.
class _InMemoryTokenStore implements SecureTokenStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}

ProviderScope _buildApp({
  required AppDatabase db,
  required SecureTokenStore tokens,
  required SharedPreferences prefs,
}) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureTokenStoreProvider.overrideWithValue(tokens),
        themeModePrefsOverride(prefs),
        fontScalePrefsOverride(prefs),
      ],
      child: const PathPocketApp(),
    );

void main() {
  testWidgets('login screen renders with email field when not authenticated',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
        _buildApp(db: db, tokens: _InMemoryTokenStore(), prefs: prefs));
    await tester.pump();

    expect(find.text('PathPocket'), findsWidgets);
    expect(find.textContaining('病理学 AI 助手'), findsOneWidget);
    // Email field (replaced phone field).
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    // Register link present.
    expect(find.text('申请注册'), findsOneWidget);
    // No phone icon from the old login screen.
    expect(find.byIcon(Icons.phone_outlined), findsNothing);
  });

  testWidgets('mobile shell shows centered model name and app bar icons',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tokens = _InMemoryTokenStore();
    await tokens.write('auth.token', 'test-token');
    await tokens.write(
      'auth.user',
      jsonEncode({
        'id': 'u_1',
        'email': 'doc@test.dev',
        'displayName': '医生',
        'role': 'user',
        'status': 'approved',
      }),
    );

    await tester.pumpWidget(
        _buildApp(db: db, tokens: tokens, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('PathPocket'), findsWidgets);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
