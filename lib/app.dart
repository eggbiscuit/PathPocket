import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme.dart';

class PathPocketApp extends ConsumerWidget {
  const PathPocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PathPocket',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
