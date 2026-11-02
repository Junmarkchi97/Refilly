import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.onSignIn,
    this.finishing = false,
  });

  /// Leaves the tour for account creation.
  final Future<void> Function() onFinish;

  /// Leaves the tour for an existing customer to log in. Hidden when null.
  final Future<void> Function()? onSignIn;
  final bool finishing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Step {
  const _Step(this.photo, this.title, this.description, this.chips);
  final String photo, title, description;
  final List<_ChipSpec> chips;
}

class _ChipSpec {
  const _ChipSpec(this.icon, this.label, this.alignment, {this.dark = false});
  final IconData icon;
  final String label;
  final Alignment alignment;
  final bool dark;
}

const _steps = <_Step>[
  _Step(
    'assets/welcome/station.jpg',
    'Pick a station\nyou can trust',
    'Compare nearby refilling stations, their prices and delivery fees before you order.',
    [
      _ChipSpec(Icons.verified_rounded, 'Verified station', Alignment(-.86, -.78)),
      _ChipSpec(Icons.water_drop_rounded, 'Refill from ₱35', Alignment(.84, .62), dark: true),
    ],
  ),
  _Step(
    'assets/welcome/doorstep.jpg',
    'Delivered to\nyour door',
    'Choose a delivery window, lobby or doorstep, and pay cash when it arrives.',
    [
      _ChipSpec(Icons.schedule_rounded, 'Today, 2–4 PM', Alignment(.86, -.8)),
      _ChipSpec(Icons.payments_outlined, 'Cash on Delivery', Alignment(-.84, .66), dark: true),
    ],
  ),
  _Step(
    'assets/welcome/phone.jpg',
    'Your usuals,\none tap away',
    'Save an order to My Essentials. We remind you when it may be time, and nothing is ordered until you confirm.',
    [
      _ChipSpec(Icons.event_repeat_rounded, 'Refill due Thursday', Alignment(-.84, -.78)),
      _ChipSpec(Icons.check_circle_rounded, 'You confirm every order', Alignment(.8, .64), dark: true),
    ],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;
  int _index = 0;

  int get _pageCount => _steps.length + 1;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(page, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
    }
  }

  void _next() {
    if (widget.finishing) { return; }
    HapticFeedback.selectionClick();
    if (_index == _pageCount - 1) {
      widget.onFinish();
      return;
    }
    _go(_index + 1);
  }

  void _previous() {
    if (_index == 0 || widget.finishing) { return; }
    HapticFeedback.selectionClick();
    _go(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final welcome = _index == 0;
    final isLast = _index == _pageCount - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: RF.bg,
        body: Stack(
          children: [
            PageView.builder(
              key: const Key('onboarding-pages'),
              controller: _controller,
              physics: widget.finishing ? const NeverScrollableScrollPhysics() : null,
              itemCount: _pageCount,
              onPageChanged: (value) {
                if (mounted) { setState(() => _index = value); }
              },
              itemBuilder: (context, index) => index == 0
                  ? const _WelcomePage()
                  : _StepPage(step: _steps[index - 1], active: _index == index),
            ),
            if (!welcome)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                        child: SizedBox(
                          height: 44,
                          child: _StepBar(
                            index: _index - 1,
                            count: _steps.length,
                            onBack: widget.finishing ? null : _previous,
                            onSkip: isLast || widget.finishing ? null : widget.onFinish,
                            showSkip: !isLast,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _Actions(
                      label: welcome ? 'Get started' : isLast ? 'Create account' : 'Continue',
                      finishing: widget.finishing,
                      onPrimary: _next,
                      signIn: welcome && widget.onSignIn != null,
                      onSignIn: widget.finishing ? null : widget.onSignIn,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.index,
    required this.count,
    required this.onBack,
    required this.onSkip,
    required this.showSkip,
  });
  final int index, count;
  final VoidCallback? onBack, onSkip;
  final bool showSkip;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: RF.ink),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Semantics(
          label: 'Step ${index + 1} of $count',
          child: Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 320),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= index ? RF.ink : Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (i < count - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 64,
        child: showSkip ? TextButton(onPressed: onSkip, child: const Text('Skip')) : null,
      ),
    ],
  );
}

/// Space each page leaves free at the bottom for [_Actions].
const _actionsHeight = 128.0;
const _stepActionsHeight = 96.0;

class _Actions extends StatelessWidget {
  const _Actions({
    required this.label,
    required this.finishing,
    required this.onPrimary,
    required this.signIn,
    required this.onSignIn,
  });
  final String label;
  final bool finishing, signIn;
  final VoidCallback onPrimary;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: FilledButton(
            key: const Key('onboarding-primary'),
            onPressed: finishing ? null : onPrimary,
            child: finishing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ),
        if (signIn)
          SizedBox(height: 44, child: TextButton(onPressed: onSignIn, child: const Text('I already have an account')))
        else
          const SizedBox(height: 8),
      ],
    ),
  );
}

class _PageText extends StatelessWidget {
  const _PageText({required this.title, required this.body, this.brand = false});
  final String title, body;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 640;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brand)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(9), child: const RefillyMark(size: 34)),
                const SizedBox(width: 10),
                const Text('Refilly', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -.6)),
              ],
            ),
          ),
        Text(
          title,
          style: TextStyle(
            color: RF.ink,
            fontSize: compact ? 28 : 34,
            height: 1.08,
            letterSpacing: -1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(body, style: TextStyle(color: RF.muted, fontSize: compact ? 14 : 15, height: 1.45)),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const _WelcomeMosaic(),
      SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: c.maxHeight),
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, _actionsHeight),
                child: const _PageText(
                  brand: true,
                  title: 'Water and rice,\ndelivered home.',
                  body: 'Order from trusted neighborhood stations and keep your household essentials stocked.',
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// A slowly drifting wall of photos behind the welcome message.
class _WelcomeMosaic extends StatefulWidget {
  const _WelcomeMosaic();

  @override
  State<_WelcomeMosaic> createState() => _WelcomeMosaicState();
}

class _WelcomeMosaicState extends State<_WelcomeMosaic> with SingleTickerProviderStateMixin {
  static const _columns = [
    ['assets/welcome/doorstep.jpg', 'assets/products/jug-round.jpg', 'assets/welcome/rice.jpg', 'assets/products/rice-10.jpg'],
    ['assets/products/jug-slim.jpg', 'assets/welcome/kitchen.jpg', 'assets/products/rice-5.jpg', 'assets/welcome/station.jpg'],
    ['assets/welcome/phone.jpg', 'assets/products/rice-25.jpg', 'assets/products/jug-alkaline.jpg', 'assets/welcome/doorstep.jpg'],
  ];
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, c) {
        final colWidth = (c.maxWidth - 16 * 2 - 10 * 2) / 3;
        final tile = colWidth * 1.42;
        final loop = (tile + 10) * 4;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _drift,
                          builder: (context, child) {
                            final t = _drift.value * loop;
                            final offset = col.isOdd ? -loop + (t % loop) : -(t % loop);
                            return OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: double.infinity,
                              child: Transform.translate(offset: Offset(0, offset + (col.isOdd ? -tile * .45 : 0)), child: child),
                            );
                          },
                          child: Column(
                            children: [
                              for (final path in [..._columns[col], ..._columns[col], ..._columns[col]])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.asset(path, width: colWidth, height: tile, fit: BoxFit.cover, cacheWidth: 360),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (col < 2) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .3, .56, .72],
                    colors: [RF.bg.withValues(alpha: .0), RF.bg.withValues(alpha: .0), RF.bg.withValues(alpha: .92), RF.bg],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.active});
  final _Step step;
  final bool active;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LayoutBuilder(
          builder: (context, c) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, _stepActionsHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: RF.shadow),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(step.photo, fit: BoxFit.cover, cacheWidth: 900),
                          ),
                        ),
                        if (box.maxHeight > 220)
                          for (var i = 0; i < step.chips.length; i++)
                            Align(
                              alignment: step.chips[i].alignment,
                              child: _FloatingChip(spec: step.chips[i], active: active, delay: .25 + i * .2),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: c.maxHeight * .5),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _PageText(title: step.title, body: step.description),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Illustrative label only; it reflects real app features, not live data.
class _FloatingChip extends StatelessWidget {
  const _FloatingChip({required this.spec, required this.active, required this.delay});
  final _ChipSpec spec;
  final bool active;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
      decoration: BoxDecoration(
        color: spec.dark ? RF.button : Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [BoxShadow(color: Color(0x2632220F), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 17, color: spec.dark ? Colors.white : RF.accent),
          const SizedBox(width: 7),
          Text(
            spec.label,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: spec.dark ? Colors.white : RF.ink),
          ),
        ],
      ),
    );
    if (!active || MediaQuery.of(context).disableAnimations) { return chip; }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      child: chip,
      builder: (context, v, child) {
        final p = Curves.easeOutBack.transform(((v - delay) / (1 - delay)).clamp(0.0, 1.0));
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 14 * (1 - p)), child: Transform.scale(scale: .9 + .1 * p, child: child)),
        );
      },
    );
  }
}
