import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'features/chat/presentation/chat_provider.dart';
import 'features/chat/presentation/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PathPocketApp(),
    ),
  );
}

class PathPocketApp extends StatelessWidget {
  const PathPocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathPocket',
      theme: buildAppTheme(),
      home: const ChatScreen(),
    );
  }
}
