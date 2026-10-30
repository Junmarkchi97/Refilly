import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

/// Motion tokens (iOS-like). Every helper respects the OS "reduce motion" setting.
class Motion {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
  static const spring = Cubic(0.175, 0.885, 0.32, 1.1); // gentle overshoot
  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;
  static Duration d(BuildContext c, Duration v) => reduced(c) ? Duration.zero : v;
  static AnimationStyle sheet = AnimationStyle(duration: slow, reverseDuration: fast, curve: spring);
}

/// Light haptic on phones (no-op on web/desktop).
void tapHaptic() {
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
    HapticFeedback.lightImpact();
  }
}

/// Scale-down-on-press wrapper (0.96, spring back). Child keeps its own onTap.
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scale;
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = .96});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (_) {
            _set(true);
            tapHaptic();
          }
        : null,
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: Motion.d(context, _down ? const Duration(milliseconds: 120) : Motion.medium),
      curve: _down ? Curves.easeOut : Motion.spring,
      child: widget.child,
    ),
  );
}

/// Staggered fade + slide-up entrance for list items (plays once).
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlideIn({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = (index.clamp(0, 8)) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delay),
      curve: Interval(delay / (300 + delay), 1, curve: Motion.curve),
      child: child,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: c),
      ),
    );
  }
}

/// Cross-fades between loading / empty / content.
class StateSwitcher extends StatelessWidget {
  final Widget child;
  const StateSwitcher({super.key, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.d(context, Motion.medium),
    switchInCurve: Motion.curve,
    switchOutCurve: Curves.easeInCubic,
    child: child,
  );
}

/// Shimmering placeholder block.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, c) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          colors: const [Color(0xFFEDECEF), Color(0xFFF8F8FA), Color(0xFFEDECEF)],
          stops: const [.1, .5, .9],
          begin: Alignment(-1.5 + 3 * _c.value, 0),
          end: Alignment(-.5 + 3 * _c.value, 0),
        ).createShader(r),
        child: c,
      ),
    ),
  );
}

/// Skeleton list of card placeholders (replaces spinners).
class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  const SkeletonList({super.key, this.count = 5, this.height = 84});
  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: count,
      itemBuilder: (_, i) => Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFEDECEF), borderRadius: BorderRadius.circular(RF.radius)),
      ),
    ),
  );
}

/// Number that counts up to [value].
class AnimatedCount extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  const AnimatedCount({super.key, required this.value, required this.format, this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value),
    duration: Motion.d(context, const Duration(milliseconds: 700)),
    curve: Motion.curve,
    builder: (_, v, _) => Text(format(v), style: style),
  );
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({super.begin, super.end});
  @override
  LatLng lerp(double t) =>
      LatLng(begin!.latitude + (end!.latitude - begin!.latitude) * t, begin!.longitude + (end!.longitude - begin!.longitude) * t);
}

/// Marker layer that glides between GPS updates instead of jumping.
class GlidingMarker extends StatelessWidget {
  final LatLng point;
  final Marker Function(LatLng) builder;
  const GlidingMarker({super.key, required this.point, required this.builder});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<LatLng>(
    tween: _LatLngTween(begin: point, end: point),
    duration: Motion.d(context, const Duration(milliseconds: 1200)),
    curve: Curves.easeInOutCubic,
    builder: (_, p, _) => MarkerLayer(markers: [builder(p)]),
  );
}
