import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../theme.dart';

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
    String? imageUrl = p?.imageUrl;
    Uint8List? newBytes;
    String newExt = 'jpg';
    Future<void> pick(void Function(void Function()) setD) async {
      final f = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'])).firstOrNull;
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be under 5 MB')));
        return;
      }
      setD(() {
        newBytes = bytes;
        newExt = f.name.split('.').last.toLowerCase();
      });
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(p == null ? 'New product' : 'Edit product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: newBytes != null
                          ? Image.memory(newBytes!, width: 84, height: 84, fit: BoxFit.cover)
                          : ProductThumb(imageUrl, size: 84, radius: 16),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => pick(setD),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: Text(newBytes != null || imageUrl != null ? 'Replace photo' : 'Add photo'),
                          ),
                          if (newBytes != null || imageUrl != null)
                            TextButton(
                              onPressed: () => setD(() {
                                newBytes = null;
                                imageUrl = null;
                              }),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              child: const Text('Remove photo'),
                            ),
                          const Text('JPG, PNG or WebP · up to 5 MB', style: TextStyle(color: RF.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setD(() => cat = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'Unit (gallon, kg, tank...)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Price (₱)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final validPrice = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || unit.text.trim().isEmpty || validPrice == null || !validPrice.isFinite || validPrice <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a product name, unit, and a valid price greater than zero.')));
      return;
    }
    try {
      if (newBytes != null) {
        final mime = switch (newExt) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        imageUrl = await Api.uploadProductImage(widget.station.id, newBytes!, newExt == 'jpeg' ? 'jpg' : newExt, mime);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
      return;
    }
    final data = {
      'image_url': imageUrl,
      'station_id': widget.station.id,
      'category_id': cat,
      'name': name.text.trim(),
      'unit': unit.text.trim(),
      'price': validPrice,
    };
    try {
      if (p == null) {
        await sb.from('products').insert(data);
      } else {
        await sb.from('products').update(data).eq('id', p.id);
      }
      if (p?.imageUrl != null && p!.imageUrl != imageUrl) await Api.deleteProductImage(p.imageUrl!);
      if (mounted) _reload();
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
              if (snap.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Could not load products'), const SizedBox(height: 12), FilledButton(onPressed: _reload, child: const Text('Retry'))]));
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
                padding: EdgeInsets.only(bottom: bottomInset(context, 140)),
                children: [
                  for (final (pIdx, p) in (snap.data!).indexed)
                    FadeSlideIn(
                      index: pIdx,
                      child: ListTile(
                        leading: ProductThumb(p.imageUrl, size: 52, radius: 12),
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
