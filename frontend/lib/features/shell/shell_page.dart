import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../budgets/budgets_page.dart';
import '../dashboard/dashboard_page.dart';
import '../insights/insights_page.dart';
import '../profile/profile_page.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/transactions_page.dart';
import '../../shared/widgets.dart';

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});
  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  int tab = 0;
  static const pages = [DashboardPage(), TransactionsPage(), BudgetsPage(), InsightsPage(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(txProvider.notifier).refresh();
      final m = await ref.read(txProvider.notifier).sync();
      if (m != null && mounted) snack(context, m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tx = ref.watch(txProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (tx.offline)
            Container(width: double.infinity, color: C.warn.withValues(alpha: .15), padding: const EdgeInsets.all(7),
                child: Text('📴 Offline mode - changes saved on this device${tx.queue.isNotEmpty ? ' (${tx.queue.length} pending)' : ''}', textAlign: TextAlign.center, style: const TextStyle(color: C.warn, fontSize: 12, fontWeight: FontWeight.w600)))
          else if (tx.syncing)
            Container(width: double.infinity, color: C.p2.withValues(alpha: .15), padding: const EdgeInsets.all(7), child: const Text('⟳ Syncing…', textAlign: TextAlign.center, style: TextStyle(color: C.p2, fontSize: 12)))
          else if (tx.queue.isNotEmpty)
            InkWell(
              onTap: () async { final m = await ref.read(txProvider.notifier).sync(); if (m != null && context.mounted) snack(context, m); },
              child: Container(width: double.infinity, color: C.p2.withValues(alpha: .15), padding: const EdgeInsets.all(7), child: Text('${tx.queue.length} change(s) waiting - tap to sync', textAlign: TextAlign.center, style: const TextStyle(color: C.p2, fontSize: 12))),
            ),
          Expanded(child: IndexedStack(index: tab, children: pages)),
        ]),
      ),
      floatingActionButton: tab < 3
          ? Container(
              decoration: const BoxDecoration(gradient: C.grad, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x667C5CFF), blurRadius: 18)]),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent, elevation: 0, onPressed: () => showAddTransaction(context),
                child: const Icon(Icons.add, size: 30, color: Colors.white),
              ))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
