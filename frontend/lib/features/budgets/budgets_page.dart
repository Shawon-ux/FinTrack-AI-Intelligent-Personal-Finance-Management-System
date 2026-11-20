import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const DefaultTabController(
        length: 3,
        child: Column(children: [
          Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(alignment: Alignment.centerLeft, child: Text('Budgets & Savings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
          TabBar(tabs: [Tab(text: 'Budgets'), Tab(text: 'Goals'), Tab(text: 'Recurring')]),
          Expanded(child: TabBarView(children: [_Budgets(), _Goals(), _Recurring()])),
        ]),
      );
}

Widget _async<T>(AsyncValue<T> v, Widget Function(T) b) => v.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(errText(e), style: TextStyle(color: C.mut)))),
    data: b);

class _Budgets extends ConsumerWidget {
  const _Budgets();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _async(
      ref.watch(budgetsProvider),
      (list) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final b in list)
              Card(
                  child: Pad(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  Pill('${b['pct']}% used', color: (b['pct'] as num) >= 100 ? C.bad : (b['pct'] as num) >= 75 ? C.warn : C.ok)
                ]),
                const SizedBox(height: 10),
                Bar((b['pct'] as num).toDouble()),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${fmt(b['spent'])} of ${fmt(b['total_limit'])}', style: const TextStyle(fontSize: 12)),
                  Text((b['remaining'] as num) < 0 ? 'Over by ${fmt(-(b['remaining'] as num))}' : '${fmt(b['remaining'])} left',
                      style: TextStyle(fontSize: 12, color: (b['remaining'] as num) < 0 ? C.bad : C.ok)),
                ]),
                if (b['active'] == true)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${b['days_left']} days left · projected ${fmt(b['projected'])} · overrun risk ${b['overrun_risk']}',
                          style: TextStyle(color: C.mut, fontSize: 12))),
                for (final c in b['categories'])
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${catIcon[c['category']] ?? ''} ${c['category']}', style: const TextStyle(fontSize: 12)),
                        Text('${fmt(c['spent'])} / ${fmt(c['limit'])}', style: const TextStyle(fontSize: 12))
                      ]),
                      const SizedBox(height: 3),
                      Bar((c['pct'] as num).toDouble()),
                    ]),
                  ),
              ]))),
            GradientButton('+ New budget', () => _newBudget(context, ref)),
          ]));

  void _newBudget(BuildContext context, WidgetRef ref) {
    final name = TextEditingController(text: 'Monthly Budget'), total = TextEditingController(text: '20000');
    final cats = {for (final c in ['Food', 'Transport', 'Shopping', 'Entertainment', 'Bills']) c: TextEditingController()};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
          const Text('New budget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(controller: total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total limit (৳)')),
          const SizedBox(height: 10),
          for (final e in cats.entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                    controller: e.value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${catIcon[e.key]} ${e.key} limit (optional)'))),
          GradientButton('Create', () async {
            final n = DateTime.now(), s = DateTime(n.year, n.month, 1), e = DateTime(n.year, n.month + 1, 0);
            String iso(DateTime d) => d.toIso8601String().substring(0, 10);
            final lim = {for (final x in cats.entries) if ((double.tryParse(x.value.text) ?? 0) > 0) x.key: double.parse(x.value.text)};
            try {
              await ref.read(apiProvider).post('/budgets/', {'name': name.text, 'total_limit': total.text, 'start_date': iso(s), 'end_date': iso(e), 'category_limits': lim});
              ref.invalidate(budgetsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (er) {
              if (ctx.mounted) snack(ctx, errText(er));
            }
          }),
        ]),
      ),
    );
  }
}

class _Goals extends ConsumerWidget {
  const _Goals();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _async(
      ref.watch(goalsProvider),
      (list) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final g in list)
              Card(
                  child: Pad(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('🎯 ${g['name']}', style: const TextStyle(fontWeight: FontWeight.bold))), Pill('${g['pct']}%', color: C.p)]),
                const SizedBox(height: 10),
                Bar((g['pct'] as num).toDouble(), goal: true),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${fmt(double.tryParse('${g['saved_amount']}'))} / ${fmt(double.tryParse('${g['target_amount']}'))}', style: const TextStyle(fontSize: 12)),
                  if (g['monthly_required'] != null) Text('Save ${fmt(g['monthly_required'])}/mo', style: TextStyle(fontSize: 12, color: C.mut)),
                ]),
                TextButton(onPressed: () => _contribute(context, ref, '${g['id']}'), child: const Text('+ Add contribution')),
              ]))),
            GradientButton('+ New goal', () => _newGoal(context, ref)),
          ]));

  Future<void> _contribute(BuildContext context, WidgetRef ref, String id) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Add contribution'),
              content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (৳)')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))
              ],
            ));
    if (ok != true) return;
    try {
      await ref.read(apiProvider).post('/goals/$id/contribute/', {'amount': c.text});
      ref.invalidate(goalsProvider);
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  Future<void> _newGoal(BuildContext context, WidgetRef ref) async {
    final n = TextEditingController(), t = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('New savings goal'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: t, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target (৳)'))
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))
              ],
            ));
    if (ok != true) return;
    try {
      await ref.read(apiProvider).post('/goals/', {'name': n.text, 'target_amount': t.text});
      ref.invalidate(goalsProvider);
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }
}

class _Recurring extends ConsumerWidget {
  const _Recurring();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _async(
      ref.watch(recurringProvider),
      (list) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final r in list)
              Card(
                  child: ListTile(
                leading: const Text('🔁', style: TextStyle(fontSize: 22)),
                title: Text('${r['title']}'),
                subtitle: Text('${r['frequency']} · next due ${r['next_due']}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt(double.tryParse('${r['amount']}')), style: const TextStyle(fontWeight: FontWeight.bold)),
                  InkWell(
                      onTap: () async {
                        await ref.read(apiProvider).post('/recurring/${r['id']}/confirm/');
                        ref.invalidate(recurringProvider);
                        await ref.read(txProvider.notifier).refresh();
                      },
                      child: const Text('Mark paid', style: TextStyle(color: C.p2, fontSize: 12))),
                ]),
              )),
            if (list.isEmpty) Text('No recurring items.', style: TextStyle(color: C.mut)),
          ]));
}
