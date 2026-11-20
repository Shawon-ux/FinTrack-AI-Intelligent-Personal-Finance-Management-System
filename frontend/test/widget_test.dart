import 'dart:io';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack_ai/main.dart';
import 'package:fintrack_ai/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration-style smoke tests. They need the Django API on 127.0.0.1:8000 with `manage.py seed_demo` data.
void main() {
  setUp(() {
    HttpOverrides.global = null; // allow real HTTP in tests
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('welcome screen renders', (tester) async {
    final c = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FinTrackApp()));
    await tester.pump(const Duration(seconds: 2)); // background animates forever, so no pumpAndSettle
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('FinTrack AI'), findsOneWidget);
  });

  test('login -> analytics -> offline add -> sync is idempotent', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(txProvider.notifier).init();
    await c.read(authProvider.notifier).authenticate('login', 'demo@fintrack.ai', 'demo1234');
    expect(c.read(authProvider)?['email'], 'demo@fintrack.ai');

    final ov = await c.read(overviewProvider.future);
    expect(ov['income'], greaterThan(0));

    const id = '11111111-2222-4333-8444-555555555555';
    final n = c.read(txProvider.notifier);
    n.setOffline(true);
    await n.upsert({'id': id, 'transaction_type': 'expense', 'amount': '99.00', 'currency': 'BDT', 'description': 'flutter test', 'category': 'Other', 'transaction_date': DateTime.now().toUtc().toIso8601String()});
    expect(c.read(txProvider).queue.length, 1);          // saved locally while offline
    expect(c.read(txProvider).merged.any((t) => t['id'] == id), true);
    n.setOffline(false);
    await Future.delayed(const Duration(seconds: 4));    // setOffline(false) triggers sync
    expect(c.read(txProvider).queue.length, 0);          // cleared only after server confirmed
    expect(c.read(txProvider).cache.where((t) => t['id'] == id).length, 1);
    await c.read(apiProvider).delete('/transactions/$id/');
  });

  test('admin role sees aggregate stats; normal user is forbidden', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(authProvider.notifier).authenticate('login', 'admin@fintrack.ai', 'admin1234');
    expect(c.read(authProvider)?['role'], 'admin');
    final s = await c.read(apiProvider).get('/admin/stats/');
    expect(s['users'], isNotNull);
    await c.read(authProvider.notifier).logout();
    await c.read(authProvider.notifier).authenticate('login', 'demo@fintrack.ai', 'demo1234');
    expect(() => c.read(apiProvider).get('/admin/stats/'), throwsA(isA<Object>()));
  });

  test('register does not log in; user then signs in', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final email = 'new${DateTime.now().millisecondsSinceEpoch}@test.dev';
    await c.read(authProvider.notifier).register(email, 'longpass123', name: 'Tester');
    expect(c.read(authProvider), isNull);               // not signed in yet
    await c.read(authProvider.notifier).authenticate('login', email, 'longpass123');
    expect(c.read(authProvider)?['email'], email);
    await c.read(apiProvider).delete('/users/me/delete/');
  });

  test('profile picture round trip and theme preference persist', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(authProvider.notifier).authenticate('login', 'demo@fintrack.ai', 'demo1234');
    const img = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ';
    await c.read(authProvider.notifier).updateMe(profile: {'avatar': img});
    expect(c.read(authProvider)?['profile']['avatar'], img);
    await c.read(authProvider.notifier).reloadMe();                       // survives a reload from the server
    expect(c.read(authProvider)?['profile']['avatar'], img);
    await c.read(authProvider.notifier).updateMe(profile: {'avatar': ''}); // remove
    expect(c.read(authProvider)?['profile']['avatar'], '');
    await expectLater(c.read(authProvider.notifier).updateMe(profile: {'avatar': 'http://x'}), throwsA(isA<Object>())); // non-image rejected

    await c.read(themeProvider.notifier).set(ThemeMode.light);
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    await c2.read(themeProvider.notifier).load();
    expect(c2.read(themeProvider), ThemeMode.light);
  });
}
