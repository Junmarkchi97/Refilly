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
import '../notifications_screen.dart';
import '../brand.dart';
import 'apply_owner_screen.dart';
import 'home_tab.dart';
import '../auth/verify_phone_screen.dart';
import 'saved_address_screen.dart';

class CustomerHome extends StatefulWidget {
  final Profile profile;
  const CustomerHome({super.key, required this.profile});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  late Profile _profile = widget.profile;
  int _tab = 0;
  int _routineRefresh = 0;

  void _go(int tab) => setState(() {
    _tab = tab;
    if (tab == 0) _routineRefresh++;
  });

  void _setProfile(Profile profile) => setState(() => _profile = profile);

  Future<void> _editAddress() async {
    final updated = await Navigator.push<Profile>(
      context,
      MaterialPageRoute(builder: (_) => SavedAddressScreen(profile: _profile)),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _profile = updated;
      _tab = 3;
    });
    showAppNotice(context, 'Address updated', kind: AppNotice.success);
  }

  Widget get _nav => FloatingNav(
    index: _tab,
    onTap: _go,
    items: const [
      (Icons.home_outlined, 'Home'),
      (Icons.repeat_rounded, 'Essentials'),
      (Icons.receipt_long_outlined, 'Orders'),
      (Icons.person_outline_rounded, 'Account'),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: Ambient(
      child: SafeArea(
        bottom: false,
        child: switch (_tab) {
          0 => HomeTab(
              key: ValueKey('${_routineRefresh}_${_profile.deliveryAddress}'),
              profile: _profile,
              onEssentials: () => _go(1),
              onOrders: () => _go(2),
              onEditAddress: _editAddress,
            ),
          1 => MyEssentialsScreen(
              profile: _profile,
              onExplore: () => openStations(context, _profile),
              onOrders: () => _go(2),
            ),
          2 => Column(
              children: [
                const PageHeader('Orders', subtitle: 'Track, reorder and save your essentials'),
                Expanded(child: OrdersScreen(profile: _profile)),
              ],
            ),
          _ => ProfileTab(profile: _profile, onProfileChanged: _setProfile),
        },
      ),
    ),
    bottomNavigationBar: _nav,
  );
}

/// Opens the supplier map. With [category] (e.g. 'rice') only stations selling it are listed.
void openStations(BuildContext context, Profile profile, {String? category}) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => StationsMap(profile: profile, category: category)),
);

class ProfileTab extends StatelessWidget {
  final Profile profile;
  final ValueChanged<Profile> onProfileChanged;
  const ProfileTab({super.key, required this.profile, required this.onProfileChanged});
  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Future<void> editAddress() async {
      final updated = await Navigator.push<Profile>(
        context,
        MaterialPageRoute(builder: (_) => SavedAddressScreen(profile: profile)),
      );
      if (updated == null || !context.mounted) return;
      onProfileChanged(updated);
      showAppNotice(context, 'Address updated', kind: AppNotice.success);
    }

    final addressSubtitle = profile.hasSavedAddress
        ? profile.deliveryAddress!
        : 'Add an address for faster checkout';

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
        AppCard(
          child: ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Delivery address'),
            subtitle: Text(addressSubtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: editAddress,
          ),
        ),
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
  final String? category;
  const StationsMap({super.key, required this.profile, this.category});
  @override
  State<StationsMap> createState() => _StationsMapState();
}

class _StationsMapState extends State<StationsMap> {
  late Future<List<Station>> _f = _load();
  final _q = TextEditingController();
  final _map = MapController();

  Future<List<Station>> _load() async {
    final stations = await Api.stations().timeout(const Duration(seconds: 20));
    final slug = widget.category;
    if (slug == null) return stations;
    final ids = await Api.stationIdsWithCategory(slug).timeout(const Duration(seconds: 20));
    return stations.where((s) => ids.contains(s.id)).toList();
  }

  void _reload() => setState(() => _f = _load());

  void _open(Station s) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StationScreen(station: s, profile: widget.profile, initialCategorySlug: widget.category),
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
      final rice = widget.category == 'rice';
      return MapSheetScaffold(
        initial: .52,
        min: .22,
        topLeft: MapButton(Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
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
              Expanded(child: Text(rice ? 'Rice suppliers' : 'Choose a supplier', style: Theme.of(context).textTheme.headlineSmall)),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search suppliers or areas',
                fillColor: RF.bg,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: const BorderSide(color: RF.accent, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: RF.ink),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (snap.hasError) LoadFailureView(compact: true, error: snap.error!, onRetry: _reload),
          if (!snap.hasData && !snap.hasError) const Column(children: [SlowLoadingHint(), SkeletonList(count: 3, height: 60)]),
          if (snap.hasData && shown.isEmpty)
            EmptyState(
              icon: rice ? Icons.rice_bowl_outlined : Icons.location_off_rounded,
              title: q.isNotEmpty ? 'No matches' : rice ? 'Rice is coming soon' : 'No suppliers nearby',
              subtitle: q.isNotEmpty
                  ? 'Try another supplier name or area.'
                  : rice
                      ? 'No supplier near you sells rice on Refilly yet. Water refills are available now.'
                      : 'We are adding suppliers in your area.',
              actionLabel: 'Refresh',
              onAction: _reload,
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
