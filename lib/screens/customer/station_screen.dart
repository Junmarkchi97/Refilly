import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'checkout_screen.dart';
import '../network_states.dart';

class StationScreen extends StatefulWidget {
  final Station station;
  final Profile profile;
  final Map<String, int> initialQuantities;
  const StationScreen({super.key, required this.station, required this.profile, this.initialQuantities = const {}});
  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  late Future<(List<Product>, List<Category>)> _f = _load().timeout(const Duration(seconds: 20));

  Future<(List<Product>, List<Category>)> _load() async {
    final products = await Api.products(widget.station.id);
    final categories = await Api.categories();
    if (widget.initialQuantities.isNotEmpty && !_restoredCart) {
      _restoredCart = true;
      for (final p in products) {
        final qty = widget.initialQuantities[p.id];
        if (qty != null && qty > 0) _cart[p] = qty;
      }
    }
    return (products, categories);
  }

  void _retry() => setState(() => _f = _load().timeout(const Duration(seconds: 20)));
  final Map<Product, int> _cart = {};
  bool _restoredCart = false;
  late final Future<List<Map<String, dynamic>>> _reviews = Api.stationReviews(widget.station.id);
  String? _cat;

  double get _total => _cart.entries.fold(0, (t, e) => t + e.key.price * e.value);

  Widget _qtyBtn(IconData i, VoidCallback? onTap, {bool dark = false}) => Pressable(
    scale: .88,
    child: Material(
      color: dark ? RF.ink : RF.fill,
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
  Widget build(BuildContext context) {
    final st = widget.station;
    final pt = LatLng(st.lat, st.lng);
    final count = _cart.values.fold(0, (a, b) => a + b);
    return FutureBuilder(
      future: _f,
      builder: (context, snap) {
        final data = snap.data;
        final products = data?.$1 ?? const <Product>[];
        final cats = data?.$2 ?? const <Category>[];
        final usedCats = cats.where((c) => products.any((p) => p.categoryId == c.id)).toList();
        final shown = _cat == null ? products : products.where((p) => p.categoryId == _cat).toList();
        return MapSheetScaffold(
          initial: .62,
          min: .4,
          topLeft: MapButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
          map: FlutterMap(
            options: MapOptions(initialCenter: LatLng(pt.latitude - .006, pt.longitude), initialZoom: 15),
            children: [
              osmTiles(),
              MarkerLayer(markers: [photoPin(pt, st.photoUrl)]),
              osmAttribution(),
            ],
          ),
          bottomBar: AnimatedSize(
            duration: Motion.d(context, Motion.medium),
            curve: Motion.curve,
            child: _cart.isEmpty
                ? const SizedBox(width: double.infinity)
                : AnimatedSlide(
                    offset: _cart.isEmpty ? const Offset(0, 1.4) : Offset.zero,
                    duration: Motion.d(context, Motion.slow),
                    curve: Motion.spring,
                    child: AnimatedOpacity(
                      opacity: _cart.isEmpty ? 0 : 1,
                      duration: Motion.d(context, Motion.fast),
                      child: Container(
                        color: Colors.white,
                        child: SafeArea(
                          minimum: EdgeInsets.fromLTRB(16, 10, 16, bottomInset(context, 14) - MediaQuery.viewPaddingOf(context).bottom),
                          child: Pressable(
                            child: FilledButton(
                              onPressed: st.isOpen && _cart.isNotEmpty
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CheckoutScreen(station: st, cart: _cart, profile: widget.profile),
                                      ),
                                    )
                                  : null,
                              child: st.isOpen
                                  ? AnimatedCount(value: _total, format: (v) => 'Confirm $count item${count == 1 ? '' : 's'} · ${peso(v)}')
                                  : const Text('Station closed'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          sheet: (_) => [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  StationAvatar(st.photoUrl, size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: Text(st.name, style: Theme.of(context).textTheme.headlineSmall)),
                  StatusPill(st.isOpen ? 'open' : 'closed'),
                ],
              ),
            ),
            if (st.address != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                child: Text(st.address!, style: const TextStyle(color: RF.muted)),
              ),
            if (st.description?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(st.description!, style: const TextStyle(color: RF.muted)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text('Delivers within ${st.deliveryRadiusKm.toStringAsFixed(1)} km · Delivery fee ${st.deliveryFee == 0 ? 'Free' : peso(st.deliveryFee)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviews,
              builder: (context, reviewsSnap) {
                if (!reviewsSnap.hasData || reviewsSnap.data!.isEmpty) return const SizedBox.shrink();
                final reviews = reviewsSnap.data!;
                final avg = reviews.fold<double>(0, (total, item) => total + ((item['rating'] as num?)?.toDouble() ?? 0)) / reviews.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('★ ${avg.toStringAsFixed(1)} · ${reviews.length} recent reviews', style: const TextStyle(fontWeight: FontWeight.w700)),
                    for (final r in reviews.take(3)) if ((r['comment']?.toString() ?? '').trim().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text('★ ${r['rating']} — ${r['comment']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                );
              },
            ),
            const SizedBox(height: 10),
            if (snap.hasError) LoadFailureView(compact: true, error: snap.error!, onRetry: _retry),
            if (data == null && !snap.hasError) const Column(children: [SlowLoadingHint(), SkeletonList(count: 4, height: 70)]),
            if (products.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(label: const Text('All'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                    ),
                    for (final c in usedCats)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: ChoiceChip(label: Text(c.name), selected: _cat == c.id, onSelected: (_) => setState(() => _cat = c.id)),
                      ),
                  ],
                ),
              ),
            if (data != null && products.isEmpty)
              const EmptyState(
                icon: Icons.inventory_2_rounded,
                title: 'No products yet',
                subtitle: "This station hasn't added items.\nCheck back soon.",
              )
            else if (data != null && shown.isEmpty)
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
                child: OptionTile(
                  selected: (_cart[p] ?? 0) > 0,
                  onTap: () => setState(() => _cart[p] = (_cart[p] ?? 0) + 1),
                  child: Row(
                    children: [
                      ProductThumb(p.imageUrl, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('per ${p.unit}', style: const TextStyle(color: RF.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(peso(p.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 4),
                          AnimatedSize(
                            duration: Motion.d(context, Motion.medium),
                            curve: Motion.curve,
                            child: (_cart[p] ?? 0) == 0
                                ? const Text(
                                    'Add',
                                    style: TextStyle(color: RF.accent, fontWeight: FontWeight.w700, fontSize: 13),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _qtyBtn(
                                        Icons.remove_rounded,
                                        () => setState(() {
                                          _cart[p] = _cart[p]! - 1;
                                          if (_cart[p] == 0) _cart.remove(p);
                                        }),
                                      ),
                                      SizedBox(
                                        width: 26,
                                        child: Text(
                                          '${_cart[p]}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      _qtyBtn(Icons.add_rounded, () => setState(() => _cart[p] = (_cart[p] ?? 0) + 1), dark: true),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
