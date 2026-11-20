import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

Future<void> showAddTransaction(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTransactionSheet(),
    );

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});
  @override
  ConsumerState<AddTransactionSheet> createState() => _AddState();
}

class _AddState extends ConsumerState<AddTransactionSheet> {
  final id = const Uuid().v4(); // client-generated UUID => idempotent sync
  String type = 'expense', category = '', sub = '', pay = 'cash', aiCat = '', aiSource = '', receiptHash = '';
  double? aiConf;
  String? account, toAccount, error;
  DateTime date = DateTime.now();
  final amount = TextEditingController(), desc = TextEditingController(), merchant = TextEditingController();
  List<J> accounts = [];

  @override
  void initState() {
    super.initState();
    () async {
      try {
        accounts = await ref.read(accountsProvider.future);
      } catch (_) {}
      if (accounts.isNotEmpty) account = accounts.first['id'];
      if (mounted) setState(() {});
    }();
  }

  Future<void> categorize() async {
    final text = desc.text.isNotEmpty ? desc.text : merchant.text;
    if (text.isEmpty) return snack(context, 'Type a description first');
    try {
      final r = await ref.read(apiProvider).post('/ai/categorize/', {'text': text});
      setState(() {
        aiCat = category = r['category']; sub = r['subcategory']; aiConf = (r['confidence'] as num).toDouble(); aiSource = r['source'];
        if (r['amount'] != null && amount.text.isEmpty) amount.text = '${r['amount']}';
        if ((r['merchant'] ?? '') != '' && merchant.text.isEmpty) merchant.text = r['merchant'];
        if (r['type'] == 'income') { type = 'income'; category = 'Income'; }
      });
    } catch (e) {
      if (mounted) snack(context, errText(e).contains('offline') ? 'AI needs a connection - pick a category manually' : errText(e));
    }
  }

  Future<void> scan() async {
    final c = TextEditingController(text: 'RESTAURANT ABC\n20 November 2026\nBurger 350\nDrinks 100\nFries 150\nVAT 30\nTotal 630');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan receipt'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('On-device OCR (ML Kit) would fill this in. Paste or edit the OCR text:', style: TextStyle(fontSize: 12, color: C.mut)),
          const SizedBox(height: 8),
          TextField(controller: c, maxLines: 7),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Extract'))],
      ),
    );
    if (text == null) return;
    try {
      final r = await ref.read(apiProvider).post('/ai/receipt/scan/', {'text': text});
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${r['merchant']}${r['duplicate'] == true ? '  (possible duplicate!)' : ''}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in r['items']) Text('${i['name']}   ${fmt(i['amount'])}'),
            Text('VAT   ${fmt(r['vat'])}'),
            const SizedBox(height: 6),
            Text('Total ${fmt(r['total'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Nothing is saved until you confirm.', style: TextStyle(color: C.mut, fontSize: 12)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Discard')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use'))],
        ),
      );
      if (ok == true) {
        setState(() {
          amount.text = '${r['total']}'; merchant.text = '${r['merchant']}'; desc.text = 'Receipt: ${r['merchant']}'; receiptHash = r['receipt_hash'];
          if (r['suggested'] != null) { category = aiCat = r['suggested']['category']; sub = r['suggested']['subcategory']; aiConf = (r['suggested']['confidence'] as num).toDouble(); }
          if (r['date'] != null) date = DateTime.parse('${r['date']}T12:00');
        });
      }
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  Future<void> save() async {
    final a = double.tryParse(amount.text);
    if (a == null || a <= 0) return setState(() => error = 'Enter an amount greater than 0.');
    if (type == 'transfer' && (toAccount == null || toAccount == account)) return setState(() => error = 'Pick two different accounts.');
    final user = ref.read(authProvider);
    final tx = <String, dynamic>{
      'id': id, 'transaction_type': type, 'amount': a.toStringAsFixed(2), 'currency': user?['profile']?['currency'] ?? 'BDT',
      'description': desc.text, 'category': type == 'income' ? 'Income' : type == 'transfer' ? 'Transfer' : (category.isEmpty ? 'Other' : category),
      'subcategory': sub, 'merchant_name': merchant.text, 'payment_method': pay, 'transaction_date': date.toUtc().toIso8601String(),
      'account': account, 'to_account': type == 'transfer' ? toAccount : null, 'ai_category': aiCat, 'ai_confidence': aiConf, 'receipt_hash': receiptHash,
    };
    await ref.read(txProvider.notifier).upsert(tx);
    if (!mounted) return;
    Navigator.pop(context);
    snack(context, ref.read(txProvider).offline ? 'Saved on device - will sync when online' : 'Saved ✓');
  }

  @override
  Widget build(BuildContext context) {
    final off = ref.watch(txProvider).offline;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
        const Text('Add transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'expense', label: Text('Expense')), ButtonSegment(value: 'income', label: Text('Income')), ButtonSegment(value: 'transfer', label: Text('Transfer'))],
          selected: {type}, onSelectionChanged: (s) => setState(() { type = s.first; category = ''; }),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: scan, icon: const Icon(Icons.document_scanner_outlined), label: const Text('Scan receipt')),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (৳)')),
        const SizedBox(height: 10),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description', hintText: 'Paid ৳650 at KFC for dinner'), onEditingComplete: () { FocusScope.of(context).unfocus(); if (aiCat.isEmpty && !off) categorize(); }),
        Row(children: [
          Expanded(child: Text(aiCat.isEmpty ? '' : '✨ AI: $aiCat (${((aiConf ?? 0) * 100).round()}%)${aiSource == 'personalised' ? ' · learned from you' : ''}', style: TextStyle(color: C.mut, fontSize: 12))),
          TextButton(onPressed: categorize, child: const Text('✨ Auto-categorise')),
        ]),
        if (type != 'transfer') ...[
          Wrap(spacing: 6, children: [
            for (final c in (type == 'income' ? ['Income'] : expenseCats)) ChoiceChip(label: Text('${catIcon[c]} $c'), selected: category == c, onSelected: (_) => setState(() => category = c)),
          ]),
          const SizedBox(height: 10),
          TextField(controller: merchant, decoration: const InputDecoration(labelText: 'Merchant')),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: account, decoration: InputDecoration(labelText: type == 'transfer' ? 'From account' : 'Account'),
          items: [for (final a in accounts) DropdownMenuItem(value: '${a['id']}', child: Text('${a['name']}'))],
          onChanged: (v) => setState(() => account = v),
        ),
        const SizedBox(height: 10),
        if (type == 'transfer')
          DropdownButtonFormField<String>(
            initialValue: toAccount, decoration: const InputDecoration(labelText: 'To account'),
            items: [for (final a in accounts) DropdownMenuItem(value: '${a['id']}', child: Text('${a['name']}'))],
            onChanged: (v) => setState(() => toAccount = v),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: pay, decoration: const InputDecoration(labelText: 'Payment method'),
            items: [for (final p in ['cash', 'bank', 'card', 'bkash', 'nagad', 'rocket', 'other']) DropdownMenuItem(value: p, child: Text(p))],
            onChanged: (v) => setState(() => pay = v!),
          ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero, title: const Text('Date & time'), subtitle: Text(date.toString().substring(0, 16)), trailing: const Icon(Icons.calendar_today, size: 18),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
            if (d != null) setState(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
          },
        ),
        if (error != null) Text(error!, style: const TextStyle(color: C.bad, fontSize: 12)),
        const SizedBox(height: 8),
        GradientButton(off ? 'Save offline' : 'Save', save),
      ]),
    );
  }
}
