import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/delivery_notes.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/checkout_request.dart';
import '../../services/location.dart';
import '../../services/address_search.dart';
import '../../theme.dart';
import '../address_suggestions.dart';
import '../network_states.dart';
import '../widgets.dart';
import 'station_screen.dart';
import 'tracking_screen.dart';
import '../auth/verify_phone_screen.dart';

/// Preferred delivery windows: as soon as possible, then two-hour slots today and tomorrow.
List<String> deliveryWindows(DateTime now) {
  String slot(String day, int start) =>
      '$day, ${clockLabel(DateTime(2000, 1, 1, start))}–${clockLabel(DateTime(2000, 1, 1, start + 2))}';
  final today = <String>[
    for (var h = (now.hour + 2).clamp(8, 24); h + 2 <= 20; h += 2) slot('Today', h),
  ];
  return ['As soon as possible', ...today.take(3), for (final h in const [8, 10, 13, 15]) slot('Tomorrow', h)];
}

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
  late final _address = TextEditingController(text: widget.profile.deliveryAddress ?? '');
  final _notes = TextEditingController();
  late final _phone = TextEditingController(text: widget.profile.phone);
  final _map = MapController();
  final _geocoder = AddressSearchService();
  final _request = CheckoutRequest();
  Timer? _addressDebounce;
  int _addressRequestId = 0;
  bool _showAddressSuggestions = false;
  bool _searchingAddress = false;
  String? _addressSearchError;
  List<AddressSuggestion> _addressSuggestions = const [];
  LatLng? _drop;
  final String _payment = 'cod';
  late final List<String> _windows = deliveryWindows(DateTime.now());
  late String _window = _windows.first;
  bool _doorstep = false;
  late int _empties = _refillCount;
  bool _busy = false;
  bool _quoting = false;
  double? _deliveryFee;
  String? _quoteError;
  int _quoteSequence = 0;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile.hasSavedAddress) {
      final point = LatLng(profile.deliveryLat!, profile.deliveryLng!);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _map.move(point, 16);
        await _setDrop(point);
      });
    }
  }

  void _onAddressChanged(String input) {
    _request.reset();
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
      } catch (e) {
        if (!mounted || requestId != _addressRequestId) return;
        setState(() {
          _searchingAddress = false;
          _addressSearchError = describeFailure(
            e,
            failed: 'Address lookup unavailable. You can pin the map manually.',
          ).message;
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
    _request.reset();
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
      setState(() {
        _quoteError = describeFailure(
          e,
          failed: 'This pin is outside the delivery area, or the quote could not be loaded.',
        ).message;
        _quoting = false;
      });
    }
  }

  double get _total => widget.cart.entries.fold(0, (t, e) => t + e.key.price * e.value);

  int get _refillCount => widget.cart.entries
      .where((e) => !isRiceProduct(e.key.name, unit: e.key.unit) && !isNewContainerProduct(e.key))
      .fold(0, (t, e) => t + e.value);

  bool get _hasWater => widget.cart.keys.any((p) => !isRiceProduct(p.name, unit: p.unit));

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
      showAppNotice(context, 'Choose a serviceable delivery location first.');
      return;
    }
    if (_drop == null) {
      showAppNotice(context, 'Pin your delivery location on the map');
      return;
    }
    if (_address.text.trim().isEmpty) {
      showAppNotice(context, 'Enter a delivery address');
      return;
    }
    if (!Api.phoneVerified && await Api.requirePhoneVerification()) {
      if (!mounted) return;
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => VerifyPhoneScreen(initialPhone: _phone.text)));
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final address = _address.text.trim();
      final lat = _drop?.latitude;
      final lng = _drop?.longitude;
      final id = await Api.placeOrder(
        stationId: widget.station.id,
        cart: widget.cart,
        address: address,
        lat: lat,
        lng: lng,
        phone: _phone.text.trim(),
        notes: DeliveryNotes(
          window: _window,
          handoff: _doorstep ? 'Doorstep' : 'Lobby',
          emptiesToCollect: _empties,
          instructions: _notes.text,
        ).encode(),
        payment: _payment,
        requestId: _request.id,
      );
      if (lat != null && lng != null) {
        try {
          await Api.saveDeliveryAddress(address: address, lat: lat, lng: lng);
        } catch (_) {
          // Order already placed; address save can be retried from Account.
        }
      }
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
      if (mounted) showFailureNotice(context, e, failed: 'Could not place your order.');
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
    final itemCount = widget.cart.values.fold(0, (a, b) => a + b);
    return Scaffold(
      body: Ambient(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(RF.sheetRadius)),
                    boxShadow: [BoxShadow(color: const Color(0xFF32220F).withValues(alpha: .05), blurRadius: 30, offset: const Offset(0, -10))],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Row(
                          children: [
                            FloatIconButton(Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.maybePop(context)),
                            Expanded(
                              child: Text('Confirm delivery', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                            ),
                            const SizedBox(width: 42),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 8),
                        child: Text('Review every charge before you place it', textAlign: TextAlign.center, style: TextStyle(color: RF.muted, fontSize: 13)),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          children: [
                            _supplierRow(st),
                            const SizedBox(height: 6),
                            for (final e in widget.cart.entries) _itemRow(e.key, e.value),
                            const Divider(height: 22),
                            _addressSection(stPt),
                            DetailRow(
                              icon: Icons.schedule_rounded,
                              label: 'Delivery window',
                              value: _window,
                              caption: eta == null ? 'Sent to the supplier with your order' : 'About $eta once dispatched',
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 52, bottom: 4),
                              child: Row(
                                children: [
                                  for (final w in _windows)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(w.replaceFirst('As soon as possible', 'ASAP')),
                                        selected: w == _window,
                                        onSelected: (_) => setState(() => _window = w),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const _Label('Where should we leave it?'),
                            Row(
                              children: [
                                Expanded(child: _handoffChoice(false, Icons.apartment_rounded, 'Lobby')),
                                const SizedBox(width: 8),
                                Expanded(child: _handoffChoice(true, Icons.door_front_door_outlined, 'Doorstep')),
                              ],
                            ),
                            if (_hasWater) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Empty containers to collect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        Text('The rider takes these back', style: TextStyle(color: RF.muted, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  QtyStepper(value: _empties, max: 20, label: 'empty containers', onChanged: (v) => setState(() => _empties = v)),
                                ],
                              ),
                            ],
                            const _Label('Contact number'),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: '09XX XXX XXXX',
                                prefixIcon: Icon(Icons.call_outlined, size: 20, color: RF.muted),
                              ),
                            ),
                            const _Label('Delivery instructions'),
                            TextField(
                              controller: _notes,
                              maxLines: 2,
                              minLines: 1,
                              maxLength: 300,
                              decoration: const InputDecoration(hintText: 'e.g. Call when you arrive. Gate code 1234.', counterText: ''),
                            ),
                          ],
                        ),
                      ),
                      _dock(itemCount),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supplierRow(Station st) => Row(
    children: [
      StationAvatar(st.photoUrl, size: 44),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              '${st.isOpen ? 'Open' : 'Closed'} · Delivers within ${st.deliveryRadiusKm.toStringAsFixed(0)} km',
              style: const TextStyle(color: RF.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _itemRow(Product p, int qty) {
    final (title, size) = splitProductName(p.name);
    final kind = isRiceProduct(p.name, unit: p.unit)
        ? 'Whole sack'
        : isNewContainerProduct(p)
            ? 'With new container'
            : 'Refill only';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ProductArt(name: p.name, unit: p.unit, imageUrl: p.imageUrl, size: 52, radius: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text([?size, kind, '× $qty'].join(' · '), style: const TextStyle(color: RF.muted, fontSize: 13)),
              ],
            ),
          ),
          Text(peso(p.price * qty), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _addressSection(LatLng stPt) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const IconBubble(Icons.location_on_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: AddressSuggestAnchor(
              open: _showAddressSuggestions,
              searching: _searchingAddress,
              error: _addressSearchError,
              suggestions: _addressSuggestions,
              onSelected: _selectAddress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Deliver to', style: TextStyle(color: RF.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                  TextField(
                    controller: _address,
                    onChanged: _onAddressChanged,
                    textInputAction: TextInputAction.search,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'House no., street, barangay, city',
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 150,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _drop ?? stPt,
                  initialZoom: 15,
                  onTap: (_, p) => _setDrop(p),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
                ),
                children: [
                  osmTiles(),
                  MarkerLayer(markers: [if (_drop != null) dot(_drop!, color: RF.accent)]),
                  osmAttribution(),
                ],
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Pressable(
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
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Text(
          _quoteError ??
              (_quoting
                  ? 'Checking that this supplier delivers here…'
                  : _drop == null
                      ? 'Tap the map to pin your exact drop-off.'
                      : 'Drop-off pinned. Tap the map again to move it.'),
          style: TextStyle(color: _quoteError != null ? const Color(0xFFB3261E) : RF.muted, fontSize: 13),
        ),
      ),
    ],
  );

  Widget _handoffChoice(bool doorstep, IconData icon, String label) => SelectCard(
    selected: _doorstep == doorstep,
    onTap: () => setState(() => _doorstep = doorstep),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    ),
  );

  Widget _dock(int itemCount) => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset(context, 14)),
    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEFEAE4)))),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: RF.goodSoft, shape: BoxShape.circle),
              child: const Text('₱', style: TextStyle(color: RF.good, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Pay the rider when it arrives', style: TextStyle(color: RF.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _fee('Items ($itemCount)', peso(_total)),
        _fee(
          'Delivery fee',
          _quoting ? 'Checking…' : _deliveryFee == null ? 'Pin your address' : _deliveryFee == 0 ? 'Free' : peso(_deliveryFee!),
        ),
        const Divider(height: 14),
        Row(
          children: [
            const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            AnimatedCount(value: _grandTotal, format: peso, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Pressable(
            child: FilledButton(
              onPressed: _busy || _quoting || _deliveryFee == null ? null : _place,
              child: Text(
                _busy
                    ? 'Placing order…'
                    : _quoting
                        ? 'Checking delivery area…'
                        : _deliveryFee == null
                            ? 'Pin your address to continue'
                            : 'Place order · ${peso(_grandTotal)}',
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fee(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF3F3B37), fontSize: 14))),
        Text(value, style: const TextStyle(color: Color(0xFF3F3B37), fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3F3B37))),
  );
}

