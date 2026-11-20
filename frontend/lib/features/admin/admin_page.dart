import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

final adminStatsProvider = FutureProvider.autoDispose<J>((ref) async => Map<String, dynamic>.from(await ref.read(apiProvider).get('/admin/stats/')));
final adminUsersProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/admin/users/')));
final adminLogsProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/admin/logs/')));
final adminFeedbackProvider = FutureProvider.autoDispose<List<J>>((ref) async => asList(await ref.read(apiProvider).get('/admin/feedback/')));

/// Administrator console. Shows aggregate data only - never private transaction details.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminState();
}

class _AdminState extends ConsumerState<AdminPage> {
  int tab = 0;

  Widget _wrap<T>(AsyncValue<T> v, Widget Function(T) b) => v.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(errText(e), style: const TextStyle(color: C.mut))),
      data: b);

  @override
  Widget build(BuildContext context) {
    final pages = [_overview(), _users(), _logs(), _feedback()];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('🛡 Admin console'),
        actions: [TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Log out'))],
      ),
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.feedback_outlined), label: 'Feedback'),
        ],
      ),
    );
  }

  Widget _overview() => _wrap(ref.watch(adminStatsProvider), (s) {
        final tiles = <String, Object?>{
          'Users': s['users'], 'Active': s['active_users'], 'Premium': s['premium'], 'New (7d)': s['new_7d'],
          'Transactions': s['transactions'], 'Tx (24h)': s['tx_24h'], 'Open anomaly alerts': s['open_alerts'], 'Open feedback': s['open_feedback'],
        };
        final sync = s['sync'] as Map;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminStatsProvider),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
              children: [
                for (final e in tiles.entries)
                  Container(
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${e.value ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(e.key, style: const TextStyle(color: C.mut, fontSize: 12)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
                child: Pad(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sign-ups, last 14 days', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              BarChart(values: [for (final d in s['signups']) (d['count'] as num).toDouble()], labels: [for (final d in s['signups']) '${d['date']}'.substring(8)]),
            ]))),
            Card(
                child: Pad(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sync monitor', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Runs: ${sync['runs'] ?? 0} · Records received: ${sync['received'] ?? 0} · Failed: ${sync['failed'] ?? 0}', style: const TextStyle(fontSize: 13)),
            ]))),
            Card(
                child: Pad(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ML model versions', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final m in s['models'])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w600))), Pill('${m['version']}', color: m['is_active'] == true ? C.ok : C.mut)]),
                    Text('trained on: ${m['trained_on']} · ${m['metrics']}', style: const TextStyle(color: C.mut, fontSize: 11)),
                  ]),
                ),
            ]))),
            const Text('🔒 Aggregate view only - private transaction details are not shown to administrators.', style: TextStyle(color: C.mut, fontSize: 12)),
          ]),
        );
      });

  Widget _users() => _wrap(ref.watch(adminUsersProvider), (list) => ListView(padding: const EdgeInsets.all(16), children: [
        for (final u in list)
          Card(
              child: Pad(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${u['email']}', style: const TextStyle(fontWeight: FontWeight.w600))),
              Pill(u['active'] == true ? 'active' : 'disabled', color: u['active'] == true ? C.ok : C.bad),
              if (u['premium'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Pill('premium', color: C.p)),
            ]),
            Text('${u['tx_count']} transactions · joined ${'${u['joined']}'.substring(0, 10)}', style: const TextStyle(color: C.mut, fontSize: 12)),
            Row(children: [
              TextButton(onPressed: () => _update(u['id'], {'active': !(u['active'] == true)}), child: Text(u['active'] == true ? 'Disable' : 'Enable')),
              TextButton(onPressed: () => _update(u['id'], {'premium': !(u['premium'] == true)}), child: Text(u['premium'] == true ? 'Remove premium' : 'Make premium')),
            ]),
          ]))),
        if (list.isEmpty) const Text('No users.', style: TextStyle(color: C.mut)),
      ]));

  Future<void> _update(dynamic id, J body) async {
    try {
      await ref.read(apiProvider).post('/admin/users/$id/', body);
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  Widget _logs() => _wrap(ref.watch(adminLogsProvider), (list) => ListView(padding: const EdgeInsets.all(16), children: [
        for (final l in list)
          Card(child: ListTile(dense: true, title: Text('${l['action']}  ·  ${l['user__email'] ?? 'anonymous'}'), subtitle: Text('${l['detail']}\n${l['ip'] ?? ''} · ${'${l['created_at']}'.substring(0, 16)}'), isThreeLine: true)),
      ]));

  Widget _feedback() => _wrap(ref.watch(adminFeedbackProvider), (list) => ListView(padding: const EdgeInsets.all(16), children: [
        for (final f in list) Card(child: ListTile(title: Text('${f['user__email']}'), subtitle: Text('${f['message']}'), trailing: Pill('${f['status']}'))),
        if (list.isEmpty) const Text('No feedback yet.', style: TextStyle(color: C.mut)),
      ]));
}
