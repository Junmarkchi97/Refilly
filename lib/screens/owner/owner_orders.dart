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
  late Future<List<Profile>> _riders = Api.riders(widget.station.id);
  bool _showDone = false;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!.where((o) => _showDone || !(o.status == 'delivered' || o.status == 'cancelled')).toList();
          return Column(children: [
            SwitchListTile(title: const Text('Show delivered/cancelled'), value: _showDone, onChanged: (v) => setState(() => _showDone = v)),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No orders'))
                  : ListView(children: [for (final o in list) _tile(o)]),
            ),
          ]);
        },
      );

  Widget _tile(Order o) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ExpansionTile(
          leading: CircleAvatar(backgroundColor: statusColor(o.status), radius: 8),
          title: Text('${o.customer?['full_name'] ?? 'Customer'} · ${peso(o.total)}'),
          subtitle: Text('${statusLabel(o.status)} · ${TimeOfDay.fromDateTime(o.createdAt).format(context)}'),
          childrenPadding: const EdgeInsets.all(12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${o.contactPhone ?? o.customer?['phone'] ?? '-'}'),
            Text('Address: ${o.deliveryAddress}'),
            if (o.notes?.isNotEmpty ?? false) Text('Notes: ${o.notes}'),
            Text('Payment: ${o.paymentMethod.toUpperCase()} (${o.paymentStatus})'),
            const Divider(),
            for (final i in o.items) Text('${i.quantity} × ${i.productName} @ ${peso(i.unitPrice)}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (o.status == 'pending') FilledButton(onPressed: () => Api.setStatus(o.id, 'accepted'), child: const Text('Accept')),
              if (o.status == 'accepted') FilledButton(onPressed: () => Api.setStatus(o.id, 'preparing'), child: const Text('Preparing')),
              if (o.status == 'pending' || o.status == 'accepted')
                OutlinedButton(onPressed: () => Api.setStatus(o.id, 'cancelled'), child: const Text('Reject')),
              if (o.status == 'out_for_delivery') OutlinedButton(onPressed: () => Api.setStatus(o.id, 'delivered'), child: const Text('Mark delivered')),
              if (o.status != 'delivered' && o.status != 'cancelled')
                FutureBuilder<List<Profile>>(
                  future: _riders,
                  builder: (context, rs) => DropdownButton<String>(
                    hint: const Text('Assign rider'),
                    value: (rs.data ?? []).any((r) => r.id == o.riderId) ? o.riderId : null,
                    items: [for (final r in rs.data ?? <Profile>[]) DropdownMenuItem(value: r.id, child: Text(r.fullName ?? r.phone ?? 'Rider'))],
                    onChanged: (v) async {
                      if (v == null) return;
                      await Api.assignRider(o.id, v);
                      setState(() => _riders = Api.riders(widget.station.id));
                    },
                  ),
                ),
            ]),
          ],
        ),
      );
}
