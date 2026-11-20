import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../data/providers.dart';

IconData notificationIcon(String kind) => switch (kind) {
      'budget' => Icons.account_balance_wallet_outlined,
      'anomaly' => Icons.warning_amber_rounded,
      'goal' => Icons.flag_outlined,
      'announcement' => Icons.campaign_outlined,
      'support' => Icons.support_agent,
      'signup' => Icons.person_add_alt_1_outlined,
      'feedback' => Icons.chat_bubble_outline,
      _ => Icons.notifications_none,
    };

Color notificationColor(String kind) => switch (kind) {
      'budget' => C.warn,
      'anomaly' => C.bad,
      'goal' => C.ok,
      'announcement' => C.p,
      'support' => C.p2,
      'signup' => C.ok,
      _ => C.p2,
    };

/// Bell icon with an unread badge. Tap to open the notifications sheet.
class BellButton extends ConsumerWidget {
  const BellButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).valueOrNull?.where((n) => n['is_read'] != true).length ?? 0;
    return Stack(clipBehavior: Clip.none, children: [
      IconButton.filledTonal(
        style: IconButton.styleFrom(backgroundColor: C.card2, foregroundColor: C.text),
        onPressed: () => showNotificationsSheet(context),
        icon: const Icon(Icons.notifications_outlined),
      ),
      if (unread > 0)
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: C.bad, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.bg, width: 2)),
            child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

void showNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Consumer(builder: (c, r, _) {
      final n = r.watch(notificationsProvider);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              TextButton(
                  onPressed: () async {
                    await r.read(apiProvider).post('/notifications/read_all/');
                    r.invalidate(notificationsProvider);
                  },
                  child: const Text('Mark all read')),
            ]),
            n.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(errText(e)),
              data: (l) => l.isEmpty
                  ? Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('🎉 All caught up', style: TextStyle(color: C.mut))))
                  : Flexible(
                      child: ListView(shrinkWrap: true, children: [
                        for (final x in l)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: x['is_read'] == true ? C.card : C.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: x['is_read'] == true ? C.line : notificationColor('${x['kind']}').withValues(alpha: .5))),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 38, height: 38, decoration: BoxDecoration(color: notificationColor('${x['kind']}').withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: Icon(notificationIcon('${x['kind']}'), color: notificationColor('${x['kind']}'), size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${x['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('${x['body']}', style: TextStyle(color: C.mut, fontSize: 13)),
                                ]),
                              ),
                              if (x['is_read'] != true) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: C.p, shape: BoxShape.circle)),
                            ]),
                          ),
                      ]),
                    ),
            ),
          ]),
        ),
      );
    }),
  );
}
