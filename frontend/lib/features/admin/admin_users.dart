import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import 'admin_dashboard.dart';
import 'admin_providers.dart';

Color roleColor(String r) => r == 'admin' ? C.bad : r == 'premium' ? C.warn : C.mut;
String roleLabel(String r) => r == 'admin' ? '🛡 Admin' : r == 'premium' ? '⭐ Premium' : 'Free';

class AdminUsers extends ConsumerStatefulWidget {
  const AdminUsers({super.key});
  @override
  ConsumerState<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends ConsumerState<AdminUsers> {
  String q = '', status = '', plan = '';
  Timer? _deb;

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  String get key => '$q|$status|$plan';

  Widget _chip(String label, bool on, VoidCallback f) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => f()));

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(adminUsersProvider(key));
    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              if (res.valueOrNull != null) Pill('${res.value!['total']} found', color: C.p),
            ]),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 350), () => setState(() => q = v.trim()));
              },
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or email…', isDense: true),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('All', status == '' && plan == '', () => setState(() { status = ''; plan = ''; })),
                _chip('Active', status == 'active', () => setState(() { status = status == 'active' ? '' : 'active'; })),
                _chip('Disabled', status == 'disabled', () => setState(() { status = status == 'disabled' ? '' : 'disabled'; })),
                _chip('⭐ Premium', plan == 'premium', () => setState(() { plan = plan == 'premium' ? '' : 'premium'; })),
                _chip('Free', plan == 'free', () => setState(() { plan = plan == 'free' ? '' : 'free'; })),
                _chip('🛡 Admins', plan == 'admin', () => setState(() { plan = plan == 'admin' ? '' : 'admin'; })),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(errText(e))),
            data: (d) {
              final list = List<J>.from((d['results'] as List).map((e) => Map<String, dynamic>.from(e)));
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminUsersProvider(key)),
                child: list.isEmpty
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(50), child: Center(child: Text('No users match.', style: TextStyle(color: C.mut))))])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _row(context, list[i]),
                      ),
              );
            },
          ),
        ),
      ]),
      Positioned(
        right: 16,
        bottom: 16,
        child: Container(
          decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: C.p.withValues(alpha: .4), blurRadius: 16)]),
          child: FloatingActionButton.extended(
            heroTag: 'adduser',
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            onPressed: () => _add(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add user'),
          ),
        ),
      ),
    ]);
  }

  Widget _row(BuildContext context, J u) {
    final role = '${u['role']}';
    final active = u['active'] == true;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailPage(id: u['id'] as int)));
        ref.invalidate(adminUsersProvider(key));
        ref.invalidate(adminStatsProvider);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
        child: Row(children: [
          Stack(children: [
            Avatar(name: '${u['name']}'.isEmpty ? '${u['email']}' : '${u['name']}', radius: 22),
            Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: active ? C.ok : C.bad, shape: BoxShape.circle, border: Border.all(color: C.card, width: 2)))),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u['name']}'.isEmpty ? '${u['email']}' : '${u['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${u['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.mut, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Joined ${ago(u['joined'])} · last login ${ago(u['last_login'])} · ${u['tx_count'] ?? 0} tx', style: TextStyle(color: C.mut, fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill(roleLabel(role), color: roleColor(role)),
            if (!active) const Padding(padding: EdgeInsets.only(top: 4), child: Pill('disabled', color: C.bad)),
          ]),
        ]),
      ),
    );
  }

  void _add(BuildContext context) {
    final email = TextEditingController(), name = TextEditingController(), pass = TextEditingController();
    var role = 'user', busy = false, hide = true;
    String gen() {
      const c = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final r = math.Random.secure();
      return List.generate(12, (_) => c[r.nextInt(c.length)]).join();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 22), children: [
            const Text('Add a new user', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: hide,
              decoration: InputDecoration(
                labelText: 'Password (min 8)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => set(() => hide = !hide)),
                  IconButton(tooltip: 'Generate', icon: const Icon(Icons.auto_fix_high, size: 20), onPressed: () => set(() { pass.text = gen(); hide = false; })),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text('Role', style: TextStyle(color: C.mut, fontSize: 12)),
            Wrap(spacing: 8, children: [for (final r in ['user', 'premium', 'admin']) ChoiceChip(label: Text(roleLabel(r)), selected: role == r, onSelected: (_) => set(() => role = r))]),
            const SizedBox(height: 18),
            GradientButton('Create user', () async {
              set(() => busy = true);
              try {
                await ref.read(apiProvider).post('/admin/users/', {'email': email.text, 'password': pass.text, 'name': name.text, 'role': role});
                ref.invalidate(adminUsersProvider(key));
                ref.invalidate(adminStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) snack(context, 'User created ✓  Share the password securely.');
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

// ------------------------------------------------------------------ detail page

class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({super.key, required this.id});
  final int id;

  Future<void> _act(BuildContext context, WidgetRef ref, Map<String, dynamic> body, {String? ok}) async {
    try {
      final r = await ref.read(apiProvider).post('/admin/users/$id/', body);
      ref.invalidate(adminUserProvider(id));
      if (r is Map && r['temp_password'] != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Temporary password'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Share this with the user securely. It is shown only once.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              SelectableText('${r['temp_password']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ]),
            actions: [
              TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: '${r['temp_password']}')); snack(ctx, 'Copied'); }, child: const Text('Copy')),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        );
      } else if (ok != null && context.mounted) {
        snack(context, ok);
      }
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String msg, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: const TextStyle(color: C.bad)))]),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(adminUserProvider(id));
    final myId = ref.watch(authProvider)?['id'];
    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: d.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errText(e))),
        data: (u) {
          final role = '${u['role']}', active = u['active'] == true;
          final c = u['counts'] as Map;
          final isMe = myId == u['id'];
          Widget stat(String l, dynamic v, IconData i) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                  child: Column(children: [Icon(i, size: 18, color: C.p2), const SizedBox(height: 4), Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(l, style: TextStyle(color: C.mut, fontSize: 11))]),
                ),
              );
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(24)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54), child: Avatar(name: '${u['name']}'.isEmpty ? '${u['email']}' : '${u['name']}', radius: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${u['name']}'.isEmpty ? 'No name' : '${u['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${u['email']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [
                        _badge(roleLabel(role)),
                        _badge(active ? '● Active' : '● Disabled'),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [stat('Transactions', c['transactions'], Icons.receipt_long), const SizedBox(width: 8), stat('Budgets', c['budgets'], Icons.flag_outlined), const SizedBox(width: 8), stat('Goals', c['goals'], Icons.savings_outlined)]),
            const SizedBox(height: 8),
            Row(children: [stat('Accounts', c['accounts'], Icons.account_balance_wallet_outlined), const SizedBox(width: 8), stat('Open alerts', c['alerts_open'], Icons.warning_amber_rounded), const SizedBox(width: 8), stat('Sync fails', c['sync_failed'], Icons.sync_problem_outlined)]),
            const SizedBox(height: 14),
            _section('Account', [
              _info('Joined', ago(u['joined'])),
              _info('Last login', ago(u['last_login'])),
              _info('First transaction', u['first_tx'] == null ? '-' : ago(u['first_tx'])),
              _info('Currency', '${u['currency']}'),
              _info('Onboarding done', u['onboarded'] == true ? 'Yes' : 'No'),
              _info('AI learning consent', u['ai_consent'] == true ? 'Yes' : 'No'),
            ]),
            _section('Manage', [
              ListTile(leading: const Icon(Icons.campaign_outlined, color: C.p), title: const Text('Send notification'), trailing: const Icon(Icons.chevron_right), onTap: () => _notify(context, ref, '${u['email']}')),
              SwitchListTile(secondary: const Icon(Icons.star_outline, color: C.warn), title: const Text('Premium plan'), value: role == 'premium', onChanged: role == 'admin' ? null : (v) => _act(context, ref, {'premium': v}, ok: v ? 'Premium enabled' : 'Premium removed')),
              SwitchListTile(secondary: const Icon(Icons.shield_outlined, color: C.bad), title: const Text('Administrator'), value: role == 'admin', onChanged: isMe ? null : (v) async { if (await _confirm(context, v ? 'Make admin?' : 'Remove admin?', v ? 'This user will be able to manage all users.' : 'They will lose admin access.', 'Confirm')) { if (context.mounted) _act(context, ref, {'admin': v}, ok: 'Role updated'); } }),
              SwitchListTile(secondary: Icon(Icons.power_settings_new, color: active ? C.ok : C.bad), title: const Text('Account active'), subtitle: Text(active ? 'User can sign in' : 'Sign-in is blocked'), value: active, onChanged: isMe ? null : (v) => _act(context, ref, {'active': v}, ok: v ? 'Account enabled' : 'Account disabled')),
              ListTile(leading: const Icon(Icons.lock_reset, color: C.p2), title: const Text('Reset password'), subtitle: const Text('Generates a temporary password'), onTap: () async { if (await _confirm(context, 'Reset password?', 'A new temporary password will be created and the old one stops working.', 'Reset') && context.mounted) _act(context, ref, {'reset_password': true}); }),
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: C.bad),
                  title: const Text('Delete user & all data', style: TextStyle(color: C.bad)),
                  onTap: () async {
                    if (await _confirm(context, 'Delete this user?', 'This permanently deletes the account and all of its data. This cannot be undone.', 'Delete') && context.mounted) {
                      try {
                        await ref.read(apiProvider).delete('/admin/users/$id/');
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) snack(context, errText(e));
                      }
                    }
                  },
                ),
            ]),
            _section('Recent activity', [
              if ((u['activity'] as List).isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No recorded activity.', style: TextStyle(color: C.mut))),
              for (final a in u['activity'])
                ListTile(
                  dense: true,
                  leading: Icon(activityIcon('${a['action']}'), color: activityColor('${a['action']}'), size: 20),
                  title: Text('${a['action']}'.replaceAll('_', ' ')),
                  subtitle: Text('${a['detail']}'.isEmpty ? '${a['ip'] ?? ''}' : '${a['detail']} · ${a['ip'] ?? ''}'),
                  trailing: Text(ago(a['created_at']), style: TextStyle(color: C.mut, fontSize: 11)),
                ),
            ]),
            Text('🔒 Transaction contents are private and not visible to administrators.', style: TextStyle(color: C.mut, fontSize: 11)),
          ]);
        },
      ),
    );
  }

  Widget _badge(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)), child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)));

  Widget _info(String k, String v) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [Expanded(child: Text(k, style: TextStyle(color: C.mut))), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]));

  Widget _section(String t, List<Widget> kids) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 6, bottom: 6), child: Text(t.toUpperCase(), style: TextStyle(color: C.mut, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1))),
          Container(decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)), child: Column(children: kids)),
        ]),
      );

  void _notify(BuildContext context, WidgetRef ref, String email) {
    final t = TextEditingController(), b = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 22), children: [
          Text('Notify $email', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: t, maxLength: 80, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 4),
          TextField(controller: b, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
          const SizedBox(height: 14),
          GradientButton('Send', () async {
            try {
              await ref.read(apiProvider).post('/admin/broadcast/', {'title': t.text, 'body': b.text, 'audience': 'user', 'user_id': id});
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) snack(context, 'Notification sent ✓');
            } catch (e) {
              if (ctx.mounted) snack(ctx, errText(e));
            }
          }),
        ]),
      ),
    );
  }
}
