import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class TxTile extends ConsumerWidget {
  const TxTile(this.t, {super.key});
  final J t;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = t['transaction_type'];
    final inc = type == 'income', tr = type == 'transfer';
    final d = DateTime.tryParse('${t['transaction_date']}')?.toLocal();
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _detail(context, ref),
      leading: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(13)), child: Text(catIcon[t['category']] ?? (tr ? '🔁' : '•'), style: const TextStyle(fontSize: 18))),
      title: Text('${(t['merchant_name'] ?? '').toString().isNotEmpty ? t['merchant_name'] : (t['description'] ?? '').toString().isNotEmpty ? t['description'] : (t['category'] ?? 'Transaction')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${t['category'] ?? ''} · ${d == null ? '' : '${d.day} ${mo[d.month - 1]}'}', style: const TextStyle(fontSize: 12, color: C.mut)),
        if (t['sync_status'] == 'pending') const Pill('⏳ pending', color: C.warn),
        if (t['has_alert'] == true) const Pill('unusual', color: C.bad),
      ]),
      trailing: Text('${inc ? '+' : tr ? '' : '-'}${fmt(double.tryParse('${t['amount']}') ?? 0)}', style: TextStyle(fontWeight: FontWeight.bold, color: inc ? C.ok : tr ? null : C.bad)),
    );
  }

  void _detail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fmt(double.tryParse('${t['amount']}')), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('${t['merchant_name'] ?? ''} ${t['description'] ?? ''}', style: const TextStyle(color: C.mut)),
          if ((t['ai_category'] ?? '').toString().isNotEmpty) Text('AI suggested: ${t['ai_category']}', style: const TextStyle(color: C.mut, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('Category (editable)', style: TextStyle(color: C.mut, fontSize: 12)),
          Wrap(spacing: 6, children: [
            for (final c in expenseCats)
              ChoiceChip(
                label: Text('${catIcon[c]} $c'), selected: t['category'] == c,
                onSelected: (_) {
                  final x = Map<String, dynamic>.from(t)..remove('has_alert')..remove('sync_status')..remove('created_at')..remove('updated_at');
                  x['category'] = c;
                  ref.read(txProvider.notifier).upsert(x);
                  Navigator.pop(ctx);
                },
              ),
          ]),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () { ref.read(txProvider.notifier).remove('${t['id']}'); Navigator.pop(ctx); },
            icon: const Icon(Icons.delete_outline, color: C.bad), label: const Text('Delete', style: TextStyle(color: C.bad)),
          ),
        ]),
      ),
    );
  }
}

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});
  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String q = '', type = '';
  @override
  Widget build(BuildContext context) {
    var list = ref.watch(txProvider).merged;
    if (type.isNotEmpty) list = list.where((t) => t['transaction_type'] == type).toList();
    if (q.isNotEmpty) {
      final s = q.toLowerCase();
      list = list.where((t) => '${t['description']} ${t['merchant_name']} ${t['category']} ${t['tags']}'.toLowerCase().contains(s)).toList();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(txProvider.notifier).refresh(),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Transactions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search merchant, category, note…')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final e in const {'': 'All', 'expense': 'Expenses', 'income': 'Income', 'transfer': 'Transfers'}.entries)
            ChoiceChip(label: Text(e.value), selected: type == e.key, onSelected: (_) => setState(() => type = e.key)),
        ]),
        const SizedBox(height: 8),
        Card(child: Pad(child: Column(children: [
          for (final t in list.take(100)) TxTile(t),
          if (list.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No transactions match.', style: TextStyle(color: C.mut))),
        ]))),
        Center(child: Text('${list.length} transaction(s)', style: const TextStyle(color: C.mut, fontSize: 12))),
        const SizedBox(height: 70),
      ]),
    );
  }
}
