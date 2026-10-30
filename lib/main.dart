import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'theme.dart';
import 'models/models.dart';
import 'services/api.dart';
import 'services/onboarding_store.dart';
import 'screens/onboarding_screen.dart';
import 'screens/brand.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/rider/rider_link_screen.dart';
import 'screens/admin/admin_home.dart';
import 'screens/owner/owner_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  }
  runApp(const RefillyApp());
}

class RefillyApp extends StatelessWidget {
  const RefillyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Refilly',
    debugShowCheckedModeBanner: false,
    theme: refillyTheme(),
    home: AppConfig.isConfigured
        ? (riderTokenFromUrl() != null ? RiderLinkScreen(token: riderTokenFromUrl()!) : const FirstLaunchGate())
        : const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Supabase not configured.\nRun with --dart-define-from-file=env.json (see README).',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
  );
}

/// Shows onboarding only for unsigned-in first-time visitors.
/// Signed-in users and anonymous rider delivery links bypass it entirely.
class FirstLaunchGate extends StatefulWidget {
  const FirstLaunchGate({super.key, this.store});

  final OnboardingStore? store;

  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  late final OnboardingStore _store;
  late final Future<bool> _isComplete;
  bool _finishedThisSession = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? OnboardingStore();
    _isComplete = _store.isComplete();
  }

  Future<void> _finish() async {
    if (_saving) { return; }
    setState(() => _saving = true);
    try {
      await _store.markComplete();
    } catch (_) {
      // A storage failure must never lock a customer out of sign-in.
      // They can still continue for this session.
    }
    if (!mounted) { return; }
    setState(() {
      _saving = false;
      _finishedThisSession = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sb.auth.currentSession != null || _finishedThisSession) {
      return const AuthGate();
    }
    return FutureBuilder<bool>(
      future: _isComplete,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RefillyMark(size: 76),
                  SizedBox(height: 18),
                  CircularProgressIndicator(strokeWidth: 2.4),
                ],
              ),
            ),
          );
        }
        if (snapshot.data == true) { return const AuthGate(); }
        return OnboardingScreen(onFinish: _finish, finishing: _saving);
      },
    );
  }
}

/// Riders open `<app>/#/rider/<token>` (or `/rider/<token>`) with no login.
String? riderTokenFromUrl() {
  final u = Uri.base;
  final path = u.fragment.isNotEmpty ? u.fragment : u.path;
  final m = RegExp(r'^/?rider/([A-Za-z0-9]{32,128})').firstMatch(path);
  return m?.group(1);
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: sb.auth.onAuthStateChange,
    builder: (context, _) {
      if (sb.auth.currentSession == null) return const LoginScreen();
      return FutureBuilder<Profile?>(
        key: ValueKey(sb.auth.currentUser?.id),
        future: Api.me(),
        builder: (context, snap) {
          if (snap.hasError) return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load your profile: ${snap.error}'))));
          if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (!snap.hasData) return const Scaffold(body: Center(child: Text('Your profile was not found. Please contact support.')));
          final p = snap.data!;
          switch (p.role) {
            case 'admin':
              return AdminHome(profile: p);
            case 'owner':
              return OwnerHome(profile: p);
            default:
              return CustomerHome(profile: p);
          }
        },
      );
    },
  );
}
