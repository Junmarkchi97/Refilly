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
    'EXPLORE WHAT\'S NEARBY',
    'Your neighborhood,\none tap away.',
    'Discover trusted nearby businesses, starting with local water refilling stations.',
  ),
  _OnboardingSlide(
    'MADE FOR EVERYDAY ORDERS',
    'Order in a few\nsimple taps.',
    'Choose what you need, pin your exact delivery address, and review the total before ordering.',
  ),
  _OnboardingSlide(
    'KNOW WHAT\'S NEXT',
    'From local shops\nto your doorstep.',
    'Follow order updates and track your rider when live location sharing is available.',
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
            constraints: const BoxConstraints(maxWidth: 520),
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
                                    Text(isLast ? 'Get started' : 'Next'),
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

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({required this.index, required this.active});

  final bool active;

  final int index;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF3FF), Color(0xFFF8FAFF)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -height * .33,
                right: -width * .2,
                child: Container(
                  width: width * .85,
                  height: width * .85,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD9E9FF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -height * .44,
                left: -width * .20,
                child: Container(
                  width: width,
                  height: width,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .62),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (index == 0)
                _DiscoverArtwork(width: width, height: height, active: active)
              else if (index == 1)
                _CheckoutArtwork(width: width, height: height, active: active)
              else
                _TrackingArtwork(width: width, height: height, active: active),
            ],
          ),
        ),
      );
    },
  );
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFDCE7F9)),
      boxShadow: [
        BoxShadow(
          color: RF.accent.withValues(alpha: .10),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: child,
  );
}

class _ArtworkLabel extends StatelessWidget {
  const _ArtworkLabel(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: RF.accentSoft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: RF.accent, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: RF.muted),
            ),
          ],
        ),
      ),
      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: RF.muted),
    ],
  );
}

class _DiscoverArtwork extends StatelessWidget {
  const _DiscoverArtwork({required this.width, required this.height, required this.active});

  final bool active;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: height * .12,
        left: width * .12,
        right: width * .12,
        child: _Entrance(active: active, start: .18, child: _ArtworkCard(
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: RF.accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Find your local favorites',
                  style: TextStyle(color: RF.muted, fontSize: 13),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: RF.accent,
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        )),
      ),
      Positioned(
        top: height * .38,
        left: width * .16,
        right: width * .16,
        child: _Entrance(active: active, start: .38, child: const _ArtworkCard(
          child: _ArtworkLabel(
            'Water refill stations',
            'Discover nearby shops',
            Icons.water_drop_outlined,
          ),
        )),
      ),
      Positioned(
        bottom: height * .10,
        left: width * .27,
        right: width * .12,
        child: _Entrance(active: active, start: .38, child: const _ArtworkCard(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: RF.accent, size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'More categories to come',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        )),
      ),
    ],
  );
}

class _CheckoutArtwork extends StatelessWidget {
  const _CheckoutArtwork({required this.width, required this.height, required this.active});

  final bool active;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: height * .11,
        left: width * .16,
        right: width * .16,
        child: _Entrance(active: active, start: .18, child: _ArtworkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: RF.accent, size: 21),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Refill essentials',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('2 items', style: TextStyle(color: RF.muted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 13),
              Container(height: 1, color: RF.line),
              const SizedBox(height: 13),
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, color: RF.accent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your chosen drop-off',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: Color(0xFF21AA79), size: 18),
                ],
              ),
            ],
          ),
        )),
      ),
      Positioned(
        bottom: height * .13,
        left: width * .23,
        right: width * .13,
        child: _Entrance(active: active, start: .18, child: _ArtworkCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RF.accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.done_all_rounded, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Review. Confirm. Done.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        )),
      ),
    ],
  );
}

class _TrackingArtwork extends StatelessWidget {
  const _TrackingArtwork({required this.width, required this.height, required this.active});

  final bool active;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: CustomPaint(
          painter: _TrackingRoutePainter(),
        ),
      ),
      Positioned(
        top: height * .14,
        left: width * .12,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: const Icon(Icons.storefront_rounded, color: RF.accent, size: 26),
        ),
      ),
      Positioned(
        top: height * .32,
        right: width * .17,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: RF.accent),
          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 27),
        ),
      ),
      Positioned(
        bottom: height * .17,
        left: width * .18,
        right: width * .18,
        child: _Entrance(active: active, start: .38, child: const _ArtworkCard(
          child: _ArtworkLabel(
            'Out for delivery',
            'Follow your order status',
            Icons.route_rounded,
          ),
        )),
      ),
    ],
  );
}

class _TrackingRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .22, size.height * .28)
      ..cubicTo(
        size.width * .38,
        size.height * .08,
        size.width * .64,
        size.height * .54,
        size.width * .75,
        size.height * .46,
      );

    final paint = Paint()
      ..color = RF.accent.withValues(alpha: .40)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 14) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrackingRoutePainter oldDelegate) => false;
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
