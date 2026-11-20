import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/notifications_sheet.dart';
import '../../shared/widgets.dart';
import 'admin_more.dart';
import 'admin_providers.dart';

IconData activityIcon(String a) {
  if (a.contains('login_failed')) return Icons.gpp_maybe_outlined;
  if (a.contains('login')) return Icons.login;
  if (a.contains('register') || a.contains('create')) return Icons.person_add_alt_1_outlined;
  if (a.contains('delete')) return Icons.delete_outline;
  if (a.contains('broadcast')) return Icons.campaign_outlined;
  if (a.contains('feedback')) return Icons.chat_bubble_outline;
  if (a.contains('update')) return Icons.edit_outlined;
  return Icons.bolt;
}

Color activityColor(String a) => a.contains('failed') || a.contains('delete') ? C.bad : a.contains('login') ? C.p2 : a.contains('register') || a.contains('create') ? C.ok : C.p;

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(adminStatsProvider);
    final me = ref.watch(authProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
        ref.invalidate(notificationsProvider);
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Admin console 🛡', style: TextStyle(color: C.mut, fontSize: 12)),
              Text('Hi, ${('${me?['first_name'] ?? ''}'.isEmpty ? '${me?['email']}'.split('@').first : me?['first_name'])}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
          const BellButton(),
        ]),
        const SizedBox(height: 14),
        st.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Card(child: Pad(child: Text(errText(e), style: const TextStyle(color: C.bad)))),
          data: (s) => _body(context, ref, s),
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, J s) {
    final delta = (s['new_7d'] as num) - (s['new_prev_7d'] as num);
    final plan = [
      {'name': 'Free', 'amount': ((s['users'] as num) - (s['premium'] as num)).toDouble()},
      {'name': 'Premium', 'amount': (s['premium'] as num).toDouble()},
      {'name': 'Admins', 'amount': (s['admins'] as num).toDouble()},
    ].where((e) => (e['amount'] as double) > 0).toList();
    final h = s['health'] as Map, sync = s['sync'] as Map, notes = s['notifications'] as Map;
    final failRate = (sync['fail_rate'] as num).toDouble();
    final cats = List<J>.from((s['top_categories'] as List).map((e) => Map<String, dynamic>.from(e)));
    final maxCat = cats.fold<num>(1, (m, e) => (e['n'] as num) > m ? e['n'] as num : m);

    return Column(children: [
      // ---- hero
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: C.p.withValues(alpha: .35), blurRadius: 26, offset: const Offset(0, 10))]),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Total users', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                child: Text('${delta >= 0 ? '▲' : '▼'} ${delta.abs()} this week', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            Text('${s['users']}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _mini('Active', '${s['active_users']}'),
              _mini('Premium', '${s['premium']}'),
              _mini('Disabled', '${s['disabled']}'),
              _mini('New 7d', '${s['new_7d']}'),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      // ---- engagement
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Active users', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _stat('Today', '${s['dau']}', C.ok)),
              Expanded(child: _stat('7 days', '${s['wau']}', C.p2)),
              Expanded(child: _stat('30 days', '${s['mau']}', C.p)),
            ]),
          ]),
        ),
      ),
      // ---- quick KPIs (tap to jump)
      Row(children: [
        Expanded(child: _kpi(context, Icons.receipt_long, C.p2, '${s['transactions']}', 'Transactions', '+${s['tx_24h']} today', null)),
        const SizedBox(width: 10),
        Expanded(child: _kpi(context, Icons.warning_amber_rounded, (s['open_alerts'] as num) > 0 ? C.warn : C.ok, '${s['open_alerts']}', 'Open anomaly alerts', 'of ${s['anomaly_alerts']} total', null)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _kpi(context, Icons.chat_bubble_outline, C.p, '${s['open_feedback']}', 'Open feedback', 'tap to review', () => ref.read(adminTabProvider.notifier).state = 3)),
        const SizedBox(width: 10),
        Expanded(child: _kpi(context, Icons.campaign_outlined, C.ok, '${notes['broadcasts']}', 'Broadcasts sent', '${notes['read_rate']}% notifications read', () => ref.read(adminTabProvider.notifier).state = 2)),
      ]),
      const SizedBox(height: 12),
      // ---- charts
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Expanded(child: Text('New sign-ups', style: TextStyle(fontWeight: FontWeight.w700))), Pill('14 days')]),
            const SizedBox(height: 8),
            BarChart(values: [for (final d in s['signups']) (d['count'] as num).toDouble()], labels: [for (final d in s['signups']) '${d['date']}'.substring(8)], height: 110),
          ]),
        ),
      ),
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Expanded(child: Text('Transactions created', style: TextStyle(fontWeight: FontWeight.w700))), Pill('14 days')]),
            const SizedBox(height: 8),
            BarChart(values: [for (final d in s['tx_series']) (d['count'] as num).toDouble()], labels: [for (final d in s['tx_series']) '${d['date']}'.substring(8)], height: 110),
          ]),
        ),
      ),
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Plans', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Donut(plan),
          ]),
        ),
      ),
      if (cats.isNotEmpty)
        Card(
          child: Pad(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Most used categories', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(children: [
                    Row(children: [Text('${catIcon[c['category']] ?? '•'} ${c['category']}', style: const TextStyle(fontSize: 13)), const Spacer(), Text('${c['n']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
                    const SizedBox(height: 4),
                    Bar((c['n'] as num) / maxCat * 100, goal: true),
                  ]),
                ),
            ]),
          ),
        ),
      // ---- system health
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('System health', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _health('Database', h['database'] == true ? 'Online' : 'Down', h['database'] == true ? C.ok : C.bad),
            _health('ML models active', '${h['ml_models']}', (h['ml_models'] as num) > 0 ? C.ok : C.warn),
            _health('Sync failures', '${failRate.toStringAsFixed(1)}%  (${sync['failed'] ?? 0}/${sync['received'] ?? 0})', failRate < 2 ? C.ok : failRate < 10 ? C.warn : C.bad),
            _health('Predictions generated', '${s['predictions']}', C.p2),
          ]),
        ),
      ),
      // ---- recent activity
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => openAuditLog(context), child: const Text('Audit log')),
            ]),
            for (final a in s['activity'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: activityColor('${a['action']}').withValues(alpha: .15), borderRadius: BorderRadius.circular(10)), child: Icon(activityIcon('${a['action']}'), size: 18, color: activityColor('${a['action']}'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['action']}'.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${a['user__email'] ?? 'anonymous'}${'${a['detail']}'.isEmpty ? '' : ' · ${a['detail']}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.mut, fontSize: 11)),
                    ]),
                  ),
                  Text(ago(a['created_at']), style: TextStyle(color: C.mut, fontSize: 11)),
                ]),
              ),
          ]),
        ),
      ),
      // ---- models
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ML models', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final m in s['models'])
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w600))), Pill('${m['version']}', color: m['is_active'] == true ? C.ok : C.mut)]),
                  Text('trained on: ${m['trained_on']}', style: TextStyle(color: C.mut, fontSize: 11)),
                ]),
              ),
          ]),
        ),
      ),
      Text('🔒 Aggregate view - private transaction details are never shown to administrators.', style: TextStyle(color: C.mut, fontSize: 11)),
    ]);
  }

  Widget _mini(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]);

  Widget _stat(String l, String v, Color c) => Column(children: [
        Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c)),
        Text(l, style: TextStyle(color: C.mut, fontSize: 12)),
      ]);

  Widget _kpi(BuildContext context, IconData icon, Color color, String v, String label, String sub, VoidCallback? onTap) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: color)),
            const SizedBox(height: 10),
            Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(sub, style: TextStyle(color: C.mut, fontSize: 11)),
          ]),
        ),
      );

  Widget _health(String k, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
          Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c)),
        ]),
      );
}
