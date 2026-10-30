import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';

class OwnerOrders extends StatefulWidget {
  final Station station;
  const OwnerOrders({super.key, required this.station});
  @override
  State<OwnerOrders> createState() => _OwnerOrdersState();
}

class _OwnerOrdersState extends State<OwnerOrders> {
  late final _stream = Api.watchOrders(stationId: widget.station.id);
  bool _showDone = false;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
    stream: _stream,
    builder: (context, snap) => StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(snap.hasData),
        child: Builder(
          builder: (context) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const SkeletonList();
            final list = snap.data!.where((o) => _showDone || !(o.status == 'delivered' || o.status == 'cancelled')).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: InfoBox(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 20, color: RF.muted),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Show delivered & cancelled', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Switch(value: _showDone, onChanged: (v) => setState(() => _showDone = v)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: _showDone ? 'No orders yet' : 'No active orders',
                          subtitle: _showDone
                              ? 'New orders from customers appear here in real time.'
                              : 'You are all caught up. Turn on the switch to see delivered and cancelled orders.',
                          actionLabel: _showDone ? null : 'Show history',
                          onAction: _showDone ? null : () => setState(() => _showDone = true),
                        )
                      : ListView(
                          padding: EdgeInsets.only(bottom: bottomInset(context, 100)),
                          children: [for (final (i, o) in list.indexed) FadeSlideIn(index: i, child: _tile(o))],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Future<void> _assign(Order o) async {
    final name = TextEditingController(text: o.riderName);
    final phone = TextEditingController(text: o.riderPhone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final validName = name.text.trim().isNotEmpty;
          final validPhone = RegExp(r'^(09\d{9}|639\d{9}|\+639\d{9})$')
              .hasMatch(phone.text.replaceAll(RegExp(r'[\s-]'), ''));
          final ready = validName && validPhone;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.delivery_dining_rounded, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Assign a rider',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order for ${o.customer?['full_name'] ?? 'Customer'}',
                      style: const TextStyle(color: RF.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Rider name',
                        hintText: 'Enter full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '09XX XXX XXXX',
                        prefixIcon: Icon(Icons.phone_outlined),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: RF.muted, size: 17),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'We’ll create a private delivery link to share with your rider. Creating a new link disables the previous one.',
                            style: TextStyle(color: RF.muted, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: ready ? () => Navigator.pop(dialogContext, true) : null,
                            child: Text(o.riderName == null ? 'Create link' : 'Update link'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final riderName = name.text.trim();
    final riderPhone = phone.text.replaceAll(RegExp(r'[\s-]'), '');
    name.dispose();
    phone.dispose();
    if (ok != true || !mounted) return;
    try {
      final token = await Api.assignRider(o.id, riderName, riderPhone);
      if (mounted) await shareRiderLink(context, Api.riderLink(token), riderName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign rider: $e')),
        );
      }
    }
  }

  Future<void> _shareExisting(Order o) async {
    final t = await Api.riderToken(o.id);
    if (t == null || !mounted) return;
    await shareRiderLink(context, Api.riderLink(t), o.riderName ?? 'Rider');
  }

  final Set<String> _busy = {};

  Future<void> _act(Order o, String status, {String? confirm}) async {
    if (confirm != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(confirm),
          content: Text('${o.customer?['full_name'] ?? 'Customer'} · ${peso(o.total)}. The customer will be notified.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep order')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy.add(o.id));
    try {
      await Api.setStatus(o.id, status);
      tapHaptic();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: ${e.toString().replaceFirst('Exception: ', '')}')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  Future<void> _confirmCod(Order order) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirm cash received?'),
      content: Text('Confirm you collected ${peso(order.total)} for this delivery. This cannot be undone here.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cash collected'))],
    ));
    if (confirmed != true) return;
    try {
      await sb.rpc('confirm_cod_collection', params: {'p_order': order.id});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('COD payment marked as collected')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment confirmation failed: $e')));
    }
  }

  Widget _btn(String label, VoidCallback? onTap, {bool primary = true, bool busy = false}) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    final child = busy && primary
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    return Expanded(
      child: Pressable(
        child: primary
            ? FilledButton(style: style, onPressed: busy ? () {} : onTap, child: child)
            : OutlinedButton(style: style, onPressed: busy ? null : onTap, child: child),
      ),
    );
  }

  Widget _tile(Order o) {
    final busy = _busy.contains(o.id);
    final open = o.status != 'delivered' && o.status != 'cancelled';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(RF.radius),
          border: Border.all(color: RF.line),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: RF.fill,
                  child: Text(
                    ((o.customer?['full_name'] as String?) ?? 'C').characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: RF.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.customer?['full_name'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        '${TimeOfDay.fromDateTime(o.createdAt).format(context)} · ${o.items.fold<int>(0, (t, i) => t + i.quantity)} items · ${o.paymentMethod.toUpperCase()}',
                        style: const TextStyle(color: RF.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(peso(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 4),
                    StatusPill(o.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            RouteBox(from: o.contactPhone ?? o.customer?['phone'] ?? 'No phone', to: o.deliveryAddress),
            const SizedBox(height: 8),
            for (final i in o.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    ProductThumb(i.imageUrl, size: 36, radius: 9),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${i.quantity} × ${i.productName}', style: const TextStyle(color: RF.muted)),
                    ),
                    Text(peso(i.unitPrice * i.quantity), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (o.notes?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Notes: ${o.notes}', style: const TextStyle(color: RF.muted, fontSize: 13)),
              ),
            if (o.riderName != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: InfoBox(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${o.riderName} ${o.riderPhone ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (open)
                        TextButton(
                          onPressed: () => _shareExisting(o),
                          style: TextButton.styleFrom(foregroundColor: RF.accent),
                          child: const Text('Share link'),
                        ),
                    ],
                  ),
                ),
              ),
            if (o.status == 'delivered' && o.paymentMethod == 'cod' && o.paymentStatus == 'unpaid') ...[
              const SizedBox(height: 12),
              Row(children: [_btn('Confirm cash collected', () => _confirmCod(o))]),
            ],
            if (open) const SizedBox(height: 12),
            if (o.status == 'pending')
              Row(
                children: [
                  _btn('Reject', () => _act(o, 'cancelled', confirm: 'Reject this order?'), primary: false, busy: busy),
                  const SizedBox(width: 10),
                  _btn('Accept', () => _act(o, 'accepted'), busy: busy),
                ],
              ),
            if (o.status == 'accepted' || o.status == 'preparing')
              Row(
                children: [
                  _btn(o.riderName == null ? 'Assign rider' : 'Change rider', () => _assign(o), primary: false),
                  const SizedBox(width: 10),
                  if (o.status == 'accepted') _btn('Preparing', () => _act(o, 'preparing'), busy: busy),
                  if (o.status == 'preparing')
                    _btn('Cancel', () => _act(o, 'cancelled', confirm: 'Cancel this order?'), primary: false, busy: busy),
                ],
              ),
            if (o.status == 'out_for_delivery') Row(children: [_btn('Mark delivered', () => _act(o, 'delivered'), busy: busy)]),
          ],
        ),
      ),
    );
  }
}
