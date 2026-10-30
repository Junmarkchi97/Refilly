import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'station_screen.dart';
import 'orders_screen.dart';
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
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: SafeArea(
      bottom: false,
      child: switch (_tab) {
        0 => StationsMap(profile: widget.profile),
        1 => Column(
          children: [
            const PageHeader('Orders', subtitle: 'Track your deliveries live'),
            Expanded(child: OrdersScreen(profile: widget.profile)),
          ],
        ),
        _ => ProfileTab(profile: widget.profile),
      },
    ),
    bottomNavigationBar: FloatingNav(
      index: _tab,
      onTap: (i) => setState(() => _tab = i),
      items: const [(Icons.home_rounded, 'Home'), (Icons.receipt_long_rounded, 'Orders'), (Icons.person_rounded, 'Profile')],
    ),
  );
}

class ProfileTab extends StatelessWidget {
  final Profile profile;
  const ProfileTab({super.key, required this.profile});
  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
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
                subtitle: const Text('Sell water & essentials on Refilly'),
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
  const StationsMap({super.key, required this.profile});
  @override
  State<StationsMap> createState() => _StationsMapState();
}

class _StationsMapState extends State<StationsMap> {
  late Future<List<Station>> _f = Api.stations();

  void _open(Station s) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StationScreen(station: s, profile: widget.profile),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Station>>(
    future: _f,
    builder: (context, snap) => StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(snap.hasData),
        child: Builder(
          builder: (context) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const SkeletonList();
            final stations = snap.data!;
            final open = stations.where((s) => s.isOpen).length;
            final first = (widget.profile.fullName ?? '').split(' ').first;
            return RefreshIndicator(
              onRefresh: () async => setState(() => _f = Api.stations()),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  PageHeader(
                    first.isEmpty ? 'Refilly' : 'Hi, $first',
                    subtitle: 'Fresh water, delivered fast',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), boxShadow: RF.shadow),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.water_drop_rounded, color: RF.accent, size: 18),
                          SizedBox(width: 4),
                          Text('Refilly', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RF.radius),
                      child: SizedBox(
                        height: 260,
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              child: FlutterMap(
                                options: const MapOptions(initialCenter: manila, initialZoom: 11.5),
                                children: [
                                  osmTiles(),
                                  MarkerLayer(
                                    markers: [
                                      for (final s in stations)
                                        pin(
                                          LatLng(s.lat, s.lng),
                                          Icons.water_drop_rounded,
                                          s.isOpen ? RF.accent : RF.muted,
                                          onTap: () => _open(s),
                                        ),
                                    ],
                                  ),
                                  osmAttribution(),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: RF.shadow,
                                ),
                                child: Text('$open open near you', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SectionTitle('Stations'),
                  if (stations.isEmpty)
                    EmptyState(
                      icon: Icons.location_off_rounded,
                      title: 'No stations nearby',
                      subtitle: 'We are adding refilling stations in your area. Pull down to refresh.',
                      actionLabel: 'Refresh',
                      onAction: () => setState(() => _f = Api.stations()),
                    ),
                  for (final (sIdx, s) in (stations).indexed)
                    FadeSlideIn(
                      index: sIdx,
                      child: AppCard(
                        onTap: () => _open(s),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(color: RF.accentSoft, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.water_drop_rounded, color: RF.accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.address ?? '',
                                    style: const TextStyle(color: RF.muted, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(s.isOpen ? 'open' : 'closed'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
