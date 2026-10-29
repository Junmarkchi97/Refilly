import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'models/models.dart';
import 'services/api.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/rider/rider_home.dart';
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
        theme: ThemeData(colorSchemeSeed: const Color(0xFF0288D1), useMaterial3: true),
        home: AppConfig.isConfigured
            ? const AuthGate()
            : const Scaffold(
                body: Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Supabase not configured.\nRun with --dart-define-from-file=env.json (see README).',
                            textAlign: TextAlign.center)))),
      );
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
              if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              final p = snap.data!;
              switch (p.role) {
                case 'rider':
                  return RiderHome(profile: p);
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
