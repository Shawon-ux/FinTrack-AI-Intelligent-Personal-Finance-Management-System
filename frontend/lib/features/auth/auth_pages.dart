import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72, alignment: Alignment.center,
                decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(22)),
                child: const Text('💸', style: TextStyle(fontSize: 34)),
              ),
              const SizedBox(height: 22),
              const Text('Track your spending.\nControl your money.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
              const SizedBox(height: 10),
              const Text('AI categorisation, forecasts and anomaly alerts - even offline.', style: TextStyle(color: C.mut)),
              const SizedBox(height: 28),
              GradientButton('Get Started', () => context.go('/register')),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => context.go('/login'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: C.line)), child: const Text('Sign in')),
              const SizedBox(height: 18),
              const Center(child: Text('Understand Your Money. Predict Your Future.', style: TextStyle(color: C.mut, fontSize: 12))),
            ]),
          ),
        ),
      );
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, required this.register});
  final bool register;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  late final email = TextEditingController(text: widget.register ? '' : 'demo@fintrack.ai');
  late final pass = TextEditingController(text: widget.register ? '' : 'demo1234');
  final name = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      await ref.read(authProvider.notifier).authenticate(widget.register ? 'register' : 'login', email.text.trim(), pass.text, name: widget.register ? name.text : null);
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 30),
            Text(widget.register ? 'Create account' : 'Welcome back', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.register ? 'Start your intelligent finance journey' : 'Sign in to FinTrack AI', style: const TextStyle(color: C.mut)),
            const SizedBox(height: 20),
            if (widget.register) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: 12)],
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: 'Password', helperText: widget.register ? 'At least 8 characters' : null)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: C.bad, fontSize: 12))),
            const SizedBox(height: 16),
            GradientButton(widget.register ? 'Register' : 'Sign in', submit, busy: busy),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go(widget.register ? '/login' : '/register'),
                child: Text(widget.register ? 'Have an account? Sign in' : 'New here? Register'),
              ),
            ),
            if (!widget.register) const Center(child: Text('Demo: demo@fintrack.ai / demo1234', style: TextStyle(color: C.mut, fontSize: 12))),
          ]),
        ),
      );
}
