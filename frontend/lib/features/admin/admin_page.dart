import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'admin_broadcast.dart';
import 'admin_dashboard.dart';
import 'admin_feedback.dart';
import 'admin_more.dart';
import 'admin_providers.dart';
import 'admin_users.dart';

/// Administrator console: Dashboard · Users · Broadcast · Feedback · More (audit log, notifications, theme).
/// Shows aggregate / account-level data only - never private transaction content.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  static const _tabs = [AdminDashboard(), AdminUsers(), AdminBroadcast(), AdminFeedback(), AdminMore()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(adminTabProvider);
    final openFb = ref.watch(adminStatsProvider).valueOrNull?['open_feedback'] as num? ?? 0;
    return Scaffold(
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(tab), child: _tabs[tab]))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => ref.read(adminTabProvider.notifier).state = i,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          const NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Broadcast'),
          NavigationDestination(
            icon: Badge(isLabelVisible: openFb > 0, backgroundColor: C.bad, label: Text('$openFb'), child: const Icon(Icons.inbox_outlined)),
            selectedIcon: const Icon(Icons.inbox),
            label: 'Feedback',
          ),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
