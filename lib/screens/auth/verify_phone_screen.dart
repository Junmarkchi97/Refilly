import 'package:flutter/material.dart';
import '../../services/api.dart';

/// Supabase phone OTP. Requires an SMS provider (e.g. Twilio) under Auth → Providers → Phone.
class VerifyPhoneScreen extends StatefulWidget {
  final String? initialPhone;
  const VerifyPhoneScreen({super.key, this.initialPhone});
  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  bool _sent = false, _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verify your mobile number')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('We text you a 6-digit code so stations know your orders are real.'),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Mobile (09xx xxx xxxx)'), keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: _busy ? null : () => _run(() async {
                    await Api.sendPhoneOtp(_phone.text);
                    setState(() => _sent = true);
                  }),
              child: Text(_sent ? 'Resend code' : 'Send code')),
          if (_sent) ...[
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: _busy ? null : () => _run(() async {
                      await Api.verifyPhoneOtp(_phone.text, _code.text.trim());
                      if (context.mounted) Navigator.pop(context, true);
                    }),
                child: const Text('Verify')),
          ],
        ]),
      );
}
