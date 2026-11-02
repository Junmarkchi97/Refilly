import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/delivery_notes.dart';
import '../../models/models.dart';
import '../../models/refill_routine.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../network_states.dart';
import '../notifications_screen.dart';
import '../widgets.dart';
import 'customer_home.dart';
import 'profile_photo.dart';
import 'reorder.dart';
import 'station_screen.dart';
import 'tracking_screen.dart';

const _active = ['pending', 'accepted', 'preparing', 'out_for_delivery'];

/// Which hero to show above the categories on Home.
///
/// Waiting for the first orders snapshot must not flash the empty "Order now"
/// card when the customer already has an active delivery.
enum HomeOrdersHero { loading, empty, upcoming }

HomeOrdersHero homeOrdersHero(AsyncSnapshot<List<Order>> snap) {
  if (!snap.hasData) return HomeOrdersHero.loading;
  final upcoming = snap.data!.where((o) => _active.contains(o.status));
  return upcoming.isEmpty ? HomeOrdersHero.empty : HomeOrdersHero.upcoming;
}

class HomeTab extends StatefulWidget {
  final Profile profile;
  final VoidCallback onEssentials, onOrders;
  final VoidCallback? onEditAddress;
  const HomeTab({
    super.key,
    required this.profile,
    required this.onEssentials,
    required this.onOrders,
    this.onEditAddress,
  });
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final Stream<List<Order>> _orders = Api.watchOrders(customerId: widget.profile.id);
  late Future<List<Station>> _stations = Api.stations().timeout(const Duration(seconds: 20));
  late Future<List<(RefillRoutine, Order?)>> _essentials = _loadEssentials();
  late Future<bool> _unread = Api.hasUnreadNotifications().catchError((_) => false);
  final Set<String> _working = {};

  Future<List<(RefillRoutine, Order?)>> _loadEssentials() async {
    final routines = await Api.refillRoutines().timeout(const Duration(seconds: 20));
    return Future.wait(routines.take(3).map((r) async => (r, await Api.orderById(r.sourceOrderId))));
  }

  Future<void> _refresh() async {
    setState(() {
      _stations = Api.stations().timeout(const Duration(seconds: 20));
      _essentials = _loadEssentials();
      _unread = Api.hasUnreadNotifications().catchError((_) => false);
    });
    try {
      await Future.wait([_stations, _essentials]);
    } catch (_) {}
  }

  String get _firstName {
    final name = widget.profile.fullName?.trim() ?? '';
    return name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
  }

  void _openStations({String? category}) => openStations(context, widget.profile, category: category);

  void _openStation(Station s) => Navigator.push(context, MaterialPageRoute(builder: (_) => StationScreen(station: s, profile: widget.profile)));

  Future<void> _refill(RefillRoutine routine, Order order) async {
    if (_working.contains(routine.id)) return;
    setState(() => _working.add(routine.id));
    try {
      await startReorder(context, order, widget.profile, routine: routine);
    } finally {
      if (mounted) setState(() => _working.remove(routine.id));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
    stream: _orders,
    builder: (context, orderSnap) {
      final orders = orderSnap.data ?? const <Order>[];
      final upcoming = orders.where((o) => _active.contains(o.status)).toList();
      final lastOrderAddress = orders.where((o) => o.deliveryAddress.isNotEmpty).firstOrNull;
      final hero = homeOrdersHero(orderSnap);
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset(context, 110)),
          children: [
            _header(lastOrderAddress),
            const SizedBox(height: 26),
            Text('Hey $_firstName', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text(
              'Let’s keep your home stocked.',
              style: TextStyle(fontSize: 22, height: 1.2, letterSpacing: -.6, fontWeight: FontWeight.w500, color: Color(0xFF2A2724)),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              index: 0,
              child: switch (hero) {
                HomeOrdersHero.loading => const SizedBox(
                  height: 72,
                  child: SkeletonList(count: 1, height: 72),
                ),
                HomeOrdersHero.empty => _startOrderCard(),
                HomeOrdersHero.upcoming => Column(
                  children: [
                    for (final order in upcoming.take(4))
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: _upcomingCard(order)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: _openStations, child: const Text('Place another order')),
                    ),
                  ],
                ),
              },
            ),
            const SizedBox(height: 14),
            FadeSlideIn(index: 1, child: _categories()),
            SectionHeader('Your essentials', action: 'See all', onAction: widget.onEssentials),
            FadeSlideIn(index: 2, child: _essentialsList()),
            SectionHeader('Nearby suppliers', action: 'Browse', onAction: _openStations),
            _suppliers(lastOrderAddress),
          ],
        ),
      );
    },
  );

  String? get _savedLabel {
    final saved = widget.profile.deliveryAddress?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return null;
  }

  Widget _header(Order? lastOrderAddress) {
    final label = _savedLabel ?? lastOrderAddress?.deliveryAddress;
    return Row(
      children: [
        ProfileAvatar(
          profile: widget.profile,
          radius: 23,
          background: const Color(0xFFF3D2C0),
          foreground: const Color(0xFF6A3A28),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onEditAddress ??
                () => showAppNotice(
                      context,
                      'Update your address in Account, or confirm it at checkout.',
                      kind: AppNotice.info,
                    ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deliver to', style: TextStyle(color: RF.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label == null ? 'Add in Account' : label.split(',').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -.3),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<bool>(
          future: _unread,
          builder: (context, snap) => FloatIconButton(
            Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badge: snap.data ?? false,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              if (mounted) setState(() => _unread = Api.hasUnreadNotifications().catchError((_) => false));
            },
          ),
        ),
        const SizedBox(width: 8),
        FloatIconButton(Icons.shopping_bag_outlined, tooltip: 'Start an order', onTap: _openStations),
      ],
    );
  }

  Widget _upcomingCard(Order o) {
    final notes = DeliveryNotes.parse(o.notes);
    final first = o.items.firstOrNull;
    final count = o.items.fold(0, (a, b) => a + b.quantity);
    final title = notes.window ?? switch (o.status) {
      'pending' => 'Waiting for the station',
      'out_for_delivery' => 'On the way now',
      _ => 'Arriving soon',
    };
    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TrackingScreen(orderId: o.id, customerId: widget.profile.id)),
      ),
      child: Row(
        children: [
          ProductArt(name: first?.productName ?? 'Water', imageUrl: first?.imageUrl, size: 52, radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -.3)),
                const SizedBox(height: 2),
                Text(
                  '$count item${count == 1 ? '' : 's'} · ${o.station?['name'] ?? 'Your station'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: RF.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          o.status == 'pending'
              ? Tag(friendlyStatus(o.status).split(' ').first)
              : Tag(friendlyStatus(o.status), background: RF.accentSoft, foreground: RF.accentInk),
        ],
      ),
    );
  }

  Widget _startOrderCard() => SoftCard(
    radius: 22,
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    child: Row(
      children: [
        const ProductArt(name: 'Purified water', size: 52, radius: 14),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No delivery scheduled', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -.3)),
              SizedBox(height: 2),
              Text('Order a refill in a few taps', style: TextStyle(color: RF.muted, fontSize: 13)),
            ],
          ),
        ),
        Pressable(
          child: FilledButton(
            onPressed: _openStations,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            child: const Text('Order now'),
          ),
        ),
      ],
    ),
  );

  Widget _categories() => Row(
    children: [
      Expanded(
        child: _CategoryCard(
          title: 'Water refills',
          subtitle: 'Round, slim and alkaline',
          asset: 'assets/products/jug-round.jpg',
          onTap: _openStations,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _CategoryCard(
          title: 'Rice',
          subtitle: '5, 10 and 25 kg sacks',
          asset: 'assets/products/rice-10.jpg',
          onTap: () => _openStations(category: 'rice'),
        ),
      ),
    ],
  );

  Widget _essentialsList() => FutureBuilder<List<(RefillRoutine, Order?)>>(
    future: _essentials,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SizedBox(height: 132, child: SkeletonList(count: 2, height: 56));
      }
      final items = (snap.data ?? const []).where((e) => e.$2 != null).toList();
      if (snap.hasError || items.isEmpty) {
        return SoftCard(
          child: Row(
            children: [
              const IconBubble(Icons.event_repeat_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  snap.hasError
                      ? describeFailure(snap.error!, failed: 'Your saved essentials could not load. Pull down to retry.').message
                      : 'After a delivery, save it here for one-tap refills.',
                  style: const TextStyle(color: RF.muted, fontSize: 14, height: 1.35),
                ),
              ),
            ],
          ),
        );
      }
      return SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, (routine, order)) in items.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
              _essentialRow(routine, order!),
            ],
          ],
        ),
      );
    },
  );

  Widget _essentialRow(RefillRoutine routine, Order order) {
    final first = order.items.firstOrNull;
    final qty = order.items.fold(0, (a, b) => a + b.quantity);
    final days = routine.daysUntil(DateTime.now());
    final due = days < 0 ? 'Overdue' : days == 0 ? 'Due today' : 'Due ${shortDate(routine.nextDueOn).split(', ').last}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      child: Row(
        children: [
          ProductArt(name: first?.productName ?? 'Water', imageUrl: first?.imageUrl, size: 52, radius: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first?.productName ?? (order.station?['name'] ?? 'Saved refill').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -.2),
                ),
                const SizedBox(height: 2),
                Text('Usual $qty · $due', style: TextStyle(color: days <= 0 ? RF.accentInk : RF.muted, fontSize: 13)),
              ],
            ),
          ),
          Pressable(
            child: FilledButton(
              onPressed: _working.contains(routine.id) ? null : () => _refill(routine, order),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: const Text('Refill now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suppliers(Order? lastOrderAddress) => FutureBuilder<List<Station>>(
    future: _stations,
    builder: (context, snap) {
      if (snap.hasError) {
        return Text(
          describeFailure(snap.error!, failed: 'Suppliers could not load. Pull down to retry.').message,
          style: const TextStyle(color: RF.muted),
        );
      }
      if (!snap.hasData) return const SizedBox(height: 80, child: SkeletonList(count: 2, height: 30));
      final profile = widget.profile;
      final from = profile.hasSavedAddress
          ? LatLng(profile.deliveryLat!, profile.deliveryLng!)
          : lastOrderAddress?.deliveryLat == null || lastOrderAddress?.deliveryLng == null
              ? null
              : LatLng(lastOrderAddress!.deliveryLat!, lastOrderAddress.deliveryLng!);
      final distance = const Distance();
      double? km(Station s) => from == null ? null : distance.as(LengthUnit.Meter, from, LatLng(s.lat, s.lng)) / 1000;
      final list = [...snap.data!];
      if (from != null) list.sort((a, b) => km(a)!.compareTo(km(b)!));
      final shown = list.take(3).toList();
      if (shown.isEmpty) {
        return const Text('We are adding suppliers in your area.', style: TextStyle(color: RF.muted));
      }
      return Column(
        children: [
          for (final s in shown)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openStation(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -.2)),
                    ),
                    if (km(s) != null)
                      Text('${km(s)!.toStringAsFixed(1)} km', style: const TextStyle(color: RF.muted, fontSize: 13)),
                    const SizedBox(width: 10),
                    Text(
                      s.isOpen ? 'Open' : 'Closed',
                      style: TextStyle(color: s.isOpen ? RF.good : RF.muted, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CategoryCard extends StatelessWidget {
  final String title, subtitle, asset;
  final VoidCallback onTap;
  const _CategoryCard({required this.title, required this.subtitle, required this.asset, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. $subtitle',
    child: Pressable(
      scale: .97,
      child: Container(
        height: 158,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: RF.shadow),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -44,
                  bottom: -34,
                  width: 184,
                  height: 184,
                  child: Image.asset(asset, fit: BoxFit.contain, cacheWidth: (184 * MediaQuery.devicePixelRatioOf(context)).round()),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Color(0xEBFFFFFF), Color(0x00FFFFFF)],
                        stops: [.22, .38, .64],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  right: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -.3)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: RF.muted, fontSize: 13, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
