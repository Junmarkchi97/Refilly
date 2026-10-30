import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import '../network_states.dart';

/// Live order status + rider position (Supabase Realtime), Glide-style.
Future<void> _reviewStation(BuildContext context, Order order) async {
  int rating = 5;
  final note = TextEditingController();
  try {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Rate your water station'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(children: [for (var n = 1; n <= 5; n++) IconButton(
            tooltip: '$n stars',
            icon: Icon(n <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
            onPressed: () => setDialogState(() => rating = n),
          )]),
          TextField(controller: note, maxLength: 1000, maxLines: 3, decoration: const InputDecoration(hintText: 'Optional feedback')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
        ],
      )),
    );
    if (approved != true) return;
    await Api.submitReview(order, rating, note.text);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for reviewing the station!')));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This order may already have a review.')));
  } finally {
    note.dispose();
  }
}

class TrackingScreen extends StatelessWidget {
  final String orderId, customerId;
  const TrackingScreen({super.key, required this.orderId, required this.customerId});

  @override
  Widget build(BuildContext context) => StreamBuilder<Order?>(
    stream: Api.watchOrder(orderId),
    builder: (context, snap) {
      if (snap.hasError) { return Scaffold(
        appBar: AppBar(title: const Text('Track order')),
        body: LoadFailureView(
          error: snap.error!,
          onRetry: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => TrackingScreen(orderId: orderId, customerId: customerId)),
          ),
        ),
      ); }
      if (snap.connectionState == ConnectionState.waiting) { return const Scaffold(body: Center(child: SlowLoadingHint())); }
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
          final lastLocation = DateTime.tryParse(r?['updated_at']?.toString() ?? '');
          final locationAge = lastLocation == null ? null : DateTime.now().difference(lastLocation).inMinutes;
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
              if (o.status == 'out_for_delivery')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    riderPt == null ? 'Waiting for rider location sharing' : locationAge == null ? 'Rider location received' : locationAge >= 3 ? 'Rider location may be outdated · updated $locationAge min ago' : 'Rider location updated recently',
                    style: TextStyle(color: locationAge != null && locationAge >= 3 ? Colors.orange.shade900 : RF.muted),
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
              KeyValueRow('Delivery fee', o.deliveryFee == 0 ? 'Free' : peso(o.deliveryFee)),
              KeyValueRow('Total', peso(o.total), bold: true),
              if (o.status == 'delivered') Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Rate this water station'),
                  onPressed: () => _reviewStation(context, o),
                ),
              ),
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
