import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

/// Sky-blue surface with a soft peach corner and a cooler blue wash opposite.
class Ambient extends StatelessWidget {
  final Widget child;
  const Ambient({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: RF.bg),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-1.05, -1.05),
          radius: 1.05,
          colors: [Color(0x73FFC2A8), Color(0x00FFC2A8)],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1.1, -.9),
            radius: 1.15,
            colors: [Color(0xB37EC8FF), Color(0x007EC8FF)],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.2, 1.1),
              radius: 1.1,
              colors: [Color(0x80C5E4FF), Color(0x00C5E4FF)],
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Bundled product cutout chosen from the product name and unit.
String productAsset(String name, {String? unit}) {
  final n = name.toLowerCase();
  final u = (unit ?? '').toLowerCase();
  if (n.contains('rice') || n.contains('bigas') || u == 'kg' || u == 'sack') {
    final kg = double.tryParse(RegExp(r'(\d+(?:\.\d+)?)\s*kg').firstMatch(n)?.group(1) ?? '');
    if (kg != null && kg <= 5) return 'assets/products/rice-5.jpg';
    if (kg != null && kg > 10) return 'assets/products/rice-25.jpg';
    return 'assets/products/rice-10.jpg';
  }
  if (n.contains('slim')) return 'assets/products/jug-slim.jpg';
  if (n.contains('alkaline')) return 'assets/products/jug-alkaline.jpg';
  return 'assets/products/jug-round.jpg';
}

bool isRiceProduct(String name, {String? unit}) => productAsset(name, unit: unit).contains('/rice-');

/// Product cutout on white: the owner's own photo when present, otherwise a bundled cutout.
class ProductArt extends StatelessWidget {
  final String name;
  final String? unit, imageUrl;
  final double size;
  final double radius;
  const ProductArt({super.key, required this.name, this.unit, this.imageUrl, this.size = 64, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final useAsset = url == null || url.isEmpty || url.contains('/defaults/');
    final asset = Image.asset(
      productAsset(name, unit: unit),
      width: size * 1.15,
      height: size * 1.15,
      fit: BoxFit.contain,
      cacheWidth: (size * 1.15 * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        alignment: Alignment.center,
        child: useAsset
            ? OverflowBox(maxWidth: size * 1.15, maxHeight: size * 1.15, child: asset)
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, _, _) => OverflowBox(maxWidth: size * 1.15, maxHeight: size * 1.15, child: asset),
              ),
      ),
    );
  }
}

/// Large circular product cutout with a soft grounding shadow.
class ProductOrb extends StatelessWidget {
  final String name;
  final String? unit, imageUrl;
  final double size;
  const ProductOrb({super.key, required this.name, this.unit, this.imageUrl, this.size = 132});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size + 10,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          bottom: 0,
          left: size * .15,
          right: size * .15,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: const Color(0xFF1A4B7A).withValues(alpha: .16), blurRadius: 12)],
            ),
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: RF.shadow),
          child: ClipOval(
            child: AnimatedSwitcher(
              duration: Motion.d(context, Motion.medium),
              child: ProductArt(
                key: ValueKey('$name$imageUrl'),
                name: name,
                unit: unit,
                imageUrl: imageUrl,
                size: size * .82,
                radius: 0,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// White rounded surface with a delicate shadow and no border.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding, margin;
  final double radius;
  final VoidCallback? onTap;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = RF.cardRadius,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Pressable(
      enabled: onTap != null,
      scale: onTap == null ? 1 : .98,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius), boxShadow: RF.shadow),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    ),
  );
}

/// White card whose stroke turns into a peach-to-sky gradient when selected.
///
/// Stroke width stays fixed so selecting a card never shifts its contents.
class GradientFrame extends StatelessWidget {
  static const _stroke = 1.8;

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  const GradientFrame({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 14, 8),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: onTap != null,
    child: Pressable(
      enabled: onTap != null,
      scale: .98,
      child: AnimatedContainer(
        duration: Motion.d(context, Motion.fast),
        curve: Motion.curve,
        padding: const EdgeInsets.all(_stroke),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: selected ? RF.borderGradient : null,
          color: selected ? null : const Color(0x3390B8DC),
          boxShadow: selected ? RF.selectedShadow : RF.shadow,
        ),
        child: Material(
          color: selected ? RF.selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(radius - _stroke),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    ),
  );
}

/// Selectable card with a peach-to-sky gradient outline when chosen.
class SelectCard extends StatelessWidget {
  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const SelectCard({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 14, 8),
  });
  @override
  Widget build(BuildContext context) => GradientFrame(selected: selected, onTap: onTap, padding: padding, child: child);
}

/// Pill-shaped minus / count / plus control.
class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min, max;
  final String? label;
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 99, this.label});

  Widget _btn(BuildContext context, IconData icon, String tip, VoidCallback? onTap) => Pressable(
    enabled: onTap != null,
    scale: .88,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: onTap == null ? RF.line : RF.ink),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: RF.fill, borderRadius: BorderRadius.circular(100)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(context, Icons.remove_rounded, 'Fewer${label == null ? '' : ' $label'}', value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 30,
          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        _btn(context, Icons.add_rounded, 'More${label == null ? '' : ' $label'}', value < max ? () => onChanged(value + 1) : null),
      ],
    ),
  );
}

/// Small rounded tag ("Usual", "Confirmed").
class Tag extends StatelessWidget {
  final String text;
  final Color background, foreground;
  const Tag(this.text, {super.key, this.background = RF.usual, this.foreground = RF.usualInk});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(100)),
    child: Text(text, style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12)),
  );
}

/// Round grey icon used beside detail rows.
class IconBubble extends StatelessWidget {
  final IconData icon;
  const IconBubble(this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(color: RF.bg, shape: BoxShape.circle),
    child: Icon(icon, size: 19, color: RF.ink),
  );
}

/// Label + value + optional caption with a leading bubble icon.
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? caption;
  final Widget? trailing;
  const DetailRow({super.key, required this.icon, required this.label, required this.value, this.caption, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        IconBubble(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: RF.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -.2)),
              if (caption != null) Text(caption!, style: const TextStyle(color: RF.muted, fontSize: 13)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Section heading with an optional trailing text action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(action!, style: const TextStyle(color: RF.muted, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
      ],
    ),
  );
}

/// Two-option black segmented switch.
class PillToggle extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  const PillToggle({super.key, required this.options, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: const Color(0xFFEFEBE6), borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              child: GestureDetector(
                onTap: () {
                  tapHaptic();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: Motion.d(context, Motion.fast),
                  curve: Motion.curve,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? RF.button : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: i == index ? Colors.white : RF.ink),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Round white back / action button that floats over ambient backgrounds.
class FloatIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool badge;
  const FloatIconButton(this.icon, {super.key, this.onTap, this.tooltip, this.badge = false});
  @override
  Widget build(BuildContext context) {
    final button = _button();
    return Pressable(child: tooltip == null ? button : Tooltip(message: tooltip!, child: button));
  }

  Widget _button() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x3390B8DC)),
          boxShadow: [BoxShadow(color: const Color(0xFF1A4B7A).withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 21, color: RF.ink),
                if (badge)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: RF.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// Calendar-style date label: "Mon, Nov 16".
String shortDate(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

/// 12-hour clock label without minutes when on the hour: "2 PM", "2:30 PM".
String clockLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
  return '$h$m ${d.hour < 12 ? 'AM' : 'PM'}';
}
