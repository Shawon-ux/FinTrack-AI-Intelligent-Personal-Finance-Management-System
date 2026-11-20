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
  await container.read(themeProvider.notifier).load();
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

class FinTrackApp extends ConsumerStatefulWidget {
  const FinTrackApp({super.key});
  @override
  ConsumerState<FinTrackApp> createState() => _FinTrackAppState();
}

class _FinTrackAppState extends ConsumerState<FinTrackApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {}); // follow the phone's setting in "System" mode

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeProvider);
    final dark = mode == ThemeMode.dark || (mode == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    final theme = buildTheme(dark); // also sets C.dark before any widget builds
    return MaterialApp.router(
      key: ValueKey(dark), // rebuild the whole tree so every colour re-reads the palette
      title: 'FinTrack AI',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
