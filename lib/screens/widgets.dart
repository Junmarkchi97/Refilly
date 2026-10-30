import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/models.dart';
import '../theme.dart';
import '../services/api.dart';

const manila = LatLng(14.5995, 120.9842);
String peso(num v) => '₱${v.toStringAsFixed(2)}';

TileLayer osmTiles() => TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: AppConfig.userAgent);

Widget osmAttribution() => const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]);

Marker pin(LatLng p, IconData icon, Color color, {VoidCallback? onTap}) => Marker(
  point: p,
  width: 44,
  height: 44,
  child: GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: RF.shadow,
      ),
      child: Icon(icon, color: color, size: 22),
    ),
  ),
);

/// Copy or share (SMS / Messenger share sheet) a rider delivery link.
Future<void> shareRiderLink(BuildContext context, String link, String riderName) => showModalBottomSheet(
  context: context,
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
    child: Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: color ?? RF.card, borderRadius: BorderRadius.circular(RF.radius), boxShadow: RF.shadow),
        child: InkWell(
          borderRadius: BorderRadius.circular(RF.radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
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
          child: CircularProgressIndicator(value: value.clamp(0, 1), strokeWidth: stroke, color: color, strokeCap: StrokeCap.round),
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
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
    child: Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: i == index ? 16 : 10, vertical: 10),
                decoration: BoxDecoration(color: i == index ? RF.ink : Colors.transparent, borderRadius: BorderRadius.circular(100)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].$1, size: 22, color: i == index ? Colors.white : RF.muted),
                    if (i == index) ...[
                      const SizedBox(width: 6),
                      Text(
                        items[i].$2,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
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
