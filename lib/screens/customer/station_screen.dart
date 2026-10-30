import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
            const SizedBox(height: 10),
            if (snap.hasError) const Padding(padding: EdgeInsets.all(20), child: Text('Could not load products. Reopen the station to retry.')),
            if (data == null && !snap.hasError) const SizedBox(height: 320, child: SkeletonList(count: 4, height: 70)),
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
