import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'tracking_screen.dart';
import '../auth/verify_phone_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Station station;
  final Map<Product, int> cart;
  final Profile profile;
  const CheckoutScreen({super.key, required this.station, required this.cart, required this.profile});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _address = TextEditingController(), _notes = TextEditingController();
  late final _phone = TextEditingController(text: widget.profile.phone);
  final _map = MapController();
  LatLng? _drop;
  final String _payment = 'cod';
  bool _busy = false;

  double get _total => widget.cart.entries.fold(0, (t, e) => t + e.key.price * e.value);

  Future<void> _useMyLocation() async {
    final p = await LocationService.current();
    if (p == null) return;
    setState(() => _drop = LatLng(p.latitude, p.longitude));
    _map.move(_drop!, 16);
  }

  Future<void> _place() async {
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a delivery address')));
      return;
    }
    if (!Api.phoneVerified && await Api.requirePhoneVerification()) {
      if (!mounted) return;
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => VerifyPhoneScreen(initialPhone: _phone.text)));
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final id = await Api.placeOrder(
        stationId: widget.station.id,
        cart: widget.cart,
        address: _address.text.trim(),
        lat: _drop?.latitude,
        lng: _drop?.longitude,
        phone: _phone.text.trim(),
        notes: _notes.text.trim(),
        payment: _payment,
      );
      if (!mounted) return;
      Navigator.of(context)
        ..pop()
        ..pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(orderId: id, customerId: widget.profile.id),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.station;
    final stPt = LatLng(st.lat, st.lng);
    final eta = etaText(stPt, _drop);
    return MapSheetScaffold(
      initial: .66,
      min: .4,
      topLeft: MapButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
      topRight: MapButton(Icons.my_location_rounded, label: 'Use my location', onTap: _useMyLocation),
      map: FlutterMap(
        mapController: _map,
        options: MapOptions(initialCenter: LatLng(st.lat - .006, st.lng), initialZoom: 14, onTap: (_, p) => setState(() => _drop = p)),
        children: [
          osmTiles(),
          if (_drop != null)
            PolylineLayer(
              polylines: [
                Polyline(points: [stPt, _drop!], strokeWidth: 4, color: RF.ink),
              ],
            ),
          MarkerLayer(markers: [pin(stPt, Icons.water_drop_rounded, RF.ink), if (_drop != null) dot(_drop!)]),
          osmAttribution(),
        ],
      ),
      bottomBar: Container(
        color: Colors.white,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Pressable(
            child: FilledButton(onPressed: _busy ? null : _place, child: Text(_busy ? 'Placing order…' : 'Place order · ${peso(_total)}')),
          ),
        ),
      ),
      sheet: (_) => [
        Center(child: Text('Delivery details', style: Theme.of(context).textTheme.headlineSmall)),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 2, bottom: 14),
            child: Text('Where should we deliver?', style: TextStyle(color: RF.muted)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RouteBox(
            from: st.name,
            to: '',
            toField: TextField(
              controller: _address,
              decoration: const InputDecoration(
                hintText: 'House no., street, barangay',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            _drop == null ? 'Tap the map to pin your exact drop-off.' : 'Drop-off pinned. Tap the map again to move it.',
            style: const TextStyle(color: RF.muted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InfoBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CapsLabel('Estimated total'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCount(value: _total, format: peso, style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${widget.cart.values.fold(0, (a, b) => a + b)} items',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    if (eta != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          eta,
                          style: const TextStyle(color: RF.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'COD',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: RF.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(switch (_payment) {
                        'gcash' => 'GCash',
                        'maya' => 'Maya',
                        _ => 'Cash on delivery',
                      }, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GCash and Maya are coming soon'))),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: RF.accent,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: RF.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final e in widget.cart.entries) KeyValueRow('${e.value} × ${e.key.name}', peso(e.key.price * e.value)),
        const KeyValueRow('Delivery fee', 'Free'),
        KeyValueRow('Total', peso(_total), bold: true),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Contact number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes for rider (optional)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
