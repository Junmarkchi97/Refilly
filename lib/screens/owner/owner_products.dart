import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/picked_image.dart';
import '../widgets.dart';
import '../network_states.dart';

class OwnerProducts extends StatefulWidget {
  final Station station;
  final void Function(VoidCallback? add)? bindAdd;
  const OwnerProducts({super.key, required this.station, this.bindAdd});
  @override
  State<OwnerProducts> createState() => _OwnerProductsState();
}

class _OwnerProductsState extends State<OwnerProducts> {
  late Future<List<Product>> _f = Api.products(widget.station.id, onlyAvailable: false).timeout(const Duration(seconds: 20));
  final Future<List<Category>> _cats = Api.categories();
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    widget.bindAdd?.call(() => _edit());
  }

  @override
  void dispose() {
    widget.bindAdd?.call(null);
    super.dispose();
  }

  void _reload() => setState(() => _f = Api.products(widget.station.id, onlyAvailable: false).timeout(const Duration(seconds: 20)));

  Future<void> _edit([Product? p]) async {
    if (!mounted) return;
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
      try {
        final picked = await pickAllowedImage();
        if (picked == null) return;
        setD(() {
          newBytes = picked.bytes;
          newExt = picked.ext;
        });
      } catch (e) {
        if (mounted) showFailureNotice(context, e, failed: 'Could not read that photo.');
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ProductFormDialog(
            isNew: p == null,
            imageBytes: newBytes,
            imageUrl: imageUrl,
            categories: cats,
            categoryId: cat,
            onCategory: (v) => setD(() => cat = v),
            name: name,
            unit: unit,
            price: price,
            onPickPhoto: () => pick(setD),
            onRemovePhoto: () async {
              final ok = await confirmRemove(
                context,
                title: 'Remove product photo?',
                message: 'This clears the photo from the form. Save the product to apply the change.',
              );
              if (!ok) return;
              setD(() {
                newBytes = null;
                imageUrl = null;
              });
            },
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () {
              final amount = double.tryParse(price.text.trim());
              if (name.text.trim().isEmpty || unit.text.trim().isEmpty || amount == null || !amount.isFinite || amount <= 0) {
                showAppNotice(ctx, 'Add a name, unit, and valid price above ₱0.');
                return;
              }
              Navigator.pop(ctx, true);
            },
          ),
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
        imageUrl = await Api.uploadProductImage(widget.station.id, newBytes!, newExt, mime);
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
    body: FutureBuilder<List<Product>>(
      future: _f,
      builder: (context, snap) => StateSwitcher(
        child: KeyedSubtree(
          key: ValueKey(snap.hasData),
          child: Builder(
            builder: (context) {
              if (snap.hasError) return LoadFailureView(error: snap.error!, onRetry: _reload);
              if (!snap.hasData) return const SkeletonList();
              if (snap.data!.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: 'No products yet',
                  subtitle: 'Tap + to add water refills, containers, and essentials.',
                );
              }
              return ListView(
                padding: EdgeInsets.only(top: 8, bottom: bottomInset(context, 120)),
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
  );
}

class ProductFormDialog extends StatelessWidget {
  final bool isNew;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final List<Category> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final TextEditingController name, unit, price;
  final VoidCallback onPickPhoto, onRemovePhoto, onCancel, onSave;

  const ProductFormDialog({
    super.key,
    required this.isNew,
    required this.imageBytes,
    required this.imageUrl,
    required this.categories,
    required this.categoryId,
    required this.onCategory,
    required this.name,
    required this.unit,
    required this.price,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onCancel,
    required this.onSave,
  });

  bool get _hasPhoto => imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: imageBytes != null
          ? Image.memory(imageBytes!, width: 84, height: 84, fit: BoxFit.cover)
          : ProductThumb(imageUrl, size: 84, radius: 16),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * .92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isNew ? 'New product' : 'Edit product',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  photo,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _hasPhoto ? 'Shown on your menu.' : 'Customers see this photo on your menu.',
                      style: const TextStyle(color: RF.muted, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: onPickPhoto,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: Text(_hasPhoto ? 'Replace photo' : 'Add photo'),
              ),
              if (_hasPhoto)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFD14343), minimumSize: const Size(0, 40)),
                  onPressed: onRemovePhoto,
                  icon: const Icon(Icons.hide_image_outlined, size: 18),
                  label: const Text('Remove photo'),
                ),
              const SizedBox(height: 4),
              const Text('JPG, PNG, or WebP. Up to 5 MB.', style: TextStyle(color: RF.muted, fontSize: 13)),
              const SizedBox(height: 16),
              if (categories.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: onCategory,
                ),
                const SizedBox(height: 12),
              ],
              TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: unit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Unit', hintText: 'gallon, kg, tank'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (₱)'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Remove product?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('$name will leave your menu. Past orders keep this item.'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: const Color(0xFFD14343)),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
