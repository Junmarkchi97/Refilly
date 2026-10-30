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
        body: EmptyState(
          icon: _error!.startsWith('Delivered') ? Icons.check_circle_rounded : Icons.link_off_rounded,
          title: _error!.startsWith('Delivered') ? 'Delivered' : 'Link closed',
          subtitle: _error!,
        ),
      );
    }
    final o = _o;
    if (o == null) return const Scaffold(body: SkeletonList());
    final st = Map<String, dynamic>.from(o['station'] ?? {});
    final stPt = _pt(st['lat'], st['lng']);
    final drop = _pt(o['delivery_lat'], o['delivery_lng']);
    final status = o['status'] as String;
    final phone = o['contact_phone'] as String?;
    final eta = etaText(_me ?? stPt, drop);
    return MapSheetScaffold(
      initial: .5,
      min: .3,
      topRight: _gps != null ? const MapButton(Icons.gps_fixed_rounded, label: 'Live') : null,
      map: FlutterMap(
        options: MapOptions(initialCenter: shiftUp(_me ?? drop ?? stPt ?? manila), initialZoom: 14, initialCameraFit: fitAboveSheet([?_me, ?drop, ?stPt])),
        children: [
          osmTiles(),
          if (drop != null && (stPt ?? _me) != null)
            PolylineLayer(
              polylines: [
                Polyline(points: [_me ?? stPt!, drop], strokeWidth: 4, color: RF.ink),
              ],
            ),
          MarkerLayer(markers: [if (stPt != null) pin(stPt, Icons.water_drop_rounded, RF.ink), if (drop != null) dot(drop)]),
          if (_me != null) GlidingMarker(point: _me!, builder: (p) => pin(p, Icons.delivery_dining_rounded, RF.accent)),
          osmAttribution(),
        ],
      ),
      bottomBar: Container(
        color: Colors.white,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Pressable(
            child: status != 'out_for_delivery'
                ? FilledButton(onPressed: _busy ? null : () => _status('out_for_delivery'), child: const Text('Start delivery'))
                : FilledButton(onPressed: _busy ? null : () => _status('delivered'), child: const Text('Mark delivered')),
          ),
        ),
      ),
      sheet: (_) => [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  status == 'out_for_delivery' ? 'Deliver to ${o['customer_name'] ?? 'customer'}' : 'Pick up at ${st['name'] ?? 'station'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              StatusPill(status),
            ],
          ),
        ),
        if (eta != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Text(
              eta,
              style: const TextStyle(color: RF.accent, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 14),
        RiderCard(
          name: o['customer_name'] ?? 'Customer',
          phone: phone,
          eta: 'Customer',
          onCall: phone == null ? null : () => launchUrl(Uri.parse('tel:$phone')),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RouteBox(from: st['name'] ?? 'Station', to: o['delivery_address'] ?? ''),
        ),
        const SizedBox(height: 8),
        for (final i in (o['items'] as List)) KeyValueRow('${i['quantity']} × ${i['product_name']}', ''),
        KeyValueRow('Collect (${(o['payment_method'] as String).toUpperCase()})', peso(o['total'] as num), bold: true),
        if ((o['notes'] as String?)?.isNotEmpty ?? false) KeyValueRow('Notes', o['notes']),
        const SizedBox(height: 8),
        if (drop != null)
          PlaceRow(
            icon: Icons.directions_rounded,
            title: 'Directions',
            subtitle: 'Open in Google Maps',
            onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${drop.latitude},${drop.longitude}')),
          ),
        if (status == 'out_for_delivery' && _gps == null)
          PlaceRow(
            icon: Icons.gps_fixed_rounded,
            title: 'Share live location',
            subtitle: 'Let the customer see you on the map',
            onTap: _share,
          ),
      ],
    );
  }
}
