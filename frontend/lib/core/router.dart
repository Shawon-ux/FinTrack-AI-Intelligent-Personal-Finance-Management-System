import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers.dart';
import '../features/auth/auth_pages.dart';
import 'package:flutter/material.dart';
import '../features/admin/admin_page.dart';
import '../features/shell/shell_page.dart';

/// Bridges Riverpod auth state to GoRouter's refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider) != null;
      final loc = state.matchedLocation;
      final authPage = loc == '/welcome' || loc == '/login' || loc == '/register';
      if (!loggedIn && !authPage) return '/welcome';
      if (loggedIn && authPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _HomeGate()),
      GoRoute(path: '/welcome', pageBuilder: (c, s) => _fade(s, const WelcomePage())),
      GoRoute(path: '/login', pageBuilder: (c, s) => _fade(s, const AuthPage(register: false))),
      GoRoute(path: '/register', pageBuilder: (c, s) => _fade(s, const AuthPage(register: true))),
    ],
  );
});

/// Admins get the admin console; everyone else gets the personal-finance app.
class _HomeGate extends ConsumerWidget {
  const _HomeGate();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((u) => u?['role']));
    return role == 'admin' ? const AdminPage() : const ShellPage();
  }
}

CustomTransitionPage<void> _fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (context, anim, _, c) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: c),
      ),
    );
