import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(apiProvider).load();
  await container.read(authProvider.notifier).restore();
  await container.read(txProvider.notifier).init();
  // Dev/screenshot helper only: flutter build web --dart-define=AUTO_LOGIN=demo@fintrack.ai:demo1234
  const auto = String.fromEnvironment('AUTO_LOGIN');
  if (auto.contains(':') && container.read(authProvider) == null) {
    final i = auto.indexOf(':');
    try {
      await container.read(authProvider.notifier).authenticate('login', auto.substring(0, i), auto.substring(i + 1));
    } catch (_) {}
  }
  runApp(UncontrolledProviderScope(container: container, child: const FinTrackApp()));
}

class FinTrackApp extends ConsumerWidget {
  const FinTrackApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'FinTrack AI',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: ref.watch(routerProvider),
      );
}
