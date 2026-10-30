import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';

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
    appBar: AppBar(),
    body: ListView(
      padding: EdgeInsets.only(bottom: bottomInset(context)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify your mobile', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text('We text you a 6-digit code so stations know your orders are real.', style: TextStyle(color: RF.muted)),
            ],
          ),
        ),
        FormSection(
          title: 'Mobile number',
          children: [
            LabeledField(
              controller: _phone,
              label: 'Mobile',
              icon: Icons.phone_iphone_rounded,
              hint: '0917 123 4567',
              keyboard: TextInputType.phone,
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await Api.sendPhoneOtp(_phone.text);
                      setState(() => _sent = true);
                    }),
              child: Text(_sent ? 'Resend code' : 'Send code'),
            ),
          ],
        ),
        if (_sent)
          FormSection(
            title: 'Enter code',
            children: [
              LabeledField(
                controller: _code,
                label: '6-digit code',
                icon: Icons.password_rounded,
                keyboard: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
      ],
    ),
    bottomNavigationBar: _sent
        ? BottomActionBar(
            child: PrimaryButton(
              label: 'Verify',
              busy: _busy,
              onPressed: _code.text.trim().length < 6
                  ? null
                  : () => _run(() async {
                      await Api.verifyPhoneOtp(_phone.text, _code.text.trim());
                      if (context.mounted) Navigator.pop(context, true);
                    }),
            ),
          )
        : null,
  );
}
