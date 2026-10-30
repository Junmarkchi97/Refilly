import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Live order status + rider position (Supabase Realtime), Glide-style.
class TrackingScreen extends StatelessWidget {
  final String orderId, customerId;
  const TrackingScreen({super.key, required this.orderId, required this.customerId});

  @override
  Widget build(BuildContext context) => StreamBuilder<Order?>(
    stream: Api.watchOrder(orderId),
    builder: (context, snap) {
      if (snap.hasError) return Scaffold(body: Center(child: Text('Unable to load order: ${snap.error}')));
      if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: SkeletonList());
      final o = snap.data;
      if (o == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(icon: Icons.search_off_rounded, title: 'Order not found', subtitle: 'It may have been removed.'),
        );
      }
      final station = o.station;
      final stationPt = station == null ? null : LatLng((station['lat'] as num).toDouble(), (station['lng'] as num).toDouble());
      final drop = o.deliveryLat == null || o.deliveryLng == null ? null : LatLng(o.deliveryLat!, o.deliveryLng!);
      return StreamBuilder<Map<String, dynamic>?>(
        stream: o.status == 'out_for_delivery' ? Api.watchRider(o.id) : const Stream.empty(),
        builder: (context, rs) {
          final r = rs.data;
          final riderPt = r == null ? null : LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
          final eta = o.status == 'delivered' || o.status == 'cancelled' ? null : etaText(riderPt ?? stationPt, drop);
          final title = switch (o.status) {
            'pending' => 'Waiting for the station',
            'accepted' || 'preparing' => 'Preparing your order',
            'out_for_delivery' => eta == null ? 'Your rider is on the way' : 'Arriving in ${eta.replaceAll(' away', '')}',
            'delivered' => 'Delivered',
            _ => 'Order cancelled',
          };
          return MapSheetScaffold(
            initial: .5,
            min: .28,
            topLeft: MapButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            topRight: null,
            map: FlutterMap(
              options: MapOptions(
                initialCenter: shiftUp(riderPt ?? drop ?? stationPt ?? manila),
                initialZoom: 14,
                initialCameraFit: fitAboveSheet([?riderPt, ?drop, ?stationPt]),
              ),
              children: [
                osmTiles(),
                if (stationPt != null && drop != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: [riderPt ?? stationPt, drop], strokeWidth: 4, color: RF.ink),
                    ],
                  ),
                MarkerLayer(
                  markers: [if (stationPt != null) photoPin(stationPt, station?['photo_url']), if (drop != null) dot(drop)],
                ),
                if (riderPt != null) GlidingMarker(point: riderPt, builder: (p) => pin(p, Icons.delivery_dining_rounded, RF.accent)),
                osmAttribution(),
              ],
            ),
            sheet: (_) => [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
                    StatusPill(o.status),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
                child: Text(
                  '${o.station?['name'] ?? ''} · ${peso(o.total)} · ${o.paymentMethod.toUpperCase()}',
                  style: const TextStyle(color: RF.muted),
                ),
              ),
              if (o.riderName != null) ...[
                RiderCard(
                  name: o.riderName!,
                  phone: o.riderPhone,
                  eta: o.status == 'out_for_delivery' ? eta : 'Your rider',
                  onCall: o.riderPhone == null ? null : () => launchUrl(Uri.parse('tel:${o.riderPhone}')),
                ),
                const SizedBox(height: 16),
              ],
              if (o.status != 'cancelled') StatusSteps(o.status),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RouteBox(from: o.station?['name'] ?? 'Station', to: o.deliveryAddress),
              ),
              const SizedBox(height: 8),
              for (final i in o.items)
                KeyValueRow(
                  '${i.quantity} × ${i.productName}',
                  peso(i.unitPrice * i.quantity),
                  leading: ProductThumb(i.imageUrl, size: 40, radius: 10),
                ),
              KeyValueRow('Total', peso(o.total), bold: true),
              if (o.status == 'pending')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await Api.cancelOrder(o.id);
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
                      }
                    },
                    child: const Text('Cancel order'),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
