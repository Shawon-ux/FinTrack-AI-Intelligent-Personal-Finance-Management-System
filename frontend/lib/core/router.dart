import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers.dart';
import '../features/auth/auth_pages.dart';
import 'package:flutter/widgets.dart';
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
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const AuthPage(register: false)),
      GoRoute(path: '/register', builder: (_, __) => const AuthPage(register: true)),
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
