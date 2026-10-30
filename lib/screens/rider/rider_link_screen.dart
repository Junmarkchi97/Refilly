import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api.dart';
import '../../services/location.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Opened from the owner's delivery link: no account, every action is token-checked in SQL.
class RiderLinkScreen extends StatefulWidget {
  final String token;
  const RiderLinkScreen({super.key, required this.token});
  @override
  State<RiderLinkScreen> createState() => _RiderLinkScreenState();
}

class _RiderLinkScreenState extends State<RiderLinkScreen> {
  Map<String, dynamic>? _o;
  String? _error;
  StreamSubscription<Position>? _gps;
  LatLng? _me;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await Api.riderOrder(widget.token);
      setState(() {
        _o = o;
        _error = null;
      });
    } catch (_) {
      await _gps?.cancel();
      _gps = null;
      setState(() => _error = 'This delivery link has expired or is invalid.');
    }
  }

  Future<void> _share() async {
    if (!await LocationService.ensurePermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allow location to share it with the customer')));
      }
      return;
    }
    await _gps?.cancel();
    _gps = LocationService.stream().listen((p) async {
      setState(() => _me = LatLng(p.latitude, p.longitude));
      try {
        await Api.riderLocation(widget.token, p.latitude, p.longitude, p.heading);
      } catch (_) {
        _load();
      }
    });
    setState(() {});
  }

  Future<void> _status(String s) async {
    setState(() => _busy = true);
    try {
      await Api.riderStatus(widget.token, s);
      if (s == 'out_for_delivery' && _gps == null) await _share();
      if (s == 'delivered') {
        await _gps?.cancel();
        _gps = null;
        setState(() => _error = 'Delivered. Thank you! This link is now closed.');
        return;
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  LatLng? _pt(dynamic lat, dynamic lng) => lat == null || lng == null ? null : LatLng((lat as num).toDouble(), (lng as num).toDouble());

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Refilly delivery')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final o = _o;
    if (o == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final st = Map<String, dynamic>.from(o['station'] ?? {});
    final stPt = _pt(st['lat'], st['lng']);
    final drop = _pt(o['delivery_lat'], o['delivery_lng']);
    final status = o['status'] as String;
    final phone = o['contact_phone'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text('Delivery · ${st['name'] ?? ''}')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: _me ?? drop ?? stPt ?? manila, initialZoom: 14),
              children: [
                osmTiles(),
                MarkerLayer(
                  markers: [
                    if (stPt != null) pin(stPt, Icons.store, Colors.blue),
                    if (drop != null) pin(drop, Icons.home, Colors.red),
                    if (_me != null) pin(_me!, Icons.delivery_dining, Colors.purple),
                  ],
                ),
                osmAttribution(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: RF.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${o['customer_name'] ?? 'Customer'} · ${peso(o['total'] as num)} · ${(o['payment_method'] as String).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(o['delivery_address'] ?? ''),
                if ((o['notes'] as String?)?.isNotEmpty ?? false) Text('Notes: ${o['notes']}'),
                for (final i in (o['items'] as List)) Text('${i['quantity']} × ${i['product_name']}'),
                if (_gps != null) const Text('● Sharing live location', style: TextStyle(color: Colors.green)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (phone != null)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    if (drop != null)
                      OutlinedButton.icon(
                        onPressed: () =>
                            launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${drop.latitude},${drop.longitude}')),
                        icon: const Icon(Icons.directions),
                        label: const Text('Directions'),
                      ),
                    if (status != 'out_for_delivery')
                      FilledButton(onPressed: _busy ? null : () => _status('out_for_delivery'), child: const Text('Start delivery')),
                    if (status == 'out_for_delivery' && _gps == null)
                      OutlinedButton(onPressed: _share, child: const Text('Share live location')),
                    if (status == 'out_for_delivery')
                      FilledButton(onPressed: _busy ? null : () => _status('delivered'), child: const Text('Mark delivered')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
