import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.finishing = false,
  });

  final Future<void> Function() onFinish;
  final bool finishing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  const _OnboardingSlide(this.eyebrow, this.title, this.description);

  final String eyebrow;
  final String title;
  final String description;
}

const _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    'YOUR EVERYDAY ESSENTIALS',
    'Your essentials.\nReady for a refill.',
    'Start with water. Save a delivered order to My Essentials so your next refill is easier.',
  ),
  _OnboardingSlide(
    'A ROUTINE THAT FITS YOU',
    'Set the rhythm.\nWe’ll keep track.',
    'Choose weekly, every two weeks, or a custom interval. See what’s due when you open Refilly.',
  ),
  _OnboardingSlide(
    'YOU’RE ALWAYS IN CONTROL',
    'Due for a refill?\nYou’re already ready.',
    'Open a prefilled cart, review it, and place your order. Need more time? Snooze or skip.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;
  int _index = 0;

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

  void _next() {
    if (widget.finishing) { return; }
    HapticFeedback.selectionClick();
    if (_index == _slides.length - 1) {
      widget.onFinish();
      return;
    }
    if (MediaQuery.of(context).disableAnimations) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 430),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previous() {
    if (_index == 0 || widget.finishing) { return; }
    HapticFeedback.selectionClick();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.jumpToPage(_index - 1);
    } else {
      _controller.animateToPage(
        _index - 1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 820),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 18, 12),
                  child: Row(
                    children: [
                      const RefillyMark(size: 38),
                      const SizedBox(width: 10),
                      Text(
                        'Refilly',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const Spacer(),
                      if (!isLast)
                        TextButton(
                          onPressed: widget.finishing ? null : widget.onFinish,
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const Key('onboarding-pages'),
                    controller: _controller,
                    physics: widget.finishing ? const NeverScrollableScrollPhysics() : null,
                    itemCount: _slides.length,
                    onPageChanged: (value) {
                      if (mounted) { setState(() => _index = value); }
                    },
                    itemBuilder: (context, index) => AnimatedBuilder(
                      animation: _controller,
                      child: _SlideContent(
                        key: ValueKey('slide-$index-${_index == index}'),
                        index: index,
                        data: _slides[index],
                        active: _index == index,
                      ),
                      builder: (context, child) {
                        if (MediaQuery.of(context).disableAnimations) {
                          return child!;
                        }
                        final page = _controller.hasClients && _controller.position.haveDimensions
                            ? _controller.page ?? 0
                            : 0.0;
                        final distance = (page - index).clamp(-1.0, 1.0);
                        return Transform.translate(
                          offset: Offset(distance * 32, 0),
                          child: Opacity(
                            opacity: (1 - distance.abs() * .35).clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 10, 26, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _slides.length; i++)
                            Semantics(
                              label: 'Page ${i + 1} of ${_slides.length}',
                              selected: i == _index,
                              child: AnimatedContainer(
                                duration: MediaQuery.of(context).disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                height: 7,
                                width: _index == i ? 28 : 7,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  color: _index == i ? RF.accent : RF.line,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          key: const Key('onboarding-primary'),
                          onPressed: widget.finishing ? null : _next,
                          child: widget.finishing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(isLast ? 'Create account' : 'Next'),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: _index > 0
                            ? TextButton(
                                onPressed: widget.finishing ? null : _previous,
                                child: const Text('Back'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({super.key, required this.index, required this.data, required this.active});

  final bool active;

  final int index;
  final _OnboardingSlide data;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 490;
      final artworkHeight = (constraints.maxHeight * (compact ? .43 : .49))
          .clamp(185.0, 330.0);
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: artworkHeight,
                width: double.infinity,
                child: _Entrance(
                  active: active,
                  child: _OnboardingArtwork(index: index, active: active),
                ),
              ),
              SizedBox(height: compact ? 22 : 34),
              _Entrance(
                active: active,
                start: .12,
                child: Text(
                data.eyebrow,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RF.accent,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ),
              const SizedBox(height: 12),
              _Entrance(
                active: active,
                start: .22,
                child: Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RF.ink,
                  fontSize: compact ? 27 : 32,
                  letterSpacing: -1.2,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
              ),
              const SizedBox(height: 14),
              _Entrance(
                active: active,
                start: .34,
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    color: RF.muted,
                    height: 1.55,
                  ),
                ),
              ),
              ),
              SizedBox(height: compact ? 12 : 20),
            ],
          ),
        ),
      );
    },
  );
}


/// Illustrative preview only: never creates a routine or submits an order.
class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({required this.index, required this.active});
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final still = !active || MediaQuery.of(context).disableAnimations;
    Widget scene(double progress) => Semantics(
      label: [
        'Demo: a delivered water order is saved to My Essentials.',
        'Demo: a weekly refill interval is selected.',
        'Demo: a due refill opens a cart for review. No order is placed.',
      ][index],
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ColoredBox(
            color: const Color(0xFFF0F5FF),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 420,
                  height: 300,
                  child: _RoutineScene(index: index, progress: progress),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (still) { return scene(1); }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2400),
      builder: (context, value, _) => scene(value),
    );
  }
}

class _RoutineScene extends StatelessWidget {
  const _RoutineScene({required this.index, required this.progress});
  final int index;
  final double progress;

  Widget card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE0E9FB)),
      boxShadow: const [BoxShadow(color: Color(0x140B5DDB), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: child,
  );

  Widget pill(String label, IconData icon, {bool blue = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: blue ? RF.accent : const Color(0xFFEAF3FF),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 17, color: blue ? Colors.white : RF.accent),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: blue ? Colors.white : RF.accent)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final settled = progress > .55;
    final rise = Curves.easeOutCubic.transform((progress / .55).clamp(0.0, 1.0));
    return Stack(
      children: [
        Positioned(
          left: index == 0 ? 18 : 110, top: -50,
          child: Container(width: 270, height: 270,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDCEAFF))),
        ),
        if (index == 0) ...[
          Positioned(
            left: 34, top: 18 + 18 * (1 - rise),
            child: Transform.rotate(
              angle: -.08 * (1 - rise),
              child: const SizedBox(width: 135, height: 220,
                child: CustomPaint(painter: _WaterJugPainter())),
            ),
          ),
          Positioned(
            left: 172, right: 22, top: 57,
            child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Water refill', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Your regular order', style: TextStyle(color: RF.muted, fontSize: 12)),
              const SizedBox(height: 20),
              pill(settled ? 'Saved' : 'Delivered', settled ? Icons.bookmark_added_rounded : Icons.check_circle_outline),
            ])),
          ),
          Positioned(
            bottom: 25, left: 79,
            child: Opacity(opacity: rise,
              child: pill('My Essentials', Icons.favorite_rounded, blue: true)),
          ),
        ] else if (index == 1) ...[
          Positioned(left: 32, right: 32, top: 28,
            child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your refill rhythm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Water refill · Repeat reminder', style: TextStyle(color: RF.muted, fontSize: 13)),
              const SizedBox(height: 23),
              Row(children: [
                for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) ...[
                  Expanded(child: Container(
                    height: 37, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: day == 'M' && settled ? RF.accent : const Color(0xFFF1F5FC),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(day, style: TextStyle(fontWeight: FontWeight.w700,
                      color: day == 'M' && settled ? Colors.white : RF.muted)))),
                  if (day != 'S') const SizedBox(width: 5),
                ],
              ]),
              const SizedBox(height: 23),
              pill(settled ? 'Every week' : 'Choose an interval', Icons.event_repeat_rounded, blue: settled),
            ]))),
          Positioned(bottom: 15, right: 34,
            child: Opacity(opacity: rise, child: pill('Weekly · Biweekly · Custom', Icons.tune_rounded))),
        ] else ...[
          Positioned(left: 35, right: 35, top: 30 - 12 * rise,
            child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.water_drop_rounded, size: 32, color: RF.accent),
                const SizedBox(width: 12),
                const Expanded(child: Text('Water refill', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFE8890C), shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 17),
              Text(settled ? 'Your cart is ready to review' : 'Your next refill is due',
                style: const TextStyle(color: RF.muted, fontSize: 14)),
              const SizedBox(height: 20),
              pill(settled ? 'Review cart' : 'Refill now',
                settled ? Icons.shopping_bag_outlined : Icons.refresh_rounded, blue: true),
              const SizedBox(height: 17),
              const Text('Snooze     ·     Skip this refill',
                style: TextStyle(color: RF.muted, fontSize: 12)),
            ]))),
          Positioned(bottom: 13, left: 92,
            child: Opacity(opacity: rise, child: pill('You confirm every order', Icons.check_circle_outline))),
        ],
      ],
    );
  }
}

/// Crisp native vector artwork scales with every device density.
class _WaterJugPainter extends CustomPainter {
  const _WaterJugPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 135, size.height / 220);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 48, 108, 153), const Radius.circular(30));
    canvas.drawShadow(Path()..addRRect(body), const Color(0x550748BD), 12, false);
    canvas.drawRRect(body, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF8EC8FF), Color(0xFF1778F3), Color(0xFF0755D9)],
    ).createShader(const Rect.fromLTWH(14, 48, 108, 153)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(43, 23, 50, 40), const Radius.circular(9)),
      Paint()..color = const Color(0xFF469EF6));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(39, 13, 58, 22), const Radius.circular(7)),
      Paint()..color = const Color(0xFF0755C8));
    for (final y in [83.0, 159.0, 179.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(20, y, 96, 6), const Radius.circular(3)),
        Paint()..color = const Color(0x3355B4FF));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(25, 65, 10, 81), const Radius.circular(5)),
      Paint()..color = const Color(0x559EDBFF));
    canvas.drawCircle(const Offset(68, 122), 27, Paint()..color = Colors.white);
    final drop = Path()..moveTo(68, 103)..cubicTo(60, 114, 55, 119, 57, 126)
      ..cubicTo(60, 139, 79, 139, 80, 126)..cubicTo(81, 119, 75, 111, 68, 103)..close();
    canvas.drawPath(drop, Paint()..color = RF.accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterJugPainter oldDelegate) => false;
}

/// A finite, staggered entrance: settles fully and respects accessibility settings.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, required this.active, this.start = 0});

  final Widget child;
  final bool active;
  final double start;

  @override
  Widget build(BuildContext context) {
    if (!active || MediaQuery.of(context).disableAnimations) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      child: child,
      builder: (context, value, child) {
        final progress = ((value - start) / (1 - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        final spring = Curves.easeOutBack.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - spring)),
            child: Transform.scale(
              scale: .96 + .04 * spring,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
