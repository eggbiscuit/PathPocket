import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_token_store.dart';
import 'features/settings/presentation/font_scale_provider.dart';
import 'features/settings/presentation/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final tokenStore = createSecureTokenStore();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureTokenStoreProvider.overrideWithValue(tokenStore),
        themeModePrefsOverride(prefs),
        fontScalePrefsOverride(prefs),
      ],
      child: const PathPocketApp(),
    ),
  );
}
