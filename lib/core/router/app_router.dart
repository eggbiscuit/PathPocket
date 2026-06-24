import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/admin_panel_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthListenable(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      final publicRoutes = {'/login', '/register', '/pending'};
      final isPublic = publicRoutes.contains(loc);

      if (!auth.isAuthenticated && !isPublic) return '/login';
      if (auth.isAuthenticated && loc == '/login') return '/';
      if (auth.isAuthenticated && loc == '/admin' && !auth.user!.isAdmin) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/pending', builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPanelScreen()),
      GoRoute(path: '/', builder: (_, __) => const ShellScaffold()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _sub = ref.listen(
      authProvider.select((s) => (s.isAuthenticated, s.blocker)),
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<(bool, AuthBlocker)> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
