import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/api.dart';
import '../../services/social_auth.dart';
import '../../theme.dart';
import '../widgets.dart';
import '../brand.dart';
import '../onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialSignup = false});
  final bool initialSignup;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(), _pass = TextEditingController();
  final _name = TextEditingController(), _phone = TextEditingController();
  late bool _signup;
  bool _busy = false, _showPassword = false;

  @override
  void initState() {
    super.initState();
    _signup = widget.initialSignup;
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

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

  Future<void> _socialSignIn(OAuthProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SocialAuth.signIn(provider);
      // For mobile, the browser returns through the registered deep link.
      // On the web Supabase redirects and AuthGate observes the new session.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign-in could not start. Please try again. ($error)'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _socialButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
  }) => SizedBox(
    height: 52,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 32, 24, bottomInset(context)),
            shrinkWrap: true,
            children: [
              const Center(child: RefillyMark(size: 104)),
              const SizedBox(height: 24),
              Text(
                _signup ? 'Create your\naccount' : 'Your essentials.\nOne less thing to remember.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Save your essentials, track when refills are due, and reorder with less effort.',
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
                decoration: const InputDecoration(labelText: 'Email', floatingLabelBehavior: FloatingLabelBehavior.always),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                decoration: InputDecoration(
                  labelText: 'Password',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                ),
                obscureText: !_showPassword,
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
              const SizedBox(height: 20),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or continue with', style: TextStyle(color: RF.muted, fontSize: 12)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 14),
              _socialButton(
                label: 'Continue with Google',
                icon: const Text('G', style: TextStyle(
                  color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 22,
                )),
                onPressed: _busy ? null : () => _socialSignIn(OAuthProvider.google),
              ),
              if (SocialAuth.appleAvailable) ...[
                const SizedBox(height: 10),
                _socialButton(
                  label: 'Continue with Apple',
                  icon: const Icon(Icons.apple_rounded, size: 23),
                  onPressed: _busy ? null : () => _socialSignIn(OAuthProvider.apple),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _signup = !_signup),
                child: Text(_signup ? 'Have an account? Log in' : 'New here? Sign up'),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (tourContext) => OnboardingScreen(
                      onFinish: () async {
                        Navigator.of(tourContext).pop();
                        if (mounted) { setState(() => _signup = true); }
                      },
                    ),
                  ),
                ),
                child: const Text('See how Refilly works'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
