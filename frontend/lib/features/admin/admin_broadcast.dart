import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import 'admin_providers.dart';

class AdminBroadcast extends ConsumerStatefulWidget {
  const AdminBroadcast({super.key});
  @override
  ConsumerState<AdminBroadcast> createState() => _BroadcastState();
}

class _BroadcastState extends ConsumerState<AdminBroadcast> {
  final title = TextEditingController(), body = TextEditingController();
  String audience = 'all';
  bool busy = false;
  static const aud = {'all': ('👥', 'Everyone'), 'premium': ('⭐', 'Premium'), 'free': ('🆓', 'Free users')};
  static const templates = [
    ('🎉 New feature', 'We just launched something new in FinTrack AI. Open the app to try it!'),
    ('🛠 Maintenance', 'FinTrack AI will be briefly unavailable for maintenance tonight. Your data is safe.'),
    ('💡 Tip', 'Scan receipts and let AI categorise your spending automatically.'),
  ];

  Future<void> send() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) return snack(context, 'Add a title and a message');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send notification?'),
        content: Text('This will notify ${aud[audience]!.$2.toLowerCase()} right away.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send'))],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      final r = await ref.read(apiProvider).post('/admin/broadcast/', {'title': title.text.trim(), 'body': body.text.trim(), 'audience': audience});
      title.clear();
      body.clear();
      ref.invalidate(adminBroadcastsProvider);
      ref.invalidate(adminStatsProvider);
      if (mounted) snack(context, 'Sent to ${r['recipients']} user(s) ✓');
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final hist = ref.watch(adminBroadcastsProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
      const Text('Broadcast', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      Text('Send an in-app announcement to your users', style: TextStyle(color: C.mut, fontSize: 12)),
      const SizedBox(height: 14),
      Card(
        child: Pad(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Audience', style: TextStyle(color: C.mut, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [for (final e in aud.entries) ChoiceChip(label: Text('${e.value.$1} ${e.value.$2}'), selected: audience == e.key, onSelected: (_) => setState(() => audience = e.key))]),
            const SizedBox(height: 14),
            TextField(controller: title, maxLength: 80, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title))),
            const SizedBox(height: 4),
            TextField(controller: body, maxLines: 4, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            const SizedBox(height: 10),
            Text('Quick templates', style: TextStyle(color: C.mut, fontSize: 12)),
            Wrap(spacing: 6, children: [for (final t in templates) ActionChip(label: Text(t.$1, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() { title.text = t.$1.substring(3); body.text = t.$2; }))]),
            if (title.text.isNotEmpty || body.text.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Preview', style: TextStyle(color: C.mut, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.p.withValues(alpha: .5))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: C.p.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.campaign_outlined, color: C.p, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.text.isEmpty ? 'Title' : title.text, style: const TextStyle(fontWeight: FontWeight.w700)), Text(body.text.isEmpty ? 'Message' : body.text, style: TextStyle(color: C.mut, fontSize: 13))])),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            GradientButton('📣  Send notification', send, busy: busy),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text('SENT HISTORY', style: TextStyle(color: C.mut, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      const SizedBox(height: 8),
      hist.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(errText(e)),
        data: (l) => l.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Nothing sent yet.', style: TextStyle(color: C.mut))))
            : Column(children: [
                for (final b in l)
                  Card(
                    child: ListTile(
                      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: C.p.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.campaign_outlined, color: C.p)),
                      title: Text('${b['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${b['body']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Pill('${b['recipients']} sent', color: C.ok), const SizedBox(height: 4), Text(ago(b['created_at']), style: TextStyle(color: C.mut, fontSize: 11))]),
                    ),
                  ),
              ]),
      ),
    ]);
  }
}
