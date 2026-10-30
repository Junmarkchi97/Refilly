import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';

class OwnerProducts extends StatefulWidget {
  final Station station;
  const OwnerProducts({super.key, required this.station});
  @override
  State<OwnerProducts> createState() => _OwnerProductsState();
}

class _OwnerProductsState extends State<OwnerProducts> {
  late Future<List<Product>> _f = Api.products(widget.station.id, onlyAvailable: false);
  final Future<List<Category>> _cats = Api.categories();

  void _reload() => setState(() => _f = Api.products(widget.station.id, onlyAvailable: false));

  Future<void> _edit([Product? p]) async {
    final cats = await _cats;
    if (!mounted) return;
    final name = TextEditingController(text: p?.name);
    final unit = TextEditingController(text: p?.unit ?? 'gallon');
    final price = TextEditingController(text: p?.price.toStringAsFixed(2));
    String? cat = p?.categoryId ?? cats.firstOrNull?.id;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(p == null ? 'New product' : 'Edit product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setD(() => cat = v),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Unit (gallon, kg, tank...)'),
              ),
              TextField(
                controller: price,
                decoration: const InputDecoration(labelText: 'Price (₱)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final data = {
      'station_id': widget.station.id,
      'category_id': cat,
      'name': name.text.trim(),
      'unit': unit.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
    };
    try {
      if (p == null) {
        await sb.from('products').insert(data);
      } else {
        await sb.from('products').update(data).eq('id', p.id);
      }
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Product'),
    ),
    body: FutureBuilder<List<Product>>(
      future: _f,
      builder: (context, snap) => StateSwitcher(
        child: KeyedSubtree(
          key: ValueKey(snap.hasData),
          child: Builder(
            builder: (context) {
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              if (!snap.hasData) return const SkeletonList();
              if (snap.data!.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: 'No products yet',
                  subtitle: 'Add your water refills, containers and essentials so customers can order.',
                  actionLabel: 'Add product',
                  onAction: () => _edit(),
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  for (final (pIdx, p) in (snap.data!).indexed)
                    FadeSlideIn(
                      index: pIdx,
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text('${peso(p.price)} / ${p.unit}'),
                        onTap: () => _edit(p),
                        trailing: Switch(
                          value: p.isAvailable,
                          onChanged: (v) async {
                            await sb.from('products').update({'is_available': v}).eq('id', p.id);
                            _reload();
                          },
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
  );
}
