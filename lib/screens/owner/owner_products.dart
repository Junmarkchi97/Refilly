import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';
import '../network_states.dart';

class OwnerProducts extends StatefulWidget {
  final Station station;
  const OwnerProducts({super.key, required this.station});
  @override
  State<OwnerProducts> createState() => _OwnerProductsState();
}

class _OwnerProductsState extends State<OwnerProducts> {
  late Future<List<Product>> _f = Api.products(widget.station.id, onlyAvailable: false).timeout(const Duration(seconds: 20));
  final Future<List<Category>> _cats = Api.categories();
  final _busy = <String>{};

  void _reload() => setState(() => _f = Api.products(widget.station.id, onlyAvailable: false).timeout(const Duration(seconds: 20)));

  Future<void> _edit([Product? p]) async {
    late final List<Category> cats;
    try {
      cats = await _cats;
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: 'Could not load product categories.');
      return;
    }
    if (!mounted) return;
    final name = TextEditingController(text: p?.name);
    final unit = TextEditingController(text: p?.unit ?? 'gallon');
    final price = TextEditingController(text: p?.price.toStringAsFixed(2));
    String? cat = cats.any((c) => c.id == p?.categoryId) ? p?.categoryId : cats.firstOrNull?.id;
    String? imageUrl = p?.imageUrl;
    Uint8List? newBytes;
    String newExt = 'jpg';
    Future<void> pick(void Function(void Function()) setD) async {
      final f = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'])).firstOrNull;
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) showAppNotice(context, 'Image must be under 5 MB');
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
                if (cats.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: (v) => setD(() => cat = v),
                  ),
                  const SizedBox(height: 12),
                ],
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
            FilledButton(onPressed: () {
              final amount = double.tryParse(price.text.trim());
              if (name.text.trim().isEmpty || unit.text.trim().isEmpty || amount == null || !amount.isFinite || amount <= 0) {
                showAppNotice(ctx, 'Add a name, unit, and valid price above ₱0.');
                return;
              }
              Navigator.pop(ctx, true);
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final validPrice = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || unit.text.trim().isEmpty || validPrice == null || !validPrice.isFinite || validPrice <= 0) {
      if (mounted) showAppNotice(context, 'Enter a product name, unit, and a valid price greater than zero.');
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
      if (mounted) showFailureNotice(context, e, failed: 'Could not upload the photo.');
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
        await sb.from('products').update(data).eq('id', p.id).eq('station_id', widget.station.id);
      }
      if (p?.imageUrl != null && p!.imageUrl != imageUrl) await Api.deleteProductImage(p.imageUrl!);
      if (mounted) {
        _reload();
        showAppNotice(context, p == null ? 'Product added' : 'Product updated', kind: AppNotice.success);
      }
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: 'Could not save this product.');
    }
  }

  Future<void> _setAvailable(Product p, bool available) async {
    if (_busy.contains(p.id)) return;
    setState(() => _busy.add(p.id));
    try {
      await sb.from('products').update({'is_available': available}).eq('id', p.id).eq('station_id', widget.station.id);
      _reload();
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: 'Could not update availability.');
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _remove(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => RemoveProductDialog(name: p.name),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(p.id));
    try {
      await sb.from('products').delete().eq('id', p.id).eq('station_id', widget.station.id);
      if (p.imageUrl != null) await Api.deleteProductImage(p.imageUrl!);
      if (mounted) {
        _reload();
        showAppNotice(context, 'Product removed', kind: AppNotice.success);
      }
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: 'Could not remove this product.');
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _f,
            builder: (context, snap) => StateSwitcher(
              child: KeyedSubtree(
                key: ValueKey(snap.hasData),
                child: Builder(
                  builder: (context) {
                    if (snap.hasError) return LoadFailureView(error: snap.error!, onRetry: _reload);
                    if (!snap.hasData) return const Column(children: [SlowLoadingHint(), Expanded(child: SkeletonList())]);
                    if (snap.data!.isEmpty) {
                      return const EmptyState(
                        icon: Icons.inventory_2_rounded,
                        title: 'No products yet',
                        subtitle: 'Add your water refills, containers and essentials so customers can order.',
                      );
                    }
                    return ListView(
                      padding: EdgeInsets.only(bottom: bottomInset(context, 120)),
                      children: [
                        for (final (pIdx, p) in (snap.data!).indexed)
                          FadeSlideIn(
                            index: pIdx,
                            child: OwnerProductCard(
                              product: p,
                              busy: _busy.contains(p.id),
                              onEdit: () => _edit(p),
                              onRemove: () => _remove(p),
                              onAvailable: (v) => _setAvailable(p, v),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class OwnerProductCard extends StatelessWidget {
  final Product product;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final ValueChanged<bool> onAvailable;
  const OwnerProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onRemove,
    required this.onAvailable,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
    child: Column(
      children: [
        Row(
          children: [
            ProductThumb(product.imageUrl, size: 56, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${peso(product.price)} / ${product.unit}', style: const TextStyle(color: RF.muted)),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFD14343)),
            ),
            const Spacer(),
            Semantics(
              label: product.isAvailable ? 'Available for customers' : 'Hidden from customers',
              child: Switch(
                value: product.isAvailable,
                onChanged: busy ? null : onAvailable,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class RemoveProductDialog extends StatelessWidget {
  final String name;
  const RemoveProductDialog({super.key, required this.name});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Remove product?'),
    content: Text('$name will leave your menu. Past orders keep this item.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD14343)),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Remove'),
      ),
    ],
  );
}
