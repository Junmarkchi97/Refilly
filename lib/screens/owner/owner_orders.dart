import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../models/saved_rider.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import '../network_states.dart';
import 'cash_confetti.dart';

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
    final picked = await showDialog<SavedRider>(
      context: context,
      builder: (dialogContext) => AssignRiderDialog(
        order: o,
        loadRiders: () => Api.stationRiders(widget.station.id),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      final token = await Api.assignRider(o.id, picked.name, picked.phone, stationId: widget.station.id);
      if (mounted) await shareRiderLink(context, Api.riderLink(token), picked.name);
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

  /// Accept moves the order straight into preparing (accepted → preparing).
  Future<void> _accept(Order o) async {
    setState(() => _busy.add(o.id));
    try {
      await Api.setStatus(o.id, 'accepted');
      await Api.setStatus(o.id, 'preparing');
      tapHaptic();
    } catch (e) {
      if (mounted) {
        showFailureNotice(context, e, failed: 'Could not accept this order.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

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
      // Marking delivered means COD cash was collected with the handoff.
      if (status == 'delivered' && o.paymentMethod == 'cod' && o.paymentStatus == 'unpaid') {
        try {
          await sb.rpc('confirm_cod_collection', params: {'p_order': o.id});
        } catch (_) {
          /* Newer owner_set_order_status may already mark COD paid. */
        }
      }
      tapHaptic();
      if (status == 'delivered' && mounted) {
        celebrateOrderDelivered(context);
        showAppNotice(context, 'Order marked as delivered', kind: AppNotice.success);
      }
    } catch (e) {
      if (mounted) {
        showFailureNotice(context, e, failed: 'Could not update this order.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
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
    final hasRider = orderHasRider(o);
    final needsRider = (o.status == 'accepted' || o.status == 'preparing' || o.status == 'out_for_delivery') && !hasRider;
    final String? primaryLabel;
    final VoidCallback? onPrimary;
    if (needsRider) {
      primaryLabel = 'Assign rider';
      onPrimary = () => _assign(o);
    } else if (ownerCanMarkDelivered(o)) {
      primaryLabel = 'Mark delivered';
      onPrimary = () => _act(o, 'delivered');
    } else {
      primaryLabel = null;
      onPrimary = null;
    }
    return OwnerOrderCard(
      order: o,
      busy: busy,
      onShare: open && hasRider ? () => _shareExisting(o) : null,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      actions: [
        if (o.status == 'pending') ...[
          _btn('Reject', () => _act(o, 'cancelled', confirm: 'Reject this order?'), primary: false, danger: true, busy: busy),
          const SizedBox(width: 10),
          _btn('Accept', () => _accept(o), busy: busy),
        ],
        if (o.status == 'accepted' || o.status == 'preparing') ...[
          if (hasRider) ...[
            _btn('Change rider', () => _assign(o), primary: false),
            if (o.status == 'preparing') const SizedBox(width: 10),
          ],
          if (o.status == 'preparing')
            _btn('Cancel', () => _act(o, 'cancelled', confirm: 'Cancel this order?'), primary: false, danger: true, busy: busy),
        ],
        if (o.status == 'out_for_delivery' && hasRider)
          _btn('Change rider', () => _assign(o), primary: false),
      ],
    );
  }
}

class OwnerOrderCard extends StatelessWidget {
  final Order order;
  final bool busy;
  final VoidCallback? onShare;
  final VoidCallback? onPrimary;
  final String? primaryLabel;
  final List<Widget> actions;
  const OwnerOrderCard({
    super.key,
    required this.order,
    required this.actions,
    this.busy = false,
    this.onShare,
    this.onPrimary,
    this.primaryLabel,
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
            if (onPrimary != null && primaryLabel != null) ...[
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
                    onPressed: busy ? () {} : onPrimary,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(primaryLabel!),
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

/// Dialog to pick a saved rider or enter a new name and phone.
class AssignRiderDialog extends StatefulWidget {
  final Order order;
  final Future<List<SavedRider>> Function() loadRiders;
  const AssignRiderDialog({
    super.key,
    required this.order,
    required this.loadRiders,
  });

  @override
  State<AssignRiderDialog> createState() => _AssignRiderDialogState();
}

class _AssignRiderDialogState extends State<AssignRiderDialog> {
  late final _name = TextEditingController(text: widget.order.riderName ?? '');
  late final _phone = TextEditingController(text: widget.order.riderPhone ?? '');
  late final Future<List<SavedRider>> _riders = widget.loadRiders();
  String? _selectedPhone;

  bool get _ready {
    final validName = _name.text.trim().isNotEmpty;
    final validPhone = RegExp(r'^(09\d{9}|639\d{9}|\+639\d{9})$')
        .hasMatch(_phone.text.replaceAll(RegExp(r'[\s-]'), ''));
    return validName && validPhone;
  }

  void _select(SavedRider rider) {
    setState(() {
      _name.text = rider.name;
      _phone.text = rider.phone;
      _selectedPhone = rider.normalizedPhone;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updating = widget.order.riderName != null;
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Order for ${widget.order.customer?['full_name'] ?? 'Customer'}',
                style: const TextStyle(color: RF.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<SavedRider>>(
                future: _riders,
                builder: (context, snap) {
                  final riders = snap.data ?? const <SavedRider>[];
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }
                  if (riders.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saved riders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final rider in riders)
                              ChoiceChip(
                                selected: _selectedPhone == rider.normalizedPhone,
                                avatar: Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: _selectedPhone == rider.normalizedPhone ? Colors.white : RF.ink,
                                ),
                                label: Text('${rider.name} · ${rider.phone}'),
                                onSelected: (_) => _select(rider),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap a rider to fill the form, or enter someone new below.',
                          style: TextStyle(color: RF.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _selectedPhone = null),
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
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _selectedPhone = null),
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
                      updating
                          ? 'Updating the rider creates a new private link and disables the previous one. The order stays on delivering.'
                          : 'Saving the rider marks this order as delivering and creates a private link to share. A new link replaces the previous one.',
                      style: const TextStyle(color: RF.muted, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _ready
                          ? () => Navigator.pop(
                                context,
                                SavedRider(name: _name.text.trim(), phone: normalizeRiderPhone(_phone.text)),
                              )
                          : null,
                      child: Text(updating ? 'Update rider' : 'Save rider'),
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

bool orderHasRider(Order order) => order.riderName != null && order.riderName!.trim().isNotEmpty;

/// Owner can mark delivered only after a rider is assigned and the order is in progress.
bool ownerCanMarkDelivered(Order order) {
  if (!orderHasRider(order)) return false;
  return order.status == 'accepted' || order.status == 'preparing' || order.status == 'out_for_delivery';
}

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
