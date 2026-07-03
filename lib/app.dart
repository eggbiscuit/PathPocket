import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme.dart';
import 'features/settings/presentation/theme_provider.dart';
import 'features/settings/presentation/font_scale_provider.dart';

class PathPocketApp extends ConsumerWidget {
  const PathPocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp.router(
      title: 'PathPocket',
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      // Apply the user's font scale on top of the inherited MediaQuery, which
      // MaterialApp builds reactively from the view. Rebuilding MediaQuery from
      // View.of(context) at the app root instead would drop the status-bar
      // padding (View.of doesn't subscribe to metrics changes, so SafeArea saw
      // a stale/zero top inset and the app bar collided with the status bar).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final systemScale = mq.textScaler.scale(1.0);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(systemScale * fontScale),
          ),
          child: child!,
        );
      },
    );
  }
}
