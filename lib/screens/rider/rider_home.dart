import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import '../widgets.dart';

class RiderHome extends StatefulWidget {
  final Profile profile;
  const RiderHome({super.key, required this.profile});
  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  StreamSubscription<Position>? _gps;
  String? _activeOrder;
  LatLng? _me;

  Future<void> _startDelivery(Order o) async {
    if (!await LocationService.ensurePermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission needed')));
      return;
    }
    await Api.setStatus(o.id, 'out_for_delivery');
    await _gps?.cancel();
    setState(() => _activeOrder = o.id);
    _gps = LocationService.stream().listen((p) {
      setState(() => _me = LatLng(p.latitude, p.longitude));
      Api.pushLocation(o.id, p.latitude, p.longitude, p.heading);
    });
  }

  Future<void> _delivered(Order o) async {
    await Api.setStatus(o.id, 'delivered');
    if (_activeOrder == o.id) {
      await _gps?.cancel();
      setState(() => _activeOrder = null);
    }
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My deliveries'), actions: [logoutButton()]),
        body: StreamBuilder<List<Order>>(
          stream: Api.watchOrders(riderId: widget.profile.id),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final active = snap.data!.where((o) => o.status != 'delivered' && o.status != 'cancelled').toList();
            if (active.isEmpty) return const Center(child: Text('No assigned deliveries'));
            return ListView(padding: const EdgeInsets.all(8), children: [
              if (_activeOrder != null)
                const Card(color: Colors.greenAccent, child: ListTile(leading: Icon(Icons.gps_fixed), title: Text('Sharing live location'))),
              for (final o in active) _card(o),
            ]);
          },
        ),
      );

  Widget _card(Order o) {
    final drop = o.deliveryLat == null ? null : LatLng(o.deliveryLat!, o.deliveryLng!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o.customer?['full_name'] ?? 'Customer', style: Theme.of(context).textTheme.titleMedium),
          Text(o.deliveryAddress),
          if (o.notes?.isNotEmpty ?? false) Text('Note: ${o.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
          for (final i in o.items) Text('${i.quantity} × ${i.productName}'),
          Text('Collect: ${peso(o.total)} (${o.paymentMethod.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (drop != null)
            SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(initialCenter: drop, initialZoom: 15),
                children: [
                  osmTiles(),
                  MarkerLayer(markers: [pin(drop, Icons.home, Colors.red), if (_me != null) pin(_me!, Icons.delivery_dining, Colors.purple)]),
                ],
              ),
            ),
          Wrap(spacing: 8, children: [
            Chip(label: Text(statusLabel(o.status))),
            if (o.contactPhone?.isNotEmpty ?? false)
              OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${o.contactPhone}')), icon: const Icon(Icons.call), label: const Text('Call')),
            if (o.status != 'out_for_delivery')
              FilledButton.icon(onPressed: () => _startDelivery(o), icon: const Icon(Icons.delivery_dining), label: const Text('Start delivery')),
            if (o.status == 'out_for_delivery' && _activeOrder != o.id)
              OutlinedButton(onPressed: () => _startDelivery(o), child: const Text('Resume GPS')),
            if (o.status == 'out_for_delivery')
              FilledButton.icon(onPressed: () => _delivered(o), icon: const Icon(Icons.check), label: const Text('Delivered')),
          ]),
        ]),
      ),
    );
  }
}
