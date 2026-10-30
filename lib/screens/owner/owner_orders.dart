import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
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
    builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final list = snap.data!.where((o) => _showDone || !(o.status == 'delivered' || o.status == 'cancelled')).toList();
      return Column(
        children: [
          SwitchListTile(title: const Text('Show delivered/cancelled'), value: _showDone, onChanged: (v) => setState(() => _showDone = v)),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No orders'))
                : ListView(padding: const EdgeInsets.only(bottom: 120), children: [for (final o in list) _tile(o)]),
          ),
        ],
      );
    },
  );

  Future<void> _assign(Order o) async {
    final name = TextEditingController(text: o.riderName), phone = TextEditingController(text: o.riderPhone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rider for this order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Rider name'),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Rider mobile (09xx)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            const Text(
              'A private delivery link is created. Send it to the rider; no account needed. Making a new link disables the old one.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create link')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final token = await Api.assignRider(o.id, name.text, phone.text);
      if (mounted) await shareRiderLink(context, Api.riderLink(token), name.text.trim());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _shareExisting(Order o) async {
    final t = await Api.riderToken(o.id);
    if (t == null || !mounted) return;
    await shareRiderLink(context, Api.riderLink(t), o.riderName ?? 'Rider');
  }

  Widget _tile(Order o) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ExpansionTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: statusColor(o.status), shape: BoxShape.circle),
      ),
      title: Text('${o.customer?['full_name'] ?? 'Customer'} · ${peso(o.total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${statusLabel(o.status)} · ${TimeOfDay.fromDateTime(o.createdAt).format(context)}'),
      childrenPadding: const EdgeInsets.all(12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone: ${o.contactPhone ?? o.customer?['phone'] ?? '-'}'),
        Text('Address: ${o.deliveryAddress}'),
        if (o.notes?.isNotEmpty ?? false) Text('Notes: ${o.notes}'),
        Text('Payment: ${o.paymentMethod.toUpperCase()} (${o.paymentStatus})'),
        if (o.riderName != null) Text('Rider: ${o.riderName} ${o.riderPhone ?? ''}'),
        const Divider(),
        for (final i in o.items) Text('${i.quantity} × ${i.productName} @ ${peso(i.unitPrice)}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (o.status == 'pending') FilledButton(onPressed: () => Api.setStatus(o.id, 'accepted'), child: const Text('Accept')),
            if (o.status == 'accepted') FilledButton(onPressed: () => Api.setStatus(o.id, 'preparing'), child: const Text('Preparing')),
            if (o.status == 'pending' || o.status == 'accepted')
              OutlinedButton(onPressed: () => Api.setStatus(o.id, 'cancelled'), child: const Text('Reject')),
            if (o.status == 'out_for_delivery')
              OutlinedButton(onPressed: () => Api.setStatus(o.id, 'delivered'), child: const Text('Mark delivered')),
            if (o.status != 'delivered' && o.status != 'cancelled' && o.status != 'pending')
              OutlinedButton.icon(
                icon: const Icon(Icons.delivery_dining),
                label: Text(o.riderName == null ? 'Assign rider' : 'Rider: ${o.riderName}'),
                onPressed: () => _assign(o),
              ),
            if (o.riderName != null && o.status != 'delivered' && o.status != 'cancelled')
              TextButton.icon(icon: const Icon(Icons.share), label: const Text('Share rider link'), onPressed: () => _shareExisting(o)),
          ],
        ),
      ],
    ),
  );
}
