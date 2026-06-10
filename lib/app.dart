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

    final baseMediaQuery = MediaQueryData.fromView(View.of(context));
    final systemScale = baseMediaQuery.textScaler.scale(1.0);

    return MediaQuery(
      data: baseMediaQuery.copyWith(
        textScaler: TextScaler.linear(systemScale * fontScale),
      ),
      child: MaterialApp.router(
        title: 'PathPocket',
        theme: buildAppTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
