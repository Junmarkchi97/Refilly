import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/location.dart';
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
  String _payment = 'cod';
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(orderId: id, customerId: widget.profile.id)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final e in widget.cart.entries)
            ListTile(dense: true, title: Text('${e.value} × ${e.key.name}'), trailing: Text(peso(e.key.price * e.value))),
          ListTile(title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text(peso(_total))),
          const Divider(),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Delivery address (house no., street, barangay)')),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Contact number')),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes for rider (optional)')),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Tap the map to pin your drop-off')),
            TextButton.icon(onPressed: _useMyLocation, icon: const Icon(Icons.my_location), label: const Text('Use my location')),
          ]),
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: LatLng(widget.station.lat, widget.station.lng),
                initialZoom: 14,
                onTap: (_, p) => setState(() => _drop = p),
              ),
              children: [
                osmTiles(),
                MarkerLayer(markers: [
                  pin(LatLng(widget.station.lat, widget.station.lng), Icons.store, Colors.blue),
                  if (_drop != null) pin(_drop!, Icons.location_pin, Colors.red),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Payment'),
          RadioGroup<String>(
            groupValue: _payment,
            onChanged: (v) => setState(() => _payment = v!),
            child: const Column(children: [
              RadioListTile(value: 'cod', title: Text('Cash on delivery')),
              RadioListTile(value: 'gcash', title: Text('GCash (coming soon)'), enabled: false),
              RadioListTile(value: 'maya', title: Text('Maya (coming soon)'), enabled: false),
            ]),
          ),
          FilledButton(onPressed: _busy ? null : _place, child: Text('Place order · ${peso(_total)}')),
        ]),
      );
}
