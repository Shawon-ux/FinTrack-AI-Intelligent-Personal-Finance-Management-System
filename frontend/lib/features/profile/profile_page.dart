import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

final _txCountProvider = FutureProvider.autoDispose<int>(
  (ref) async =>
      ((await ref.read(apiProvider).get('/sync/status/'))['transactions']
              as num)
          .toInt(),
);

/// Staggered fade/slide entrance.
class _In extends StatelessWidget {
  const _In(this.i, this.child);
  final int i;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 450 + i * 90),
    curve: Curves.easeOutCubic,
    builder: (_, v, c) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * 22), child: c),
    ),
    child: child,
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: C.mut,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, indent: 62, color: C.line),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color == C.bad ? C.bad : null,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(color: C.mut, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          trailing ??
              (onTap != null
                  ? Icon(Icons.chevron_right, color: C.mut)
                  : const SizedBox.shrink()),
        ],
      ),
    ),
  );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authProvider);
    final tx = ref.watch(txProvider);
    final ov = ref.watch(overviewProvider).valueOrNull;
    final total = ref.watch(_txCountProvider).valueOrNull;
    if (u == null) return const SizedBox();
    final p = (u['profile'] ?? {}) as Map;
    final name = '${u['first_name'] ?? ''}'.isEmpty
        ? '${u['email']}'.split('@').first
        : '${u['first_name']}';
    final income = double.tryParse('${p['monthly_income']}') ?? 0,
        target = double.tryParse('${p['savings_target']}') ?? 0;
    final saved = ov == null
        ? 0.0
        : ((ov['income'] as num) - (ov['expense'] as num)).toDouble();
    final pct = target > 0
        ? (saved / target * 100).clamp(0, 100).toDouble()
        : 0.0;
    final role = '${u['role']}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ---------- header
        _In(
          0,
          DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: C.grad,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: C.p.withValues(alpha: .35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _photo(context, ref),
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white54,
                                  ),
                                  child: Avatar(
                                    name: name,
                                    dataUrl: p['avatar'] as String?,
                                    radius: 36,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: C.bg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.photo_camera,
                                      size: 14,
                                      color: C.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${u['email']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    _chip(
                                      role == 'premium'
                                          ? '⭐ Premium'
                                          : role == 'admin'
                                          ? '🛡 Admin'
                                          : 'Free plan',
                                    ),
                                    _chip('${p['currency'] ?? 'BDT'}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white24,
                            ),
                            onPressed: () => _edit(context, ref),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ---------- stats
        _In(
          1,
          Row(
            children: [
              Expanded(
                child: _stat(
                  '🧾',
                  '${total ?? tx.merged.length}',
                  'Transactions',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  '💚',
                  ov == null ? '-' : '${ov['health']['score']}',
                  'Health score',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  '💰',
                  ov == null ? '-' : '${ov['savings_rate']}%',
                  'Savings rate',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------- savings target progress
        if (target > 0)
          _In(
            2,
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Monthly savings target',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Pill('${pct.round()}%', color: pct >= 100 ? C.ok : C.p),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Bar(v, goal: true),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${fmt(saved < 0 ? 0 : saved)} saved of ${fmt(target)} this month',
                    style: TextStyle(color: C.mut, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

        // ---------- appearance
        _In(
          3,
          _Section('Appearance', [
            _Tile(
              icon: Icons.account_circle_outlined,
              color: C.p,
              title: 'Profile photo',
              subtitle: (p['avatar'] ?? '').toString().isEmpty
                  ? 'Add a picture'
                  : 'Change or remove your picture',
              trailing: Avatar(
                name: name,
                dataUrl: p['avatar'] as String?,
                radius: 18,
              ),
              onTap: () => _photo(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: C.p2.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          C.dark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          color: C.p2,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Theme',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.wb_sunny_outlined, size: 17),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.nightlight_outlined, size: 17),
                          label: Text('Night'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.phone_android, size: 17),
                          label: Text('Auto'),
                        ),
                      ],
                      selected: {ref.watch(themeProvider)},
                      onSelectionChanged: (v) =>
                          ref.read(themeProvider.notifier).set(v.first),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // ---------- financial profile
        _In(
          3,
          _Section('Financial profile', [
            _Tile(
              icon: Icons.payments_outlined,
              color: C.ok,
              title: 'Monthly income',
              subtitle: income > 0 ? fmt(income) : 'Not set',
              onTap: () => _edit(context, ref, tab: 1),
            ),
            _Tile(
              icon: Icons.savings_outlined,
              color: C.warn,
              title: 'Savings target',
              subtitle: target > 0 ? fmt(target) : 'Not set',
              onTap: () => _edit(context, ref, tab: 1),
            ),
            _Tile(
              icon: Icons.currency_exchange,
              color: C.p2,
              title: 'Currency',
              subtitle: '${p['currency'] ?? 'BDT'}',
              onTap: () => _edit(context, ref, tab: 1),
            ),
          ]),
        ),

        // ---------- preferences
        _In(
          4,
          _Section('Preferences', [
            _Tile(
              icon: Icons.auto_awesome,
              color: C.p,
              title: 'Anonymised AI learning',
              subtitle: 'Off by default. Never trains a global model without your consent.',
              trailing: Switch(
                value: p['ai_learning_consent'] == true,
                onChanged: (v) async {
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .updateMe(profile: {'ai_learning_consent': v});
                  } catch (e) {
                    if (context.mounted) snack(context, errText(e));
                  }
                },
              ),
            ),
            _Tile(
              icon: Icons.airplanemode_active,
              color: C.warn,
              title: 'Simulate offline mode',
              subtitle: 'Try adding transactions without internet',
              trailing: Switch(
                value: tx.offline,
                onChanged: (v) => ref.read(txProvider.notifier).setOffline(v),
              ),
            ),
          ]),
        ),

        // ---------- sync
        _In(
          5,
          _Section('Sync', [
            _Tile(
              icon: tx.queue.isEmpty
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined,
              color: tx.queue.isEmpty ? C.ok : C.warn,
              title: tx.queue.isEmpty
                  ? 'Everything is synced'
                  : '${tx.queue.length} change(s) waiting',
              subtitle: tx.offline ? 'Offline mode is on' : 'Tap to sync now',
              trailing: tx.syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: () async {
                final m = await ref.read(txProvider.notifier).sync();
                if (context.mounted) snack(context, m ?? 'Nothing to sync');
              },
            ),
          ]),
        ),

        // ---------- support & data
        _In(
          6,
          _Section('Support & data', [
            _Tile(
              icon: Icons.chat_bubble_outline,
              color: C.p2,
              title: 'Send feedback',
              subtitle: 'Tell us what to improve',
              onTap: () => _feedback(context, ref),
            ),
            _Tile(
              icon: Icons.shield_outlined,
              color: C.ok,
              title: 'Privacy',
              subtitle: 'Your records are private to you. Admins only see aggregate stats.',
            ),
            _Tile(
              icon: Icons.delete_outline,
              color: C.bad,
              title: 'Delete my account & data',
              onTap: () => _delete(context, ref),
            ),
          ]),
        ),

        // ---------- logout
        _In(
          7,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: C.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'FinTrack AI · v1.0.0\nUnderstand Your Money. Predict Your Future.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.mut, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      t,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _stat(String emoji, String v, String l) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: C.line),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          v,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        Text(l, style: TextStyle(color: C.mut, fontSize: 11)),
      ],
    ),
  );

  Future<void> _photo(BuildContext context, WidgetRef ref) async {
    final has = ((ref.read(authProvider)?['profile'] as Map?)?['avatar'] ?? '')
        .toString()
        .isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile photo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (has)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: C.bad),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: C.bad),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'remove') {
        await ref.read(authProvider.notifier).updateMe(profile: {'avatar': ''});
        if (context.mounted) snack(context, 'Photo removed');
        return;
      }
      // downscale on the device so the upload stays small (~20-60 KB)
      final f = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 80,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final mime = (f.mimeType ?? '').startsWith('image/')
          ? f.mimeType!
          : 'image/jpeg';
      if (bytes.length > 280000) {
        if (context.mounted)
          snack(
            context,
            'That picture is too large - please choose a smaller one.',
          );
        return;
      }
      await ref
          .read(authProvider.notifier)
          .updateMe(
            profile: {'avatar': 'data:$mime;base64,${base64Encode(bytes)}'},
          );
      if (context.mounted) snack(context, 'Profile photo updated ✓');
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  // ---------- editor
  void _edit(BuildContext context, WidgetRef ref, {int tab = 0}) {
    final u = ref.read(authProvider)!;
    final p = (u['profile'] ?? {}) as Map;
    final name = TextEditingController(text: '${u['first_name'] ?? ''}');
    final inc = TextEditingController(
      text: '${double.tryParse('${p['monthly_income']}')?.round() ?? 0}',
    );
    final sav = TextEditingController(
      text: '${double.tryParse('${p['savings_target']}')?.round() ?? 0}',
    );
    var cur = '${p['currency'] ?? 'BDT'}';
    var busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            children: [
              const Text(
                'Edit profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: inc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly income (৳)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sav,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly savings target (৳)',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Text('Currency', style: TextStyle(color: C.mut, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in ['BDT', 'USD', 'EUR', 'INR'])
                    ChoiceChip(
                      label: Text(c),
                      selected: cur == c,
                      onSelected: (_) => set(() => cur = c),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              GradientButton('Save changes', () async {
                set(() => busy = true);
                try {
                  await ref
                      .read(authProvider.notifier)
                      .updateMe(
                        name: name.text.trim(),
                        profile: {
                          'monthly_income': inc.text.isEmpty ? '0' : inc.text,
                          'savings_target': sav.text.isEmpty ? '0' : sav.text,
                          'currency': cur,
                          'onboarded': true,
                        },
                      );
                  ref.invalidate(overviewProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) snack(context, 'Profile updated ✓');
                } catch (e) {
                  set(() => busy = false);
                  if (ctx.mounted) snack(ctx, errText(e));
                }
              }, busy: busy),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _feedback(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send feedback'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'What can we improve?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).post('/feedback/', {'message': c.text});
      if (context.mounted) snack(context, 'Thanks for the feedback!');
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and all of your data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: C.bad)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }
}
