import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final tokenStore = createSecureTokenStore();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureTokenStoreProvider.overrideWithValue(tokenStore),
      ],
      child: const PathPocketApp(),
    ),
  );
}
