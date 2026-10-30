import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import '../brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(), _pass = TextEditingController();
  final _name = TextEditingController(), _phone = TextEditingController();
  bool _signup = false, _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (_signup) {
        await sb.auth.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          data: {'full_name': _name.text.trim(), 'phone': _phone.text.trim()},
        );
      } else {
        await sb.auth.signInWithPassword(email: _email.text.trim(), password: _pass.text);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 26, 24, bottomInset(context)),
            shrinkWrap: true,
            children: [
              const Center(child: RefillyMark(size: 106)),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'REFILLY',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: RF.accent,
                    letterSpacing: 3.2,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                _signup ? 'Your refill\nstarts here.' : 'Fresh water.\nAt your door.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Discover trusted local water stations, reorder in seconds, and track every delivery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RF.muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),
              if (_signup) ...[
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Mobile (09xx)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (_signup)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Station owners: sign up, then apply in Profile → Become a station owner.',
                    style: TextStyle(fontSize: 12, color: RF.muted),
                  ),
                ),
              const SizedBox(height: 24),
              Pressable(
                child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_signup ? 'Create account' : 'Log in')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _signup = !_signup),
                child: Text(_signup ? 'Have an account? Log in' : 'New here? Sign up'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
