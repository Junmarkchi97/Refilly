import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';

/// Live order status + rider position (Supabase Realtime).
class TrackingScreen extends StatelessWidget {
  final String orderId, customerId;
  const TrackingScreen({super.key, required this.orderId, required this.customerId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Track order')),
        body: StreamBuilder<List<Order>>(
          stream: Api.watchOrders(customerId: customerId),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final o = snap.data!.where((x) => x.id == orderId).firstOrNull;
            if (o == null) return const Center(child: Text('Order not found'));
            final station = o.station;
            final stationPt = station == null ? null : LatLng((station['lat'] as num).toDouble(), (station['lng'] as num).toDouble());
            final drop = o.deliveryLat == null ? null : LatLng(o.deliveryLat!, o.deliveryLng!);
            final step = orderStatuses.indexOf(o.status);
            return Column(children: [
              Expanded(
                child: StreamBuilder<Map<String, dynamic>?>(
                  stream: o.riderId != null && o.status == 'out_for_delivery' ? Api.watchRider(o.riderId!) : const Stream.empty(),
                  builder: (context, rs) {
                    final r = rs.data;
                    final riderPt = r == null ? null : LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
                    return FlutterMap(
                      options: MapOptions(initialCenter: riderPt ?? drop ?? stationPt ?? manila, initialZoom: 14),
                      children: [
                        osmTiles(),
                        MarkerLayer(markers: [
                          if (stationPt != null) pin(stationPt, Icons.store, Colors.blue),
                          if (drop != null) pin(drop, Icons.home, Colors.red),
                          if (riderPt != null) pin(riderPt, Icons.delivery_dining, Colors.purple),
                        ]),
                        osmAttribution(),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(statusLabel(o.status), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: statusColor(o.status))),
                  if (o.status != 'cancelled') LinearProgressIndicator(value: (step + 1) / 5),
                  const SizedBox(height: 8),
                  Text('${o.station?['name'] ?? ''} · ${peso(o.total)} · ${o.paymentMethod.toUpperCase()}'),
                  for (final i in o.items) Text('${i.quantity} × ${i.productName}'),
                  if (o.status == 'pending')
                    TextButton(onPressed: () => Api.setStatus(o.id, 'cancelled'), child: const Text('Cancel order')),
                ]),
              ),
            ]);
          },
        ),
      );
}
