import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import '../network_states.dart';

class OwnerOrders extends StatefulWidget {
  final Station station;
  const OwnerOrders({super.key, required this.station});
  @override
  State<OwnerOrders> createState() => _OwnerOrdersState();
}

class _OwnerOrdersState extends State<OwnerOrders> {
  late Stream<List<Order>> _stream = Api.watchOrders(stationId: widget.station.id);

  void _retry() => setState(() => _stream = Api.watchOrders(stationId: widget.station.id));
  bool _showDone = false;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
    stream: _stream,
    builder: (context, snap) => StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(snap.hasData),
        child: Builder(
          builder: (context) {
            if (snap.hasError) return LoadFailureView(error: snap.error!, onRetry: _retry);
            if (!snap.hasData) return const Column(children: [SlowLoadingHint(), Expanded(child: SkeletonList())]);
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: RF.muted, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            o.riderName == null
                                ? 'Saving the rider marks this order as delivering and creates a private link to share. A new link replaces the previous one.'
                                : 'Updating the rider creates a new private link and disables the previous one. The order stays on delivering.',
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
                            child: Text(o.riderName == null ? 'Save rider' : 'Update rider'),
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
        showFailureNotice(context, e, failed: 'Could not assign the rider.');
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
          content: Text('${o.customer?['full_name'] ?? 'Customer'} · ${peso(o.total)}. The customer will be notified. This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep order')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(status == 'cancelled' && o.status != 'pending' ? 'Cancel order' : 'Reject order'),
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
        showFailureNotice(context, e, failed: 'Could not update this order.');
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
      if (mounted) showAppNotice(context, 'Cash payment marked as collected', kind: AppNotice.success);
    } catch (e) {
      if (mounted) showFailureNotice(context, e, failed: 'Could not confirm the payment.');
    }
  }

  Widget _btn(String label, VoidCallback? onTap, {bool primary = true, bool busy = false, bool danger = false}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final child = busy && primary
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    final button = danger
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD14343),
              side: const BorderSide(color: Color(0xFFF0B4B4)),
              minimumSize: const Size.fromHeight(48),
              shape: shape,
            ),
            onPressed: busy ? null : onTap,
            child: child,
          )
        : primary
            ? FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: shape),
                onPressed: busy ? () {} : onTap,
                child: child,
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: shape),
                onPressed: busy ? null : onTap,
                child: child,
              );
    return Expanded(child: Pressable(child: button));
  }

  Widget _tile(Order o) {
    final busy = _busy.contains(o.id);
    final open = o.status != 'delivered' && o.status != 'cancelled';
    return OwnerOrderCard(
      order: o,
      busy: busy,
      onShare: open && o.riderName != null ? () => _shareExisting(o) : null,
      onConfirmCash: o.status == 'delivered' && o.paymentMethod == 'cod' && o.paymentStatus == 'unpaid' ? () => _confirmCod(o) : null,
      onMarkDelivered: ownerCanMarkDelivered(o.status) ? () => _act(o, 'delivered') : null,
      actions: [
        if (o.status == 'pending') ...[
          _btn('Reject', () => _act(o, 'cancelled', confirm: 'Reject this order?'), primary: false, danger: true, busy: busy),
          const SizedBox(width: 10),
          _btn('Accept', () => _act(o, 'accepted'), busy: busy),
        ],
        if (o.status == 'accepted' || o.status == 'preparing') ...[
          _btn(o.riderName == null ? 'Assign rider' : 'Change rider', () => _assign(o), primary: false),
          const SizedBox(width: 10),
          if (o.status == 'accepted') _btn('Preparing', () => _act(o, 'preparing'), busy: busy),
          if (o.status == 'preparing')
            _btn('Cancel', () => _act(o, 'cancelled', confirm: 'Cancel this order?'), primary: false, danger: true, busy: busy),
        ],
        if (o.status == 'out_for_delivery')
          _btn(o.riderName == null ? 'Assign rider' : 'Change rider', () => _assign(o), primary: false),
      ],
    );
  }
}

class OwnerOrderCard extends StatelessWidget {
  final Order order;
  final bool busy;
  final VoidCallback? onShare;
  final VoidCallback? onConfirmCash;
  final VoidCallback? onMarkDelivered;
  final List<Widget> actions;
  const OwnerOrderCard({
    super.key,
    required this.order,
    required this.actions,
    this.busy = false,
    this.onShare,
    this.onConfirmCash,
    this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    final name = (order.customer?['full_name'] as String?)?.trim();
    final customer = name == null || name.isEmpty ? 'Customer' : name;
    final phone = order.contactPhone ?? order.customer?['phone'] as String?;
    final note = order.notes?.trim();
    final count = order.items.fold<int>(0, (total, item) => total + item.quantity);
    final when = TimeOfDay.fromDateTime(order.createdAt).format(context);
    final summary = [when, _paymentLabel(order.paymentMethod)].join(' · ');

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _panel,
                  child: Text(
                    customer.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: RF.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(peso(order.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(summary, style: const TextStyle(color: RF.muted, fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(order.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  _DetailLine(icon: Icons.phone_rounded, label: 'Phone', value: _prettyPhone(phone) ?? 'No phone'),
                  const Divider(height: 18, color: _panelLine),
                  _DetailLine(icon: Icons.location_on_outlined, label: 'Deliver to', value: order.deliveryAddress),
                  if (note != null && note.isNotEmpty) ...[
                    const Divider(height: 18, color: _panelLine),
                    _DetailLine(icon: Icons.sticky_note_2_outlined, label: 'Note', value: note),
                  ],
                ],
              ),
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(count == 1 ? '1 item' : '$count items', style: const TextStyle(color: RF.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ProductThumb(item.imageUrl, size: 36, radius: 9),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${item.quantity} × ${item.productName}')),
                      Text(peso(item.unitPrice * item.quantity), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
            if (order.riderName != null) ...[
              const SizedBox(height: 12),
              _Panel(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rider', style: TextStyle(color: RF.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(order.riderName!, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (_prettyPhone(order.riderPhone) != null)
                            Text(_prettyPhone(order.riderPhone)!, style: const TextStyle(color: RF.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (onShare != null)
                      TextButton(
                        onPressed: busy ? null : onShare,
                        style: TextButton.styleFrom(foregroundColor: RF.accent, visualDensity: VisualDensity.compact),
                        child: const Text('Share link'),
                      ),
                  ],
                ),
              ),
            ],
            if (onConfirmCash != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: onConfirmCash,
                  child: const Text('Confirm cash collected'),
                ),
              ),
            ],
            if (onMarkDelivered != null) ...[
              const SizedBox(height: 12),
              Pressable(
                enabled: !busy,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: busy ? () {} : onMarkDelivered,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Mark delivered'),
                  ),
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

const _panel = Color(0xFFF4F4F5);
const _panelLine = Color(0xFFE4E4E7);

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
    child: child,
  );
}

String _paymentLabel(String method) => switch (method) {
  'cod' => 'Cash',
  'gcash' => 'GCash',
  'maya' => 'Maya',
  _ => method,
};

/// Accepted, preparing, and out-for-delivery orders can be closed by the owner.
bool ownerCanMarkDelivered(String status) =>
    status == 'accepted' || status == 'preparing' || status == 'out_for_delivery';

String? _prettyPhone(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('09')) {
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
  }
  return trimmed;
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: RF.ink),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: RF.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
          ],
        ),
      ),
    ],
  );
}
