import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/address_search.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import '../../theme.dart';
import '../address_suggestions.dart';
import '../widgets.dart';

/// Lets a customer save a default delivery address used to autofill checkout.
class SavedAddressScreen extends StatefulWidget {
  final Profile profile;
  const SavedAddressScreen({super.key, required this.profile});
  @override
  State<SavedAddressScreen> createState() => _SavedAddressScreenState();
}

class _SavedAddressScreenState extends State<SavedAddressScreen> {
  late final _address = TextEditingController(text: widget.profile.deliveryAddress ?? '');
  final _map = MapController();
  final _geocoder = AddressSearchService();
  Timer? _debounce;
  int _requestId = 0;
  bool _showSuggestions = false;
  bool _searching = false;
  bool _busy = false;
  String? _searchError;
  List<AddressSuggestion> _suggestions = const [];
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    final lat = widget.profile.deliveryLat;
    final lng = widget.profile.deliveryLng;
    if (lat != null && lng != null) {
      _pin = LatLng(lat, lng);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pin != null) _map.move(_pin!, 16);
      });
    }
  }

  void _onAddressChanged(String input) {
    _debounce?.cancel();
    final requestId = ++_requestId;
    final query = input.trim();
    setState(() {
      _pin = null;
      _suggestions = const [];
      _searchError = null;
      _showSuggestions = query.length >= 3;
      _searching = query.length >= 3;
    });
    if (query.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted || requestId != _requestId) return;
      try {
        final results = await _geocoder.search(query);
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _searching = false;
          _searchError = 'Address lookup unavailable. Pin the map manually.';
        });
      }
    });
  }

  Future<void> _selectSuggestion(AddressSuggestion suggestion) async {
    _debounce?.cancel();
    ++_requestId;
    FocusScope.of(context).unfocus();
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    setState(() {
      _address.text = suggestion.label;
      _address.selection = TextSelection.collapsed(offset: _address.text.length);
      _showSuggestions = false;
      _searching = false;
      _suggestions = const [];
      _searchError = null;
      _pin = point;
    });
    _map.move(point, 16);
  }

  Future<void> _useMyLocation() async {
    final p = await LocationService.current();
    if (p == null || !mounted) return;
    final point = LatLng(p.latitude, p.longitude);
    setState(() => _pin = point);
    _map.move(point, 16);
  }

  Future<void> _save() async {
    final address = _address.text.trim();
    final pin = _pin;
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a delivery address')));
      return;
    }
    if (pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pin your delivery location on the map')));
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await Api.saveDeliveryAddress(address: address, lat: pin.latitude, lng: pin.longitude);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ++_requestId;
    _geocoder.dispose();
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _pin ?? manila;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.only(bottom: bottomInset(context, 100)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery address', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text(
                  'Saved here and filled in automatically when you order.',
                  style: TextStyle(color: RF.muted),
                ),
              ],
            ),
          ),
          FormSection(
            title: 'Address',
            children: [
              AddressSuggestAnchor(
                open: _showSuggestions,
                searching: _searching,
                error: _searchError,
                suggestions: _suggestions,
                onSelected: _selectSuggestion,
                child: TextField(
                  controller: _address,
                  onChanged: _onAddressChanged,
                  textInputAction: TextInputAction.search,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'House no., street, barangay, city',
                    prefixIcon: Icon(Icons.location_on_outlined, color: RF.muted),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: initial,
                          initialZoom: 15,
                          onTap: (_, p) => setState(() => _pin = p),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                          ),
                        ),
                        children: [
                          osmTiles(),
                          MarkerLayer(markers: [if (_pin != null) dot(_pin!, color: RF.accent)]),
                          osmAttribution(),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Material(
                          color: Colors.white,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: _useMyLocation,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.my_location_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Use my location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _pin == null ? 'Tap the map to pin your exact drop-off.' : 'Drop-off pinned. Tap the map again to move it.',
                style: const TextStyle(color: RF.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save address'),
          ),
        ),
      ),
    );
  }
}
