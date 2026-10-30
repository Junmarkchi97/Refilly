import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'checkout_screen.dart';

class StationScreen extends StatefulWidget {
  final Station station;
  final Profile profile;
  const StationScreen({super.key, required this.station, required this.profile});
  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  late final Future<(List<Product>, List<Category>)> _f = _load();

  Future<(List<Product>, List<Category>)> _load() async => (await Api.products(widget.station.id), await Api.categories());
  final Map<Product, int> _cart = {};
  String? _cat;

  double get _total => _cart.entries.fold(0, (t, e) => t + e.key.price * e.value);

  Widget _qtyBtn(IconData i, VoidCallback? onTap, {bool dark = false}) => Pressable(
    scale: .88,
    child: Material(
      color: dark ? RF.ink : RF.bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(i, size: 18, color: dark ? Colors.white : RF.ink),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: FutureBuilder(
      future: _f,
      builder: (context, snap) => StateSwitcher(
        child: KeyedSubtree(
          key: ValueKey(snap.hasData),
          child: Builder(
            builder: (context) {
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              if (!snap.hasData) return const SkeletonList(count: 4);
              final (products, cats) = snap.data!;
              final usedCats = cats.where((c) => products.any((p) => p.categoryId == c.id)).toList();
              final shown = _cat == null ? products : products.where((p) => p.categoryId == _cat).toList();
              final st = widget.station;
              return ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  PageHeader(st.name, subtitle: st.address, trailing: StatusPill(st.isOpen ? 'open' : 'closed')),
                  if (st.description?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(st.description!, style: const TextStyle(color: RF.muted)),
                    ),
                  if (products.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: ChoiceChip(
                              label: const Text('All'),
                              selected: _cat == null,
                              onSelected: (_) => setState(() => _cat = null),
                            ),
                          ),
                          for (final c in usedCats)
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: ChoiceChip(
                                label: Text(c.name),
                                selected: _cat == c.id,
                                onSelected: (_) => setState(() => _cat = c.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (products.isEmpty)
                    const EmptyState(
                      icon: Icons.inventory_2_rounded,
                      title: 'No products yet',
                      subtitle: "This station hasn't added items.\nCheck back soon.",
                    )
                  else if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Nothing in this category',
                      subtitle: 'Try another category or see everything.',
                      actionLabel: 'Show all',
                      onAction: () => setState(() => _cat = null),
                    ),
                  for (final (i, p) in shown.indexed)
                    FadeSlideIn(
                      index: i,
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(color: RF.accentSoft, borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.water_drop_rounded, color: RF.accent, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: peso(p.price),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        TextSpan(
                                          text: ' / ${p.unit}',
                                          style: const TextStyle(color: RF.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedSize(
                              duration: Motion.d(context, Motion.medium),
                              curve: Motion.curve,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((_cart[p] ?? 0) > 0) ...[
                                    _qtyBtn(
                                      Icons.remove_rounded,
                                      () => setState(() {
                                        _cart[p] = _cart[p]! - 1;
                                        if (_cart[p] == 0) _cart.remove(p);
                                      }),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${_cart[p]}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _qtyBtn(Icons.add_rounded, () => setState(() => _cart[p] = (_cart[p] ?? 0) + 1), dark: true),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
    bottomNavigationBar: AnimatedSlide(
      offset: _cart.isEmpty ? const Offset(0, 1.4) : Offset.zero,
      duration: Motion.d(context, Motion.slow),
      curve: Motion.spring,
      child: AnimatedOpacity(
        opacity: _cart.isEmpty ? 0 : 1,
        duration: Motion.d(context, Motion.fast),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Pressable(
            child: FilledButton(
              onPressed: widget.station.isOpen && _cart.isNotEmpty
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(station: widget.station, cart: _cart, profile: widget.profile),
                      ),
                    )
                  : null,
              child: widget.station.isOpen
                  ? AnimatedCount(value: _total, format: (v) => 'Checkout · ${_cart.values.fold(0, (a, b) => a + b)} items · ${peso(v)}')
                  : const Text('Station closed'),
            ),
          ),
        ),
      ),
    ),
  );
}
