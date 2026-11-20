import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/animated_background.dart';
import '../../shared/widgets.dart';

/// Fades + slides a child in after [delay].
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 650 + delay),
    curve: Interval(delay / (650 + delay), 1, curve: Curves.easeOutCubic),
    builder: (_, v, c) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: c),
    ),
    child: child,
  );
}

class _Logo extends StatelessWidget {
  const _Logo({this.size = 76});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: C.grad,
      borderRadius: BorderRadius.circular(size * .3),
      boxShadow: [
        BoxShadow(
          color: C.p.withValues(alpha: .55),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Text('💸', style: TextStyle(fontSize: size * .46)),
  );
}

// ---------------------------------------------------------------- landing

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomeState();
}

class _WelcomeState extends State<WelcomePage> {
  final _pc = PageController(viewportFraction: .86);
  int _page = 0;
  Timer? _timer;
  static const features = [
    (
      '✨',
      'Smart AI categorising',
      'Type “Paid ৳650 at KFC for dinner” and we sort out the amount, merchant and category.',
    ),
    (
      '📈',
      'Predict your spending',
      'Forecasts, budget alerts and unusual-spend detection keep you a step ahead.',
    ),
    (
      '📴',
      'Works offline',
      'Add transactions anywhere. They sync safely - and only once - when you are back online.',
    ),
    (
      '🎯',
      'Reach your goals',
      'Budgets, recurring bills and savings goals that show exactly what you need to save.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients) return;
      _pc.animateToPage(
        (_page + 1) % features.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          const _Reveal(child: _Logo(size: 84)),
                          const SizedBox(height: 22),
                          const _Reveal(
                            delay: 150,
                            child: Text(
                              'FinTrack AI',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _Reveal(
                            delay: 250,
                            child: ShaderMask(
                              shaderCallback: (r) => C.grad.createShader(r),
                              child: const Text(
                                'Understand Your Money. Predict Your Future.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _Reveal(
                            delay: 400,
                            child: SizedBox(
                              height: 224,
                              child: PageView.builder(
                                controller: _pc,
                                itemCount: features.length,
                                onPageChanged: (i) => setState(() => _page = i),
                                itemBuilder: (_, i) {
                                  final f = features[i];
                                  return AnimatedScale(
                                    scale: _page == i ? 1 : .92,
                                    duration: const Duration(milliseconds: 300),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: .06,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: .12,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.$1,
                                            style: const TextStyle(
                                              fontSize: 30,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            f.$2,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            f.$3,
                                            style: const TextStyle(
                                              color: C.mut,
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < features.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: _page == i ? 22 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _page == i ? C.p : C.line,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          _Reveal(
                            delay: 550,
                            child: GradientButton(
                              'Get Started',
                              () => context.go('/register'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _Reveal(
                            delay: 650,
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => context.go('/login'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: .2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'I already have an account',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- login / register

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, required this.register});
  final bool register;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  late bool register = widget.register;
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController();
  bool hide = true, busy = false, success = false;
  String? error, notice;
  final errs = <String, String>{};
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _server() async {
    final api = ref.read(apiProvider);
    final c = TextEditingController(text: api.base);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Where your FinTrack AI backend runs, e.g. http://192.168.0.101:8000 (same Wi-Fi) or https://api.yourdomain.com', style: TextStyle(fontSize: 12, color: C.mut)),
          const SizedBox(height: 10),
          TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ),
    );
    if (ok == true) {
      await api.setBase(c.text);
      if (mounted) { setState(() { error = null; }); snack(context, 'Server set to ${api.base}'); }
    }
  }

  void _switch(bool toRegister) {
    if (toRegister == register) return;
    setState(() {
      register = toRegister;
      error = null;
      notice = null;
      errs.clear();
    });
  }

  int get strength {
    final p = pass.text;
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  bool _validate() {
    errs.clear();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim()))
      errs['email'] = 'Enter a valid email address';
    if (pass.text.length < 8) errs['pass'] = 'Use at least 8 characters';
    setState(() {});
    if (errs.isNotEmpty) _shake.forward(from: 0);
    return errs.isEmpty;
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (register) {
        await auth.register(
          email.text.trim(),
          pass.text,
          name: name.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          success = true;
          busy = false;
        });
        await Future.delayed(const Duration(milliseconds: 2000));
        if (!mounted) return;
        setState(() {
          success = false;
          register = false;
          pass.clear();
          notice = 'Account created! Sign in to continue.';
        });
      } else {
        await auth.authenticate(
          'login',
          email.text.trim(),
          pass.text,
        ); // router redirects to the app
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = errText(e));
        _shake.forward(from: 0);
      }
    }
    if (mounted) setState(() => busy = false);
  }

  InputDecoration _dec(
    String label,
    IconData icon, {
    String? err,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: C.mut),
    suffixIcon: suffix,
    errorText: err,
    fillColor: Colors.white.withValues(alpha: .06),
  );

  @override
  Widget build(BuildContext context) {
    final form = Column(
      key: ValueKey(register),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (register) ...[
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _dec('Full name', Icons.person_outline),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: _dec('Email', Icons.mail_outline, err: errs['email']),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: pass,
          obscureText: hide,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => submit(),
          autofillHints: [
            register ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: _dec(
            'Password',
            Icons.lock_outline,
            err: errs['pass'],
            suffix: IconButton(
              icon: Icon(
                hide
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => hide = !hide),
            ),
          ),
        ),
        if (register) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: pass.text.isNotEmpty && i < strength.clamp(1, 4)
                          ? [C.bad, C.warn, C.p2, C.ok][strength.clamp(1, 4) -
                                1]
                          : C.line,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pass.text.isEmpty
                ? 'At least 8 characters. Mix letters, numbers and symbols.'
                : ['Weak', 'Okay', 'Good', 'Strong'][strength.clamp(1, 4) - 1],
            style: const TextStyle(fontSize: 12, color: C.mut),
          ),
        ],
      ],
    );

    return Scaffold(
      body: AnimatedBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => context.go('/welcome'),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                            ),
                          ),
                        ),
                        const _Reveal(child: _Logo(size: 64)),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (c, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, .25),
                                end: Offset.zero,
                              ).animate(a),
                              child: c,
                            ),
                          ),
                          child: Column(
                            key: ValueKey(register),
                            children: [
                              Text(
                                register
                                    ? 'Create your account'
                                    : 'Welcome back',
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                register
                                    ? 'Start your intelligent finance journey'
                                    : 'Sign in to continue to FinTrack AI',
                                style: const TextStyle(color: C.mut),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        AnimatedBuilder(
                          animation: _shake,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(
                              math.sin(_shake.value * math.pi * 6) *
                                  9 *
                                  (1 - _shake.value),
                              0,
                            ),
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .05),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .1),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 30,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _Toggle(register: register, onChanged: _switch),
                                const SizedBox(height: 20),
                                if (notice != null)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: C.ok.withValues(alpha: .13),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: C.ok,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            notice!,
                                            style: const TextStyle(
                                              color: C.ok,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (c, a) => FadeTransition(
                                      opacity: a,
                                      child: SlideTransition(
                                        position: Tween(
                                          begin: Offset(
                                            register ? .08 : -.08,
                                            0,
                                          ),
                                          end: Offset.zero,
                                        ).animate(a),
                                        child: c,
                                      ),
                                    ),
                                    layoutBuilder: (cur, prev) => Stack(
                                      alignment: Alignment.topCenter,
                                      children: [...prev, if (cur != null) cur],
                                    ),
                                    child: form,
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  child: error == null
                                      ? const SizedBox(width: double.infinity)
                                      : Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                            top: 14,
                                          ),
                                          padding: const EdgeInsets.all(11),
                                          decoration: BoxDecoration(
                                            color: C.bad.withValues(alpha: .13),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline,
                                                color: C.bad,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  error!,
                                                  style: const TextStyle(
                                                    color: C.bad,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                GradientButton(
                                  register ? 'Create account' : 'Sign in',
                                  submit,
                                  busy: busy,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!register)
                          ActionChip(
                            avatar: const Text('⚡'),
                            label: const Text(
                              'Fill demo account',
                              style: TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: .06,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                            onPressed: () => setState(() {
                              email.text = 'demo@fintrack.ai';
                              pass.text = 'demo1234';
                              errs.clear();
                            }),
                          ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _server,
                          icon: const Icon(Icons.dns_outlined, size: 16, color: C.mut),
                          label: Text(ref.read(apiProvider).base, style: const TextStyle(color: C.mut, fontSize: 11)),
                        ),
                        TextButton(
                          onPressed: () => _switch(!register),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(color: C.mut),
                              children: [
                                TextSpan(
                                  text: register
                                      ? 'Already have an account?  '
                                      : 'New to FinTrack AI?  ',
                                ),
                                TextSpan(
                                  text: register ? 'Sign in' : 'Create account',
                                  style: const TextStyle(
                                    color: C.p2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // success overlay after registering
            IgnorePointer(
              ignoring: !success,
              child: AnimatedOpacity(
                opacity: success ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: C.bg.withValues(alpha: .92),
                  alignment: Alignment.center,
                  child: success
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.elasticOut,
                              builder: (_, v, __) => Transform.scale(
                                scale: v,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: C.grad,
                                    boxShadow: [
                                      BoxShadow(
                                        color: C.p.withValues(alpha: .6),
                                        blurRadius: 40,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const _Reveal(
                              delay: 200,
                              child: Text(
                                'You are all set! 🎉',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const _Reveal(
                              delay: 350,
                              child: Text(
                                'Taking you to sign in…',
                                style: TextStyle(color: C.mut),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliding pill toggle: Sign in | Register.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.register, required this.onChanged});
  final bool register;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Stack(
      children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          alignment: register ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: .5,
            child: Container(
              decoration: BoxDecoration(
                gradient: C.grad,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Row(
          children: [
            for (final e in [(false, 'Sign in'), (true, 'Register')])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(e.$1),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: register == e.$1 ? Colors.white : C.mut,
                      ),
                      child: Text(e.$2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
