import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';

final adminTabProvider = StateProvider<int>((ref) => const int.fromEnvironment('START_TAB', defaultValue: 0));

final adminStatsProvider = FutureProvider.autoDispose<J>((ref) async => Map<String, dynamic>.from(await ref.read(apiProvider).get('/admin/stats/')));

/// key = "query|status|plan"
final adminUsersProvider = FutureProvider.autoDispose.family<J, String>((ref, key) async {
  final p = key.split('|');
  return Map<String, dynamic>.from(await ref.read(apiProvider).get('/admin/users/?q=${Uri.encodeQueryComponent(p[0])}&status=${p[1]}&plan=${p[2]}'));
});

final adminUserProvider = FutureProvider.autoDispose.family<J, int>((ref, id) async => Map<String, dynamic>.from(await ref.read(apiProvider).get('/admin/users/$id/')));
final adminLogsProvider = FutureProvider.autoDispose.family<List<J>, String>((ref, q) async => asList(await ref.read(apiProvider).get('/admin/logs/?q=${Uri.encodeQueryComponent(q)}')));
final adminFeedbackProvider = FutureProvider.autoDispose.family<List<J>, String>((ref, status) async => asList(await ref.read(apiProvider).get('/admin/feedback/?status=$status')));
final adminBroadcastsProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/admin/broadcast/')));

/// "3h ago" style time.
String ago(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return 'never';
  final s = DateTime.now().difference(d);
  if (s.inMinutes < 1) return 'just now';
  if (s.inMinutes < 60) return '${s.inMinutes}m ago';
  if (s.inHours < 24) return '${s.inHours}h ago';
  if (s.inDays < 30) return '${s.inDays}d ago';
  return '${d.day}/${d.month}/${d.year}';
}
