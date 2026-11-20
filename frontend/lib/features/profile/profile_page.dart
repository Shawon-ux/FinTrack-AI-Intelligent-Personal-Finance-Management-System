import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfilePage> {
  late final inc = TextEditingController(), sav = TextEditingController();
  String currency = 'BDT';
  bool consent = false;

  @override
  void initState() {
    super.initState();
    final p = (ref.read(authProvider)?['profile'] ?? {}) as Map;
    inc.text = '${double.tryParse('${p['monthly_income']}')?.round() ?? 0}';
    sav.text = '${double.tryParse('${p['savings_target']}')?.round() ?? 0}';
    currency = p['currency'] ?? 'BDT';
    consent = p['ai_learning_consent'] == true;
  }

  Future<void> _feedback() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Send feedback'),
              content: TextField(controller: c, maxLines: 4),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send'))
              ],
            ));
    if (ok != true) return;
    try {
      await ref.read(apiProvider).post('/feedback/', {'message': c.text});
      if (mounted) snack(context, 'Thanks for the feedback!');
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete account?'),
              content: const Text('This permanently deletes your account and all data.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: C.bad)))
              ],
            ));
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authProvider);
    final tx = ref.watch(txProvider);
    if (u == null) return const SizedBox();
    final name = '${u['first_name'] ?? ''}'.isEmpty ? '${u['email']}'.split('@').first : '${u['first_name']}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        CircleAvatar(radius: 28, backgroundColor: C.p, child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 22))),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('${u['email']}', style: const TextStyle(color: C.mut, fontSize: 12))
        ])),
        Pill('${u['role']}', color: C.p),
      ]),
      const SizedBox(height: 14),
      Card(
          child: Pad(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Financial profile', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(controller: inc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly income (৳)')),
        const SizedBox(height: 10),
        TextField(controller: sav, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly savings target (৳)')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
            initialValue: currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: [for (final c in ['BDT', 'USD', 'EUR', 'INR']) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => currency = v!),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            onChanged: (v) => setState(() => consent = v),
            title: const Text('Allow anonymised AI learning'),
            subtitle: const Text('Off by default. Your data never trains a global model without consent.', style: TextStyle(fontSize: 11))),
        GradientButton('Save', () async {
          try {
            await ref.read(authProvider.notifier).saveProfile({'monthly_income': inc.text, 'savings_target': sav.text, 'currency': currency, 'ai_learning_consent': consent, 'onboarded': true});
            ref.invalidate(overviewProvider);
            if (context.mounted) snack(context, 'Saved ✓');
          } catch (e) {
            if (context.mounted) snack(context, errText(e));
          }
        }),
      ]))),
      Card(
          child: Pad(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Offline & sync', style: TextStyle(fontWeight: FontWeight.w600)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: tx.offline,
            onChanged: (v) => ref.read(txProvider.notifier).setOffline(v),
            title: const Text('Simulate offline mode'),
            subtitle: const Text('Add transactions without internet; they sync when you switch back.', style: TextStyle(fontSize: 11))),
        Text('${tx.queue.length} pending change(s) on this device.', style: const TextStyle(color: C.mut, fontSize: 12)),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: () async {
              final m = await ref.read(txProvider.notifier).sync();
              if (context.mounted) snack(context, m ?? 'Nothing to sync');
            },
            child: const Text('Sync now')),
      ]))),
      Card(
          child: Pad(
              child: Column(children: [
        OutlinedButton.icon(onPressed: _feedback, icon: const Icon(Icons.chat_bubble_outline), label: const Text('Send feedback')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: C.bad), label: const Text('Delete my account & data', style: TextStyle(color: C.bad))),
      ]))),
      FilledButton.tonal(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Log out')),
      const SizedBox(height: 30),
    ]);
  }
}
