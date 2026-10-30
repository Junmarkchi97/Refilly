import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'station_screen.dart';
import '../network_states.dart';
import '../../services/location.dart';
import 'orders_screen.dart';
import 'my_essentials_screen.dart';
import 'app_drawer.dart';
import '../notifications_screen.dart';
import '../brand.dart';
import 'apply_owner_screen.dart';
import '../auth/verify_phone_screen.dart';

class CustomerHome extends StatefulWidget {
  final Profile profile;
  const CustomerHome({super.key, required this.profile});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;
  int _routineRefresh = 0;

  void _go(int tab) => setState(() {
    _tab = tab;
    if (tab == 0) _routineRefresh++;
  });

  Widget get _nav => FloatingNav(
    index: _tab,
    onTap: _go,
    items: const [
      (Icons.repeat_rounded, 'Essentials'),
      (Icons.storefront_rounded, 'Explore'),
      (Icons.receipt_long_rounded, 'Orders'),
      (Icons.person_rounded, 'Account'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_tab == 1) {
      return StationsMap(
        profile: widget.profile,
        bottomBar: _nav,
        onMenu: () => showAppDrawer(
          context, widget.profile,
          onOrders: () => _go(2),
          onAccount: () => _go(3),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (_tab) {
          0 => MyEssentialsScreen(
              key: ValueKey(_routineRefresh),
              profile: widget.profile,
              onExplore: () => _go(1),
              onOrders: () => _go(2),
            ),
          2 => Column(
              children: [
                const PageHeader('Orders', subtitle: 'Track, reorder and save your essentials'),
                Expanded(child: OrdersScreen(profile: widget.profile)),
              ],
            ),
          _ => ProfileTab(profile: widget.profile),
        },
      ),
      bottomNavigationBar: _nav,
    );
  }
}

class ProfileTab extends StatelessWidget {
  final Profile profile;
  const ProfileTab({super.key, required this.profile});
  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return ListView(
      padding: EdgeInsets.only(bottom: bottomInset(context, 100)),
      children: [
        const PageHeader('Profile'),
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: RF.ink,
                child: Text(
                  (profile.fullName ?? '?').characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName ?? 'Customer', style: Theme.of(context).textTheme.titleLarge),
                    Text(sb.auth.currentUser?.email ?? '', style: const TextStyle(color: RF.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Account'),
        AppCard(child: ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Order notifications'),
          subtitle: const Text('Updates on your orders'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => go(const NotificationsScreen()),
        )),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_rounded),
                title: const Text('Verify my phone', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(Api.phoneVerified ? 'Verified' : 'Not verified yet'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => go(VerifyPhoneScreen(initialPhone: profile.phone)),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.storefront_rounded),
                title: const Text('Become a station owner', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Start selling to customers nearby'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => go(const ApplyOwnerScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () => sb.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ),
      ],
    );
  }
}

class StationsMap extends StatefulWidget {
  final Profile profile;
  final Widget? bottomBar;
  final VoidCallback? onMenu;
  const StationsMap({super.key, required this.profile, this.bottomBar, this.onMenu});
  @override
  State<StationsMap> createState() => _StationsMapState();
}

class _StationsMapState extends State<StationsMap> {
  late Future<List<Station>> _f = Api.stations().timeout(const Duration(seconds: 20));
  final _q = TextEditingController();
  final _map = MapController();

  void _open(Station s) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StationScreen(station: s, profile: widget.profile),
    ),
  );

  Future<void> _locate() async {
    final p = await LocationService.current();
    if (p != null) _map.move(LatLng(p.latitude, p.longitude), 14);
  }

  @override
  void dispose() {
    _q.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Station>>(
    future: _f,
    builder: (context, snap) {
      final stations = snap.data ?? const <Station>[];
      final q = _q.text.trim().toLowerCase();
      final shown = q.isEmpty
          ? stations
          : stations.where((s) => s.name.toLowerCase().contains(q) || (s.address ?? '').toLowerCase().contains(q)).toList();
      return MapSheetScaffold(
        bottomBar: widget.bottomBar,
        initial: .46,
        min: .22,
        topLeft: MapButton(Icons.menu_rounded, onTap: widget.onMenu ?? () => setState(() => _f = Api.stations().timeout(const Duration(seconds: 20)))),
        topRight: MapButton(Icons.my_location_rounded, label: 'Locate', onTap: _locate),
        map: FlutterMap(
          mapController: _map,
          options: const MapOptions(initialCenter: manila, initialZoom: 12),
          children: [
            osmTiles(),
            MarkerLayer(
              markers: [
                for (final s in shown)
                  photoPin(LatLng(s.lat, s.lng), s.photoUrl, dim: !s.isOpen, onTap: () => _open(s)),
              ],
            ),
            osmAttribution(),
          ],
        ),
        sheet: (_) => [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const RefillyMark(size: 42),
              const SizedBox(width: 12),
              Expanded(child: Text('Explore nearby', style: Theme.of(context).textTheme.headlineSmall)),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search local stores or areas',
                prefixIcon: const Icon(Icons.search_rounded, color: RF.ink),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (snap.hasError) LoadFailureView(compact: true, error: snap.error!, onRetry: () => setState(() => _f = Api.stations().timeout(const Duration(seconds: 20)))),
          if (!snap.hasData && !snap.hasError) const Column(children: [SlowLoadingHint(), SkeletonList(count: 3, height: 60)]),
          if (snap.hasData && shown.isEmpty)
            EmptyState(
              icon: Icons.location_off_rounded,
              title: q.isEmpty ? 'No stations nearby' : 'No matches',
              subtitle: q.isEmpty ? 'We are adding refilling stations in your area.' : 'Try another station name or area.',
              actionLabel: 'Refresh',
              onAction: () => setState(() => _f = Api.stations().timeout(const Duration(seconds: 20))),
            ),
          for (final (i, s) in shown.indexed)
            FadeSlideIn(
              index: i,
              child: PlaceRow(
                icon: Icons.water_drop_rounded,
                photoUrl: s.photoUrl,
                title: s.name,
                subtitle: s.address,
                trailing: StatusPill(s.isOpen ? 'open' : 'closed'),
                onTap: () => _open(s),
              ),
            ),
        ],
      );
    },
  );
}
