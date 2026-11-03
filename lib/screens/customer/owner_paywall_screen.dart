import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../theme.dart';
import '../design.dart';
import '../motion.dart';
import '../network_states.dart';
import 'apply_owner_screen.dart';

enum OwnerPlan { monthly, yearly }

class OwnerPricing {
  static const monthly = 249;
  static const yearlyDiscount = .40;
  static int get yearly => (monthly * 12 * (1 - yearlyDiscount)).round();
  static int get yearlyPerMonth => (yearly / 12).round();
}

String peso(int v) {
  final s = v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₱$s';
}

/// Full-screen paywall shown before a customer applies to run a station.
class OwnerPaywallScreen extends StatefulWidget {
  final Future<int> Function(String code)? redeemVoucher;
  final Future<void> Function(String plan)? choosePlan;
  const OwnerPaywallScreen({super.key, this.redeemVoucher, this.choosePlan});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const OwnerPaywallScreen()),
  );

  @override
  State<OwnerPaywallScreen> createState() => _OwnerPaywallScreenState();
}

class _OwnerPaywallScreenState extends State<OwnerPaywallScreen> {
  OwnerPlan _plan = OwnerPlan.yearly;
  bool _busy = false;

  void _continueToApplication() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ApplyOwnerScreen()));
  }

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      await (widget.choosePlan ?? Api.chooseOwnerPlan)(_plan.name);
      if (!mounted) return;
      _continueToApplication();
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: 'Could not save your plan. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _voucher() async {
    final months = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoucherSheet(redeem: widget.redeemVoucher ?? Api.redeemOwnerVoucher),
    );
    if (months == null || !mounted) return;
    showAppNotice(context, 'Voucher applied: $months months free', kind: AppNotice.success);
    _continueToApplication();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: RF.bg,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, top + 48, 20, 16),
                  children: [
                    Text(
                      'Grow your refilling station',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Get orders from nearby customers and run deliveries in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RF.muted, fontSize: 14, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    _PlanCard(
                      selected: _plan == OwnerPlan.yearly,
                      title: 'Yearly',
                      price: '${peso(OwnerPricing.yearly)} / year',
                      caption: 'Just ${peso(OwnerPricing.yearlyPerMonth)} a month',
                      badge: 'SAVE 40%',
                      strike: peso(OwnerPricing.monthly * 12),
                      onTap: () => setState(() => _plan = OwnerPlan.yearly),
                    ),
                    const SizedBox(height: 10),
                    _PlanCard(
                      selected: _plan == OwnerPlan.monthly,
                      title: 'Monthly',
                      price: '${peso(OwnerPricing.monthly)} / month',
                      caption: 'Flexible, cancel anytime',
                      onTap: () => setState(() => _plan = OwnerPlan.monthly),
                    ),
                    const SizedBox(height: 16),
                    const SoftCard(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Column(
                        children: [
                          _Benefit(Icons.receipt_long_rounded, 'Real-time orders'),
                          _Benefit(Icons.two_wheeler_rounded, 'Riders and live tracking'),
                          _Benefit(Icons.inventory_2_rounded, 'Your own storefront'),
                          _Benefit(Icons.bar_chart_rounded, 'Sales reports'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: EdgeInsets.fromLTRB(20, 0, 20, 10 + (bottom > 0 ? 0 : 6)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _subscribe,
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text(_plan == OwnerPlan.yearly
                                ? 'Continue with Yearly · ${peso(OwnerPricing.yearly)}'
                                : 'Continue with Monthly · ${peso(OwnerPricing.monthly)}'),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _voucher,
                      icon: const Icon(Icons.confirmation_number_outlined, size: 20),
                      label: const Text('Have a voucher code?'),
                    ),
                    const Text(
                      'No charge today. Billing starts after your station is approved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RF.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: top + 4,
            right: 8,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Benefit(this.icon, this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: RF.accentSoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: RF.accentInk, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final bool selected;
  final String title, price, caption;
  final String? badge, strike;
  final VoidCallback onTap;
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.caption,
    required this.onTap,
    this.badge,
    this.strike,
  });

  @override
  Widget build(BuildContext context) => GradientFrame(
    selected: selected,
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: Row(
      children: [
        AnimatedContainer(
          duration: Motion.d(context, Motion.fast),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? RF.ink : Colors.white,
            border: Border.all(color: selected ? RF.ink : RF.line, width: 2),
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: RF.good, borderRadius: BorderRadius.circular(99)),
                      child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (strike != null)
                    Text(strike!, style: const TextStyle(color: RF.muted, fontSize: 13, decoration: TextDecoration.lineThrough)),
                ],
              ),
              const SizedBox(height: 2),
              Text(caption, style: const TextStyle(color: RF.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Bottom sheet for sponsor voucher codes. Pops with the free months granted.
class VoucherSheet extends StatefulWidget {
  final Future<int> Function(String code) redeem;
  const VoucherSheet({super.key, required this.redeem});
  @override
  State<VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends State<VoucherSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final months = await widget.redeem(code);
      if (mounted) Navigator.of(context).pop(months);
    } catch (e) {
      if (mounted) setState(() => _error = describeFailure(e, failed: 'That voucher code could not be applied.').message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter voucher code', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Sponsored shops get free months on Refilly.', style: TextStyle(color: RF.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _apply(),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Voucher code',
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy || _code.text.trim().isEmpty ? null : _apply,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Apply voucher'),
          ),
        ),
      ],
    ),
  );
}
