import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import '../transactions/transactions_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ov = ref.watch(overviewProvider);
    final user = ref.watch(authProvider);
    final tx = ref.watch(txProvider);
    // refresh analytics whenever the transaction set changes (e.g. after a successful sync)
    ref.listen(
      txProvider.select((s) => s.cache.length + s.queue.length),
      (_, __) => ref.invalidate(overviewProvider),
    );
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(txProvider.notifier).refresh();
        ref.invalidate(overviewProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Avatar(
                name: '${user?['first_name'] ?? user?['email'] ?? ''}',
                dataUrl: (user?['profile'] as Map?)?['avatar'] as String?,
                radius: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back 👋',
                      style: TextStyle(color: C.mut, fontSize: 12),
                    ),
                    Text(
                      '${user?['first_name'] ?? ''}'.isEmpty
                          ? '${user?['email']}'.split('@').first
                          : '${user?['first_name']}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: C.card2,
                  foregroundColor: C.text,
                ),
                onPressed: () => _notes(context, ref),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ov.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              child: Pad(
                child: Text(errText(e), style: const TextStyle(color: C.bad)),
              ),
            ),
            data: (o) => Column(
              children: [
                if (o['_stale'] == true)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Pill('Showing cached data', color: C.warn),
                    ),
                  ),
                _hero(o),
                Card(
                  child: Pad(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weekly expenses',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        BarChart(
                          values: [
                            for (final d in o['daily'])
                              (d['amount'] as num).toDouble(),
                          ],
                          labels: [for (final d in o['daily']) '${d['label']}'],
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Pad(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✨ AI insights',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        for (final i in o['insights'])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• $i',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ScoreRing(o['health']['score']),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Financial health: ${o['health']['label']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Savings ${o['health']['parts']['savings_rate']}/40 · Budget ${o['health']['parts']['budget_adherence']}/30\nConsistency ${o['health']['parts']['consistency']}/20 · Obligations ${o['health']['parts']['obligations']}/10',
                                    style: TextStyle(
                                      color: C.mut,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Pad(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expense distribution',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if ((o['categories'] as List).isEmpty)
                          Text(
                            'No expenses yet.',
                            style: TextStyle(color: C.mut),
                          )
                        else
                          Donut(
                            List<Map<String, dynamic>>.from(o['categories']),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Pad(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent transactions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final t in tx.merged.take(5)) TxTile(t),
                  if (tx.merged.isEmpty)
                    Text(
                      'Nothing yet - tap + to add one.',
                      style: TextStyle(color: C.mut),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _hero(Map<String, dynamic> o) => DefaultTextStyle.merge(
    style: const TextStyle(color: Colors.white),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: C.grad,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance · ${o['month']}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            fmt(o['balance']),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _kv('Income', fmt(o['income'])),
              _kv('Expenses', fmt(o['expense'])),
              _kv('Savings rate', '${o['savings_rate']}%'),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );

  void _notes(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (c, r, _) {
          final n = r.watch(notificationsProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await r
                            .read(apiProvider)
                            .post('/notifications/read_all/');
                        r.invalidate(notificationsProvider);
                      },
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
                n.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(errText(e)),
                  data: (l) => l.isEmpty
                      ? Text('All caught up.', style: TextStyle(color: C.mut))
                      : Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final x in l)
                                Card(
                                  child: ListTile(
                                    title: Text('${x['title']}'),
                                    subtitle: Text('${x['body']}'),
                                    enabled: x['is_read'] != true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
