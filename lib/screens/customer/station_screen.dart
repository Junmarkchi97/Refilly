import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'checkout_screen.dart';
import '../network_states.dart';

/// Products sold with a new container rather than as a refill of the customer's own.
bool isNewContainerProduct(Product p) =>
    RegExp(r'container|\bnew\b', caseSensitive: false).hasMatch('${p.name} ${p.description ?? ''}');

/// "Purified Water Refill (5 gal)" → ("Purified Water Refill", "5 gal").
(String, String?) splitProductName(String name) {
  final m = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*$').firstMatch(name);
  return m == null ? (name, null) : (m.group(1)!, m.group(2));
}

class StationScreen extends StatefulWidget {
  final Station station;
  final Profile profile;
  final Map<String, int> initialQuantities;
  final String? refillRoutineId;
  final String? initialCategorySlug;
  const StationScreen({
    super.key,
    required this.station,
    required this.profile,
    this.initialQuantities = const {},
    this.refillRoutineId,
    this.initialCategorySlug,
  });
  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  late Future<(List<Product>, List<Category>)> _f = _load().timeout(const Duration(seconds: 20));
  late final Future<List<Map<String, dynamic>>> _reviews = Api.stationReviews(widget.station.id);
  final Map<Product, int> _cart = {};
  bool _restoredCart = false;
  String? _cat;
  Product? _selected;
  bool _newContainer = false;

  Future<(List<Product>, List<Category>)> _load() async {
    final products = await Api.products(widget.station.id);
    final categories = await Api.categories();
    if (widget.initialQuantities.isNotEmpty && !_restoredCart) {
      _restoredCart = true;
      for (final p in products) {
        final qty = widget.initialQuantities[p.id];
        if (qty != null && qty > 0) _cart[p] = qty;
      }
      _selected = _cart.keys.firstOrNull;
    }
    final water = products.where((p) => !isRiceProduct(p.name, unit: p.unit));
    final start = _selected ?? water.firstOrNull;
    if (start != null && !isRiceProduct(start.name, unit: start.unit)) {
      _newContainer = water.every(isNewContainerProduct) || (_selected != null && isNewContainerProduct(_selected!));
    }
    final slug = widget.initialCategorySlug;
    if (slug != null && _cat == null) {
      _cat = categories.where((c) => c.slug == slug).firstOrNull?.id;
    }
    return (products, categories);
  }

  void _retry() => setState(() => _f = _load().timeout(const Duration(seconds: 20)));

  double get _total => _cart.entries.fold(0, (t, e) => t + e.key.price * e.value);
  int get _count => _cart.values.fold(0, (a, b) => a + b);

  void _select(Product p) => setState(() {
    _selected = p;
    _cart[p] = (_cart[p] ?? 0) == 0 ? 1 : _cart[p]!;
  });

  void _setQty(Product p, int qty) => setState(() {
    _selected = p;
    if (qty <= 0) {
      _cart.remove(p);
    } else {
      _cart[p] = qty;
    }
  });

  void _checkout() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CheckoutScreen(
        station: widget.station,
        cart: _cart,
        profile: widget.profile,
        refillRoutineId: widget.refillRoutineId,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final st = widget.station;
    return FutureBuilder(
      future: _f,
      builder: (context, snap) {
        final data = snap.data;
        final products = data?.$1 ?? const <Product>[];
        final cats = data?.$2 ?? const <Category>[];
        final usedCats = cats.where((c) => products.any((p) => p.categoryId == c.id)).toList();
        final inCategory = _cat == null ? products : products.where((p) => p.categoryId == _cat).toList();
        final water = inCategory.where((p) => !isRiceProduct(p.name, unit: p.unit)).toList();
        final hasBothModes = water.any(isNewContainerProduct) && water.any((p) => !isNewContainerProduct(p));
        final showModes = water.isNotEmpty;
        final shown = inCategory
            .where((p) => isRiceProduct(p.name, unit: p.unit) || !showModes || isNewContainerProduct(p) == _newContainer)
            .toList();
        final riceOnly = inCategory.isNotEmpty && water.isEmpty;
        final selected = (_selected != null && shown.contains(_selected)) ? _selected : (shown.where(_cart.containsKey).firstOrNull ?? shown.firstOrNull);

        return Scaffold(
          body: Ambient(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      children: [
                        FloatIconButton(Icons.arrow_back_ios_new_rounded, tooltip: 'Back', onTap: () => Navigator.maybePop(context)),
                        const Spacer(),
                        if (!st.isOpen) const Tag('Closed', background: Colors.white, foreground: RF.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  ProductOrb(
                    name: selected?.name ?? (riceOnly ? 'Rice' : 'Purified water'),
                    unit: selected?.unit,
                    imageUrl: selected?.imageUrl,
                    size: 124,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(RF.sheetRadius)),
                        boxShadow: [BoxShadow(color: const Color(0xFF32220F).withValues(alpha: .05), blurRadius: 30, offset: const Offset(0, -10))],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                              children: [
                                Text(
                                  riceOnly ? 'Choose your rice' : 'Choose a refill',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 2),
                                _stationLine(st),
                                const SizedBox(height: 12),
                                if (usedCats.length > 1) ...[
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(label: const Text('All'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                                        ),
                                        for (final c in usedCats)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(label: Text(c.name), selected: _cat == c.id, onSelected: (_) => setState(() => _cat = c.id)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (showModes) ...[
                                  PillToggle(
                                    options: const ['Refill only', 'With new container'],
                                    index: _newContainer ? 1 : 0,
                                    onChanged: (i) => setState(() => _newContainer = i == 1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                                    child: Text(
                                      _newContainer
                                          ? 'You keep a new container. The price includes the container and the water.'
                                          : 'You hand over your own empty container. The price is for the water only.',
                                      style: const TextStyle(color: Color(0xFF3F3B37), fontSize: 13, height: 1.35),
                                    ),
                                  ),
                                ] else if (riceOnly)
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(2, 0, 2, 10),
                                    child: Text(
                                      'Sealed whole sacks. Choose the size and how many.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF3F3B37), fontSize: 13),
                                    ),
                                  ),
                                if (snap.hasError) LoadFailureView(compact: true, error: snap.error!, onRetry: _retry),
                                if (data == null && !snap.hasError) const SizedBox(height: 260, child: SkeletonList(count: 3, height: 80)),
                                if (data != null && products.isEmpty)
                                  const EmptyState(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'No products yet',
                                    subtitle: "This supplier hasn't added items.\nCheck back soon.",
                                  )
                                else if (data != null && shown.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Text(
                                      showModes && !hasBothModes
                                          ? (_newContainer
                                              ? 'This supplier only offers refills of your own container.'
                                              : 'This supplier only sells water with a new container.')
                                          : 'Nothing in this category yet.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: RF.muted),
                                    ),
                                  ),
                                for (final (i, p) in shown.indexed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: FadeSlideIn(index: i, child: _productCard(p, p == selected)),
                                  ),
                              ],
                            ),
                          ),
                          _dock(st, selected),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stationLine(Station st) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _reviews,
    builder: (context, snap) {
      final reviews = snap.data ?? const [];
      final avg = reviews.isEmpty
          ? null
          : reviews.fold<double>(0, (t, r) => t + ((r['rating'] as num?)?.toDouble() ?? 0)) / reviews.length;
      return Text(
        [
          st.name,
          st.isOpen ? 'Open' : 'Closed',
          if (avg != null) '★ ${avg.toStringAsFixed(1)}',
          'Delivery ${st.deliveryFee == 0 ? 'free' : peso(st.deliveryFee)}',
        ].join(' · '),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: RF.muted, fontSize: 13),
      );
    },
  );

  Widget _productCard(Product p, bool selected) {
    final (title, size) = splitProductName(p.name);
    final qty = _cart[p] ?? 0;
    final usual = widget.initialQuantities.containsKey(p.id);
    return SelectCard(
      selected: selected,
      onTap: () => _select(p),
      child: Row(
        children: [
          ProductArt(name: p.name, unit: p.unit, imageUrl: p.imageUrl, size: 72),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -.2)),
                const SizedBox(height: 2),
                Text(size ?? 'per ${p.unit}', style: const TextStyle(color: RF.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  p.isAvailable ? 'Available today' : 'Unavailable',
                  style: TextStyle(color: p.isAvailable ? RF.good : RF.muted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (usual) ...[const Tag('Usual'), const SizedBox(height: 4)],
              Text(peso(p.price).replaceAll('.00', ''), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -.4)),
              Text(
                qty > 0 ? 'In cart × $qty' : isRiceProduct(p.name, unit: p.unit) ? 'Whole sack' : isNewContainerProduct(p) ? 'Incl. container' : 'Water only',
                style: TextStyle(color: qty > 0 ? RF.accentInk : RF.muted, fontSize: 12, fontWeight: qty > 0 ? FontWeight.w700 : FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dock(Station st, Product? selected) {
    final qty = selected == null ? 0 : (_cart[selected] ?? 0);
    final others = _count - qty;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomInset(context, 14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          '$qty × ${peso(selected.price).replaceAll('.00', '')}${others > 0 ? ' · $others other item${others == 1 ? '' : 's'} in cart' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: RF.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  QtyStepper(value: qty, max: 50, label: selected.name, onChanged: (v) => _setQty(selected, v)),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Pressable(
              enabled: st.isOpen && _cart.isNotEmpty,
              child: FilledButton(
                onPressed: st.isOpen && _cart.isNotEmpty ? _checkout : null,
                child: !st.isOpen
                    ? const Text('Supplier closed')
                    : _cart.isEmpty
                        ? const Text('Choose a quantity')
                        : AnimatedCount(value: _total, format: (v) => 'Add to cart · ${peso(v)}'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('The delivery fee is shown before you place the order.', style: TextStyle(color: RF.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
