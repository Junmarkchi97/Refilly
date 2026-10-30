import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/models.dart';
import '../theme.dart';
import 'motion.dart';
export 'motion.dart';
import '../services/api.dart';

const manila = LatLng(14.5995, 120.9842);
String peso(num v) => '₱${v.toStringAsFixed(2)}';

/// OSM tiles softened into a light pastel basemap (Glide-style): low saturation, lifted brightness.
const _pastel = ColorFilter.matrix(<double>[
  0.55, 0.30, 0.08, 0, 38, //
  0.20, 0.65, 0.08, 0, 38, //
  0.20, 0.30, 0.43, 0, 44, //
  0, 0, 0, 1, 0,
]);
TileLayer osmTiles() => TileLayer(
  urlTemplate: AppConfig.tileUrl,
  userAgentPackageName: AppConfig.userAgent,
  tileBuilder: (context, child, tile) => ColorFiltered(colorFilter: _pastel, child: child),
);

Widget osmAttribution() => const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]);

Marker pin(LatLng p, IconData icon, Color color, {VoidCallback? onTap}) => Marker(
  point: p,
  width: 44,
  height: 44,
  child: GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: RF.shadow,
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    ),
  ),
);

/// Copy or share (SMS / Messenger share sheet) a rider delivery link.
Future<void> shareRiderLink(BuildContext context, String link, String riderName) => showModalBottomSheet(
  context: context,
  sheetAnimationStyle: Motion.sheet,
  builder: (c) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(title: Text('Delivery link for $riderName'), subtitle: SelectableText(link)),
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copy link'),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (c.mounted) Navigator.pop(c);
          },
        ),
        ListTile(
          leading: const Icon(Icons.share),
          title: const Text('Share (SMS, Messenger…)'),
          onTap: () async {
            await SharePlus.instance.share(ShareParams(text: 'Refilly delivery for $riderName: $link'));
            if (c.mounted) Navigator.pop(c);
          },
        ),
      ],
    ),
  ),
);

Widget logoutButton() => CircleIconButton(Icons.logout_rounded, onTap: () => sb.auth.signOut());

Color statusColor(String s) => switch (s) {
  'pending' => const Color(0xFFE8890C),
  'accepted' || 'preparing' => RF.accent,
  'out_for_delivery' => const Color(0xFF7B61FF),
  'delivered' || 'open' => const Color(0xFF1DB954),
  _ => RF.muted,
};

/// White rounded card with soft shadow (Cal AI style).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding, margin;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Pressable(
      enabled: onTap != null,
      scale: onTap == null ? 1 : .97,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? RF.card,
            borderRadius: BorderRadius.circular(RF.radius),
            border: Border.all(color: RF.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(RF.radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Big bold headline + muted subtitle used at the top of screens.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: RF.muted, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Big number with small label (dashboard tiles).
class StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? tint;
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.tint});
  @override
  Widget build(BuildContext context) => AppCard(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (tint ?? RF.ink).withValues(alpha: .08), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: tint ?? RF.ink),
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Text(
          label,
          style: const TextStyle(color: RF.muted, fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    ),
  );
}

/// Circular progress ring with a centered big value.
class Ring extends StatelessWidget {
  final double value, size, stroke;
  final Widget center;
  final Color color;
  const Ring({super.key, required this.value, required this.center, this.size = 120, this.stroke = 10, this.color = RF.ink});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(value: 1, strokeWidth: stroke, color: RF.line),
        ),
        SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
            duration: Motion.d(context, const Duration(milliseconds: 900)),
            curve: Motion.curve,
            builder: (_, v, _) => CircularProgressIndicator(value: v, strokeWidth: stroke, color: color, strokeCap: StrokeCap.round),
          ),
        ),
        center,
      ],
    ),
  );
}

/// Small rounded status pill.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: statusColor(status).withValues(alpha: .12), borderRadius: BorderRadius.circular(100)),
    child: Text(
      status == 'open' ? 'OPEN' : statusLabel(status),
      style: TextStyle(color: statusColor(status), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .3),
    ),
  );
}

/// Minimal floating bottom navigation (black pill highlights the active tab).
class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, String)> items;
  const FloatingNav({super.key, required this.index, required this.onTap, required this.items});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: RF.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkResponse(
                  onTap: () {
                    tapHaptic();
                    onTap(i);
                  },
                  child: AnimatedScale(
                    scale: i == index ? 1 : .94,
                    duration: Motion.d(context, Motion.fast),
                    curve: Motion.curve,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].$1, size: 25, color: i == index ? RF.ink : const Color(0xFF9A9AA0)),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: Motion.d(context, Motion.fast),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? RF.ink : const Color(0xFF9A9AA0),
                          ),
                          child: Text(items[i].$2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Round white icon button (top-right actions).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const CircleIconButton(this.icon, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 20)),
      ),
    ),
  );
}

/// Cal AI-style empty state: soft icon badge, bold title, gray subtitle, optional black pill action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 120),
      child: FadeSlideIn(
        index: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: RF.shadow),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: RF.accentSoft, shape: BoxShape.circle),
                  child: Icon(icon, size: 30, color: RF.accent),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: RF.muted, fontWeight: FontWeight.w500, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              Pressable(
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28)),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ---------- Map-first (Glide-style) building blocks ----------

/// Round white floating map button (back / menu / locate).
class MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  const MapButton(this.icon, {super.key, this.onTap, this.label});
  @override
  Widget build(BuildContext context) => Pressable(
    child: Material(
      color: Colors.white,
      elevation: 0,
      shape: const StadiumBorder(),
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 46,
          constraints: const BoxConstraints(minWidth: 46),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), boxShadow: RF.shadow),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: label == null ? RF.ink : RF.accent),
              if (label != null) ...[const SizedBox(width: 6), Text(label!, style: const TextStyle(fontWeight: FontWeight.w700))],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Full-bleed map with a draggable white bottom sheet (grabber + 26px top radius).
class MapSheetScaffold extends StatelessWidget {
  final Widget map;
  final List<Widget> Function(ScrollController) sheet;
  final double initial, min, max;
  final Widget? topLeft, topRight, bottomBar;
  const MapSheetScaffold({
    super.key,
    required this.map,
    required this.sheet,
    this.initial = .5,
    this.min = .3,
    this.max = .92,
    this.topLeft,
    this.topRight,
    this.bottomBar,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    bottomNavigationBar: bottomBar,
    body: Stack(
      children: [
        Positioned.fill(child: RepaintBoundary(child: map)),
        DraggableScrollableSheet(
          initialChildSize: initial,
          minChildSize: min,
          maxChildSize: max,
          snap: true,
          snapSizes: [initial],
          builder: (context, sc) => DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(RF.sheetRadius)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, -4))],
            ),
            child: ListView(
              controller: sc,
              padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset(context, bottomBar == null ? 32 : 16)),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(color: RF.line, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                ...sheet(sc),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [?topLeft, const Spacer(), ?topRight]),
          ),
        ),
      ],
    ),
  );
}

/// Light gray rounded box (Glide's inputs / fare box).
class InfoBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const InfoBox({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(color: RF.fill, borderRadius: BorderRadius.circular(RF.radius)),
    child: child,
  );
}

/// Small uppercase gray label ("ESTIMATED TOTAL").
class CapsLabel extends StatelessWidget {
  final String text;
  const CapsLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: RF.muted),
  );
}

/// Pickup → drop-off box with hollow/filled dots and a divider (Glide route box).
class RouteBox extends StatelessWidget {
  final String from, to;
  final Widget? toField;
  const RouteBox({super.key, required this.from, required this.to, this.toField});
  Widget _dot(bool filled) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? RF.ink : Colors.white,
      border: Border.all(color: RF.ink, width: 2),
    ),
  );
  @override
  Widget build(BuildContext context) => InfoBox(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Column(
      children: [
        Row(
          children: [
            _dot(false),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const Divider(height: 1, indent: 23),
        Row(
          children: [
            _dot(true),
            const SizedBox(width: 14),
            Expanded(
              child:
                  toField ??
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      to,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// "Saved place" style row: round gray icon, bold title, gray subtitle, chevron.
class PlaceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const PlaceRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
    enabled: onTap != null,
    scale: .98,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: RF.fill, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: RF.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(color: RF.muted, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: RF.muted),
          ],
        ),
      ),
    ),
  );
}

/// Selectable option tile (Glide ride-tier row): black 2px outline when selected.
class OptionTile extends StatelessWidget {
  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  const OptionTile({super.key, required this.selected, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Pressable(
      enabled: onTap != null,
      scale: .98,
      child: AnimatedContainer(
        duration: Motion.d(context, Motion.fast),
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(RF.radius),
          border: Border.all(color: selected ? RF.ink : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RF.radius),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: child),
        ),
      ),
    ),
  );
}

/// Label ↔ value row for fare breakdowns.
class KeyValueRow extends StatelessWidget {
  final String k, v;
  final bool bold;
  const KeyValueRow(this.k, this.v, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(color: bold ? RF.ink : RF.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
          ),
        ),
        Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
      ],
    ),
  );
}

/// Vertical order-status steps with a filled progress line.
class StatusSteps extends StatelessWidget {
  final String status;
  const StatusSteps(this.status, {super.key});
  static const _steps = [
    ('pending', 'Order placed', 'Waiting for the station'),
    ('accepted', 'Accepted', 'The station confirmed your order'),
    ('preparing', 'Preparing', 'Filling your containers'),
    ('out_for_delivery', 'On the way', 'Your rider is heading to you'),
    ('delivered', 'Delivered', 'Enjoy your water!'),
  ];
  @override
  Widget build(BuildContext context) {
    final cur = _steps.indexWhere((s) => s.$1 == status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: Motion.d(context, Motion.medium),
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= cur ? RF.ink : Colors.white,
                          border: Border.all(color: i <= cur ? RF.ink : RF.line, width: 2),
                        ),
                        child: i < cur ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: AnimatedContainer(duration: Motion.d(context, Motion.medium), width: 2, color: i < cur ? RF.ink : RF.line),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].$2,
                            style: TextStyle(fontWeight: FontWeight.w700, color: i <= cur ? RF.ink : RF.muted),
                          ),
                          if (i == cur) Text(_steps[i].$3, style: const TextStyle(color: RF.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Driver card: avatar, name, plate-style subline, call button.
class RiderCard extends StatelessWidget {
  final String name;
  final String? phone;
  final String? eta;
  final VoidCallback? onCall;
  const RiderCard({super.key, required this.name, this.phone, this.eta, this.onCall});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: InfoBox(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: RF.ink,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text([?eta, ?phone].join(' · '), style: const TextStyle(color: RF.muted, fontSize: 13)),
              ],
            ),
          ),
          if (onCall != null)
            Pressable(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(onPressed: onCall, icon: const Icon(Icons.call_rounded)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Rough ETA from straight-line distance at ~20 km/h city speed.
String? etaText(LatLng? from, LatLng? to) {
  if (from == null || to == null) return null;
  final km = const Distance().as(LengthUnit.Meter, from, to) / 1000;
  final min = (km / 20 * 60).ceil().clamp(1, 180);
  return '$min min away';
}

/// Black dot marker (Glide style) for drop-off / generic points.
Marker dot(LatLng p, {Color color = RF.ink, double size = 22}) => Marker(
  point: p,
  width: size,
  height: size,
  child: Container(
    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: RF.shadow),
    padding: EdgeInsets.all(size * .22),
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  ),
);

/// Moves the camera target south so the point sits above a half-height bottom sheet.
LatLng shiftUp(LatLng p, [double zoom = 14]) => LatLng(p.latitude - 0.9 / (1 << zoom.round()) * 9, p.longitude);

/// Camera fit that keeps all points visible above a half-height bottom sheet.
CameraFit? fitAboveSheet(List<LatLng> pts) =>
    pts.length < 2 ? null : CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(70, 110, 70, 470), maxZoom: 16);

// ---------- Forms ----------

/// Bottom space that clears the home indicator / mobile Safari toolbar.
double bottomInset(BuildContext context, [double extra = 24]) => MediaQuery.viewPaddingOf(context).bottom + extra;

/// Titled form section with 12px gaps between children.
class FormSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const FormSection({super.key, required this.title, this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!, style: const TextStyle(color: RF.muted, fontSize: 13)),
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
      ],
    ),
  );
}

/// Labelled filled field with a prefix icon.
class LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint, prefixText;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final int maxLines;
  const LabeledField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.prefixText,
    this.keyboard,
    this.onChanged,
    this.obscure = false,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RF.muted),
        ),
      ),
      TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixText == null
              ? Icon(icon, size: 20, color: RF.muted)
              : Padding(
                  padding: const EdgeInsets.only(left: 12, right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: RF.muted),
                      const SizedBox(width: 8),
                      Text(prefixText!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
        ),
      ),
    ],
  );
}

/// Sticky white bottom bar holding the primary action, with safe-area inset.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: RF.line)),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset(context, 14)),
      child: Pressable(child: child),
    ),
  );
}

/// Black primary button with a spinner while [busy].
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: Motion.d(context, Motion.fast),
        child: busy
            ? const SizedBox(
                key: ValueKey('b'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label, key: const ValueKey('l')),
      ),
    ),
  );
}

/// Dashed outline painter for upload cards.
class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(RF.radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in (ui.Path()..addRRect(rr)).computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder o) => o.color != color;
}

/// Upload card: dashed when empty; shows thumbnail/filename, check, replace & remove once picked.
class UploadCard extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  final String? fileName;
  final Uint8List? thumb;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  const UploadCard({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.fileName,
    this.thumb,
    required this.onPick,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;
    final body = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              color: picked ? RF.accentSoft : Colors.white,
              child: thumb != null
                  ? Image.memory(thumb!, fit: BoxFit.cover)
                  : Icon(picked ? Icons.description_rounded : icon, color: RF.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  picked ? fileName! : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: RF.muted, fontSize: 13),
                ),
                if (picked)
                  Row(
                    children: [
                      TextButton(
                        onPressed: onPick,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), foregroundColor: RF.accent),
                        child: const Text('Replace'),
                      ),
                      const SizedBox(width: 14),
                      TextButton(
                        onPressed: onRemove,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          foregroundColor: Colors.redAccent,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: Motion.d(context, Motion.fast),
            child: picked
                ? const CircleAvatar(
                    key: ValueKey('ok'),
                    radius: 13,
                    backgroundColor: Color(0xFF1DB954),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  )
                : const Icon(Icons.upload_rounded, key: ValueKey('up'), color: RF.ink),
          ),
        ],
      ),
    );
    return Pressable(
      enabled: !picked,
      scale: .98,
      child: Material(
        color: picked ? Colors.white : RF.fill,
        borderRadius: BorderRadius.circular(RF.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(RF.radius),
          onTap: picked ? null : onPick,
          child: picked
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RF.radius),
                    border: Border.all(color: RF.line),
                  ),
                  child: body,
                )
              : CustomPaint(painter: _DashedBorder(const Color(0xFFB9B9C0)), child: body),
        ),
      ),
    );
  }
}
