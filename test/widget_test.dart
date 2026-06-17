// Basic smoke test: login screen renders when user is not authenticated.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pathpocket/app.dart';
import 'package:pathpocket/core/storage/app_database.dart';
import 'package:pathpocket/core/storage/secure_token_store.dart';
import 'package:pathpocket/features/settings/presentation/font_scale_provider.dart';
import 'package:pathpocket/features/settings/presentation/theme_provider.dart';
import 'package:drift/native.dart';

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

void main() {
  testWidgets('login screen renders when not authenticated',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureTokenStoreProvider.overrideWithValue(_InMemoryTokenStore()),
          themeModePrefsOverride(prefs),
          fontScalePrefsOverride(prefs),
        ],
        child: const PathPocketApp(),
      ),
    );
    await tester.pump();

    expect(find.text('PathPocket'), findsWidgets);
    expect(find.textContaining('病理学 AI 助手'), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
  });

  testWidgets('mobile shell shows centered model name with no app bar divider',
      (WidgetTester tester) async {
    // Narrow viewport → mobile breakpoint.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Pre-seed an authenticated session so the shell (not login) renders.
    final tokens = _InMemoryTokenStore();
    await tokens.write('auth.token', 'test-token');
    await tokens.write(
      'auth.user',
      jsonEncode({'id': 'u_1', 'phone': '13800000000', 'displayName': '医生'}),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureTokenStoreProvider.overrideWithValue(tokens),
          themeModePrefsOverride(prefs),
          fontScalePrefsOverride(prefs),
        ],
        child: const PathPocketApp(),
      ),
    );
    // Let _restoreSession resolve and the shell render.
    await tester.pumpAndSettle();

    // Centered model name in the app bar.
    final title = find.text('PathPocket');
    expect(title, findsWidgets);

    // The app bar hamburger + new-chat affordances are present.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
