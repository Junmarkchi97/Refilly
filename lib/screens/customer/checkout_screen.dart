import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import '../../services/address_search.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'tracking_screen.dart';
import '../auth/verify_phone_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Station station;
  final Map<Product, int> cart;
  final Profile profile;
  final String? refillRoutineId;
  const CheckoutScreen({super.key, required this.station, required this.cart, required this.profile, this.refillRoutineId});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _address = TextEditingController(), _notes = TextEditingController();
  late final _phone = TextEditingController(text: widget.profile.phone);
  final _map = MapController();
  final _geocoder = AddressSearchService();
  Timer? _addressDebounce;
  int _addressRequestId = 0;
  bool _showAddressSuggestions = false;
  bool _searchingAddress = false;
  String? _addressSearchError;
  List<AddressSuggestion> _addressSuggestions = const [];
  LatLng? _drop;
  final String _payment = 'cod';
  bool _busy = false;
  bool _quoting = false;
  double? _deliveryFee;
  String? _quoteError;
  int _quoteSequence = 0;

  void _onAddressChanged(String input) {
    _addressDebounce?.cancel();
    final requestId = ++_addressRequestId;
    final query = input.trim();
    ++_quoteSequence;
    setState(() {
      // Editing a chosen address invalidates its former pin and delivery quote.
      // This prevents sending an order to a different location from its address.
      _drop = null;
      _deliveryFee = null;
      _quoteError = null;
      _quoting = false;
      _addressSuggestions = const [];
      _addressSearchError = null;
      _showAddressSuggestions = query.length >= 3;
      _searchingAddress = query.length >= 3;
    });
    if (query.length < 3) return;
    _addressDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted || requestId != _addressRequestId) return;
      try {
        final results = await _geocoder.search(query);
        if (!mounted || requestId != _addressRequestId) return;
        setState(() {
          _addressSuggestions = results;
          _searchingAddress = false;
        });
      } catch (_) {
        if (!mounted || requestId != _addressRequestId) return;
        setState(() {
          _searchingAddress = false;
          _addressSearchError = 'Address lookup unavailable. You can pin the map manually.';
        });
      }
    });
  }

  Future<void> _selectAddress(AddressSuggestion suggestion) async {
    _addressDebounce?.cancel();
    ++_addressRequestId;
    FocusScope.of(context).unfocus();
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    setState(() {
      _address.text = suggestion.label;
      _address.selection = TextSelection.collapsed(offset: _address.text.length);
      _showAddressSuggestions = false;
      _searchingAddress = false;
      _addressSuggestions = const [];
      _addressSearchError = null;
    });
    _map.move(point, 16);
    await _setDrop(point);
  }

  double get _grandTotal => _total + (_deliveryFee ?? 0);

  Future<void> _setDrop(LatLng value) async {
    _addressDebounce?.cancel();
    ++_addressRequestId;
    final sequence = ++_quoteSequence;
    setState(() {
      _drop = value;
      _deliveryFee = null;
      _quoteError = null;
      _quoting = true;
      _showAddressSuggestions = false;
      _searchingAddress = false;
    });
    try {
      final fee = await Api.deliveryQuote(widget.station.id, value.latitude, value.longitude);
      if (!mounted || sequence != _quoteSequence) return;
      setState(() { _deliveryFee = fee; _quoting = false; });
    } catch (e) {
      if (!mounted || sequence != _quoteSequence) return;
      setState(() { _quoteError = 'Delivery unavailable: $e'; _quoting = false; });
    }
  }

  double get _total => widget.cart.entries.fold(0, (t, e) => t + e.key.price * e.value);

  Future<void> _useMyLocation() async {
    final p = await LocationService.current();
    if (p == null) return;
    if (!mounted) return;
    await _setDrop(LatLng(p.latitude, p.longitude));
    if (mounted) _map.move(LatLng(p.latitude, p.longitude), 16);
  }

  Future<void> _place() async {
    if (_busy) return;
    if (_deliveryFee == null || _quoting || _quoteError != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a serviceable delivery location first.')));
      return;
    }
    if (_drop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pin your delivery location on the map')));
      return;
    }
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
      if (widget.refillRoutineId != null) {
        try {
          await Api.recordRefillOrder(widget.refillRoutineId!, id);
        } catch (_) {
          // The purchase succeeded; never retry checkout just because the
          // routine schedule could not be updated. The routine can be adjusted later.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TrackingScreen(orderId: id, customerId: widget.profile.id)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    ++_addressRequestId;
    _geocoder.dispose();
    _address.dispose();
    _notes.dispose();
    _phone.dispose();
    _map.dispose();
    super.dispose();
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
        options: MapOptions(initialCenter: LatLng(st.lat - .006, st.lng), initialZoom: 14, onTap: (_, p) => _setDrop(p)),
        children: [
          osmTiles(),
          if (_drop != null)
            PolylineLayer(
              polylines: [
                Polyline(points: [stPt, _drop!], strokeWidth: 4, color: RF.ink),
              ],
            ),
          MarkerLayer(markers: [photoPin(stPt, widget.station.photoUrl), if (_drop != null) dot(_drop!)]),
          osmAttribution(),
        ],
      ),
      bottomBar: Container(
        color: Colors.white,
        child: SafeArea(
          minimum: EdgeInsets.fromLTRB(16, 10, 16, bottomInset(context, 14) - MediaQuery.viewPaddingOf(context).bottom),
          child: Pressable(
            child: FilledButton(onPressed: _busy || _quoting || _deliveryFee == null ? null : _place, child: Text(_busy ? 'Placing order…' : _quoting ? 'Checking delivery area…' : 'Place order · ${peso(_grandTotal)}')),
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
              onChanged: _onAddressChanged,
              textInputAction: TextInputAction.search,
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
        if (_showAddressSuggestions)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchingAddress)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Expanded(child: Text('Searching Philippine addresses…')),
                      ]),
                    )
                  else if (_addressSearchError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_addressSearchError!, style: const TextStyle(color: RF.muted)),
                    )
                  else if (_addressSuggestions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No matches yet. Try a landmark or set the pin on the map.',
                        style: TextStyle(color: RF.muted)),
                    )
                  else
                    for (final result in _addressSuggestions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, color: RF.muted),
                        title: Text(result.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectAddress(result),
                      ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Address suggestions · OpenStreetMap / Photon',
                      style: TextStyle(color: RF.muted, fontSize: 11)),
                  ),
                ],
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
        if (_quoteError != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(_quoteError!, style: const TextStyle(color: Colors.red))),
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
                    AnimatedCount(value: _grandTotal, format: peso, style: Theme.of(context).textTheme.headlineLarge),
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
        for (final e in widget.cart.entries)
          KeyValueRow(
            '${e.value} × ${e.key.name}',
            peso(e.key.price * e.value),
            leading: ProductThumb(e.key.imageUrl, size: 40, radius: 10),
          ),
        KeyValueRow('Delivery fee', _deliveryFee == null ? 'Choose a pin' : _deliveryFee == 0 ? 'Free' : peso(_deliveryFee!)),
        KeyValueRow('Total', peso(_grandTotal), bold: true),
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
