import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/notifications_sheet.dart';
import '../../shared/widgets.dart';
import 'admin_dashboard.dart';
import 'admin_providers.dart';

void openAuditLog(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Audit log')), body: const SafeArea(child: AdminLogs()))));

/// Audit log with search.
class AdminLogs extends ConsumerStatefulWidget {
  const AdminLogs({super.key});
  @override
  ConsumerState<AdminLogs> createState() => _LogsState();
}

class _LogsState extends ConsumerState<AdminLogs> {
  String q = '';
  Timer? _deb;
  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(adminLogsProvider(q));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Security & admin activity', style: TextStyle(color: C.mut, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), () => setState(() => q = v.trim()));
            },
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search action, user or detail…', isDense: true),
          ),
        ]),
      ),
      Expanded(
        child: res.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(errText(e))),
          data: (l) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminLogsProvider(q)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: l.length,
              itemBuilder: (_, i) {
                final a = l[i];
                final act = '${a['action']}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: activityColor(act).withValues(alpha: .15), borderRadius: BorderRadius.circular(11)), child: Icon(activityIcon(act), size: 18, color: activityColor(act))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(act.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${a['user__email'] ?? 'anonymous'} · ${a['ip'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.mut, fontSize: 11)),
                        if ('${a['detail']}'.isNotEmpty) Text('${a['detail']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                    Text(ago(a['created_at']), style: TextStyle(color: C.mut, fontSize: 11)),
                  ]),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Settings / account tab for the administrator.
class AdminMore extends ConsumerWidget {
  const AdminMore({super.key});

  Widget _tile(IconData i, Color c, String t, String? s, {VoidCallback? onTap, Widget? trailing}) => ListTile(
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: c, size: 20)),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: s == null ? null : Text(s, style: const TextStyle(fontSize: 12)),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      );

  Widget _group(List<Widget> k) => Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)), child: Column(children: k));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider);
    final name = '${me?['first_name'] ?? ''}'.isEmpty ? '${me?['email']}'.split('@').first : '${me?['first_name']}';
    final unread = ref.watch(notificationsProvider).valueOrNull?.where((n) => n['is_read'] != true).length ?? 0;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
      Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(24)),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54), child: Avatar(name: name, dataUrl: (me?['profile'] as Map?)?['avatar'] as String?, radius: 30)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), Text('${me?['email']}', style: const TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 6), const Text('🛡 Administrator', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          ]),
        ),
      ),
      _group([
        _tile(Icons.notifications_outlined, C.p, 'Admin notifications', unread == 0 ? 'No new alerts' : '$unread unread (sign-ups, feedback…)', onTap: () => showNotificationsSheet(context)),
        _tile(Icons.list_alt, C.p2, 'Audit log', 'Logins, changes and admin actions', onTap: () => openAuditLog(context)),
      ]),
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(C.dark ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: C.p2), const SizedBox(width: 10), const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.wb_sunny_outlined, size: 17), label: Text('Light')), ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.nightlight_outlined, size: 17), label: Text('Night')), ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 17), label: Text('Auto'))],
              selected: {ref.watch(themeProvider)},
              onSelectionChanged: (v) => ref.read(themeProvider.notifier).set(v.first),
            ),
          ),
        ]),
      ),
      _group([_tile(Icons.shield_outlined, C.ok, 'Privacy', 'You see aggregate data only. Users\' transactions stay private.')]),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: C.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
    ]);
  }
}
