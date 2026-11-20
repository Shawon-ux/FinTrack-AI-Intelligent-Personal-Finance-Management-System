import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import 'admin_providers.dart';

Color statusColor(String s) => s == 'resolved' ? C.ok : s == 'in_progress' ? C.warn : C.p2;

class AdminFeedback extends ConsumerStatefulWidget {
  const AdminFeedback({super.key});
  @override
  ConsumerState<AdminFeedback> createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<AdminFeedback> {
  String status = '';

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(adminFeedbackProvider(status));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Feedback inbox', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in const {'': 'All', 'open': 'Open', 'in_progress': 'In progress', 'resolved': 'Resolved'}.entries)
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(e.value), selected: status == e.key, onSelected: (_) => setState(() => status = e.key))),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: res.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(errText(e))),
          data: (l) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminFeedbackProvider(status)),
            child: l.isEmpty
                ? ListView(children: [Padding(padding: const EdgeInsets.all(60), child: Center(child: Text('📭 No feedback here', style: TextStyle(color: C.mut))))])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final f = l[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _open(context, f),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Avatar(name: '${f['user__email']}', radius: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${f['user__email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                              Pill('${f['status']}'.replaceAll('_', ' '), color: statusColor('${f['status']}')),
                            ]),
                            const SizedBox(height: 8),
                            Text('${f['message']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(ago(f['created_at']), style: TextStyle(color: C.mut, fontSize: 11)),
                              const Spacer(),
                              if ((f['reply'] ?? '').toString().isNotEmpty) const Pill('✓ replied', color: C.ok) else Text('Tap to reply', style: TextStyle(color: C.p2, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    ]);
  }

  void _open(BuildContext context, J f) {
    final reply = TextEditingController();
    var st = '${f['status']}';
    var busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 22), children: [
            Text('${f['user__email']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(ago(f['created_at']), style: TextStyle(color: C.mut, fontSize: 12)),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(14)), child: Text('${f['message']}')),
            if ((f['reply'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.ok.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Text('You replied ${ago(f['replied_at'])}:\n${f['reply']}')),
            ],
            const SizedBox(height: 14),
            Text('Status', style: TextStyle(color: C.mut, fontSize: 12)),
            Wrap(spacing: 8, children: [for (final s in ['open', 'in_progress', 'resolved']) ChoiceChip(label: Text(s.replaceAll('_', ' ')), selected: st == s, onSelected: (_) => set(() => st = s))]),
            const SizedBox(height: 12),
            TextField(controller: reply, maxLines: 3, decoration: const InputDecoration(labelText: 'Reply to user (they get a notification)', alignLabelWithHint: true)),
            const SizedBox(height: 14),
            GradientButton(reply.text.isEmpty ? 'Save status' : 'Send reply & save', () async {
              set(() => busy = true);
              try {
                await ref.read(apiProvider).post('/admin/feedback/${f['id']}/', {'status': st, if (reply.text.trim().isNotEmpty) 'reply': reply.text.trim()});
                ref.invalidate(adminFeedbackProvider(status));
                ref.invalidate(adminStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) snack(context, 'Updated ✓');
              } catch (e) {
                set(() => busy = false);
                if (ctx.mounted) snack(ctx, errText(e));
              }
            }, busy: busy),
          ]),
        ),
      ),
    );
  }
}
