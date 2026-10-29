import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.station.name)),
        body: FutureBuilder(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (products, cats) = snap.data!;
            final usedCats = cats.where((c) => products.any((p) => p.categoryId == c.id)).toList();
            final shown = _cat == null ? products : products.where((p) => p.categoryId == _cat).toList();
            return Column(children: [
              if (widget.station.description != null)
                Padding(padding: const EdgeInsets.all(12), child: Text(widget.station.description!)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('All'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null))),
                  for (final c in usedCats)
                    Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(c.name), selected: _cat == c.id, onSelected: (_) => setState(() => _cat = c.id))),
                ]),
              ),
              Expanded(
                child: ListView(children: [
                  for (final p in shown)
                    ListTile(
                      title: Text(p.name),
                      subtitle: Text('${peso(p.price)} / ${p.unit}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: (_cart[p] ?? 0) == 0
                                ? null
                                : () => setState(() {
                                      _cart[p] = _cart[p]! - 1;
                                      if (_cart[p] == 0) _cart.remove(p);
                                    })),
                        Text('${_cart[p] ?? 0}'),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _cart[p] = (_cart[p] ?? 0) + 1)),
                      ]),
                    ),
                ]),
              ),
            ]);
          },
        ),
        bottomNavigationBar: _cart.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: widget.station.isOpen
                        ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(station: widget.station, cart: _cart, profile: widget.profile)))
                        : null,
                    child: Text(widget.station.isOpen ? 'Checkout · ${peso(_total)}' : 'Station closed'),
                  ),
                ),
              ),
      );
}
