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
