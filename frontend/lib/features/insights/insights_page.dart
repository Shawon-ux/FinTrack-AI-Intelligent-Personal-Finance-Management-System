import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});
  @override
  ConsumerState<InsightsPage> createState() => _InsightsState();
}

class _InsightsState extends ConsumerState<InsightsPage> {
  final chat = <MapEntry<bool, String>>[];
  final input = TextEditingController();
  String? whatCat;
  double whatPct = 10;
  String? whatOut;
  bool asking = false;

  Future<void> ask(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      chat.add(MapEntry(true, q));
      asking = true;
      input.clear();
    });
    try {
      final r = await ref.read(apiProvider).post('/ai/assistant/chat/', {'message': q});
      chat.add(MapEntry(false, '${r['answer']}'));
    } catch (e) {
      chat.add(MapEntry(false, errText(e)));
    }
    if (mounted) setState(() => asking = false);
  }

  Future<void> _fb(dynamic id, String s) async {
    await ref.read(apiProvider).post('/ai/feedback/', {'alert_id': id, 'status': s});
    ref.invalidate(anomaliesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final fc = ref.watch(forecastProvider), an = ref.watch(anomaliesProvider), tr = ref.watch(trendsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(forecastProvider);
        ref.invalidate(anomaliesProvider);
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Insights', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        fc.when(
          loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Card(child: Pad(child: Text(errText(e).contains('offline') ? 'AI insights need a connection.' : errText(e), style: TextStyle(color: C.mut)))),
          data: (f) {
            final past = tr.maybeWhen(data: (t) => [for (final d in (t['daily'] as List).skip(16)) (d['amount'] as num).toDouble()], orElse: () => <double>[0, 0]);
            final trends = List<J>.from((f['trends'] as List).map((e) => Map<String, dynamic>.from(e)));
            whatCat ??= trends.isNotEmpty ? '${trends.first['category']}' : null;
            return Column(children: [
              Card(
                  child: Pad(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Expanded(child: Text('Spending forecast', style: TextStyle(fontWeight: FontWeight.w600))), Pill('${f['model']}', color: C.p)]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _stat('Next 7 days', fmt(f['next_7_days']))),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Next 30 days', fmt(f['next_30_days']))),
                ]),
                const SizedBox(height: 10),
                LineChartW(actual: past.length < 2 ? [0, 0] : past, forecast: [for (final d in f['daily']) (d as num).toDouble()]),
                Text('Range (90%): ${fmt(f['interval_30']['low'])} - ${fmt(f['interval_30']['high'])} · This month projected ${fmt(f['month_projection'])}',
                    style: TextStyle(color: C.mut, fontSize: 12)),
                const SizedBox(height: 4),
                Text('Backtest MAE ${f['mae'] ?? '-'} vs baseline ${f['baseline_mae'] ?? '-'} (${f['model_version']}). ${f['disclaimer']}',
                    style: TextStyle(color: C.mut, fontSize: 11)),
              ]))),
              Card(
                  child: Pad(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Category trends (30d vs previous)', style: TextStyle(fontWeight: FontWeight.w600)),
                for (final t in trends)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(child: Text('${catIcon[t['category']] ?? ''} ${t['category']}', style: const TextStyle(fontSize: 13))),
                        Text(fmt(t['current']), style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        t['change_pct'] == null
                            ? const Pill('new')
                            : Pill('${(t['change_pct'] as num) > 0 ? '▲' : '▼'} ${(t['change_pct'] as num).abs()}%',
                                color: (t['change_pct'] as num) > 15 ? C.bad : (t['change_pct'] as num) < -15 ? C.ok : C.mut),
                      ])),
              ]))),
              if ((f['budget_risks'] as List).isNotEmpty)
                Card(
                    child: Pad(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Budget overrun risk', style: TextStyle(fontWeight: FontWeight.w600)),
                  for (final b in f['budget_risks'])
                    Row(children: [
                      Expanded(child: Text('${b['budget']} - projected ${fmt(b['projected'])} / ${fmt(b['limit'])}', style: const TextStyle(fontSize: 12))),
                      Pill('${b['risk']}', color: b['risk'] == 'high' ? C.bad : b['risk'] == 'medium' ? C.warn : C.ok)
                    ]),
                ]))),
              Card(
                  child: Pad(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('What-if simulator', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(children: [
                  Expanded(
                      child: DropdownButton<String>(
                          isExpanded: true,
                          value: whatCat,
                          items: [for (final t in trends) DropdownMenuItem(value: '${t['category']}', child: Text('${t['category']}'))],
                          onChanged: (v) => setState(() => whatCat = v))),
                  Text(' −${whatPct.round()}%'),
                ]),
                Slider(value: whatPct, min: 5, max: 50, divisions: 9, onChanged: (v) => setState(() => whatPct = v)),
                OutlinedButton(
                    onPressed: () async {
                      try {
                        final r = await ref.read(apiProvider).get('/ai/whatif/?category=${Uri.encodeQueryComponent(whatCat ?? '')}&percent=${whatPct.round()}');
                        setState(() => whatOut = 'Reducing ${r['category']} by ${(r['percent'] as num).round()}% saves ${fmt(r['monthly_saving'])}/month (${fmt(r['yearly_saving'])}/year).');
                      } catch (e) {
                        if (mounted) snack(context, errText(e));
                      }
                    },
                    child: const Text('Simulate')),
                if (whatOut != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(whatOut!, style: const TextStyle(color: C.ok, fontSize: 13))),
              ]))),
            ]);
          },
        ),
        an.maybeWhen(
          data: (list) => Card(
              child: Pad(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Unusual transactions', style: TextStyle(fontWeight: FontWeight.w600))),
              Pill('${list.where((a) => a['status'] == 'open').length} to review', color: C.warn)
            ]),
            for (final a in list.take(4))
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a['transaction_detail']['merchant_name'] ?? a['transaction_detail']['category']} · ${fmt(double.tryParse('${a['transaction_detail']['amount']}'))}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${a['explanation']}', style: TextStyle(color: C.mut, fontSize: 12)),
                    if (a['status'] == 'open')
                      Row(children: [
                        TextButton(onPressed: () => _fb(a['id'], 'confirmed_ok'), child: const Text('Yes, it was me')),
                        TextButton(onPressed: () => _fb(a['id'], 'confirmed_issue'), child: const Text('Not me', style: TextStyle(color: C.bad))),
                      ])
                    else
                      Pill('${a['status']}'.replaceAll('_', ' ')),
                  ])),
            const SizedBox(height: 6),
            Text('Flagged items are patterns worth reviewing, not confirmed fraud.', style: TextStyle(color: C.mut, fontSize: 11)),
          ]))),
          orElse: () => const SizedBox.shrink(),
        ),
        Card(
            child: Pad(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💬 AI assistant', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (chat.isEmpty) _bubble(false, 'Hi! Ask about your spending, budgets, forecast or savings.'),
          for (final m in chat) _bubble(m.key, m.value),
          if (asking) const Padding(padding: EdgeInsets.all(6), child: LinearProgressIndicator()),
          Wrap(spacing: 6, children: [
            for (final q in const ['How much did I spend on food this month?', 'Compare my spending with last month', 'How can I save ৳3000 next month?'])
              ActionChip(label: Text(q, style: const TextStyle(fontSize: 11)), onPressed: () => ask(q))
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: input, onSubmitted: ask, decoration: const InputDecoration(hintText: 'Ask FinTrack AI…', isDense: true))),
            IconButton(onPressed: () => ask(input.text), icon: const Icon(Icons.send, color: C.p)),
          ]),
          Text('Answers use your real recorded data. Not professional financial advice.', style: TextStyle(color: C.mut, fontSize: 11)),
        ]))),
      ]),
    );
  }

  Widget _stat(String l, String v) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Text(l, style: TextStyle(color: C.mut, fontSize: 12)), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
      );

  Widget _bubble(bool user, String t) => Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxWidth: 290),
          decoration: BoxDecoration(color: user ? C.p : C.card2, borderRadius: BorderRadius.circular(14)),
          child: Text(t),
        ),
      );
}
