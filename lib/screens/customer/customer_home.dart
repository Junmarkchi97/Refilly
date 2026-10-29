import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';
import 'station_screen.dart';
import 'orders_screen.dart';

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
        appBar: AppBar(title: Text(_tab == 0 ? 'Stations near you' : 'My orders'), actions: [logoutButton()]),
        body: _tab == 0 ? StationsMap(profile: widget.profile) : OrdersScreen(profile: widget.profile),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map), label: 'Stations'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          ],
        ),
      );
}

class StationsMap extends StatefulWidget {
  final Profile profile;
  const StationsMap({super.key, required this.profile});
  @override
  State<StationsMap> createState() => _StationsMapState();
}

class _StationsMapState extends State<StationsMap> {
  late Future<List<Station>> _f = Api.stations();

  void _open(Station s) => Navigator.push(context, MaterialPageRoute(builder: (_) => StationScreen(station: s, profile: widget.profile)));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Station>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final stations = snap.data!;
          return Column(children: [
            Expanded(
              flex: 3,
              child: FlutterMap(
                options: const MapOptions(initialCenter: manila, initialZoom: 12),
                children: [
                  osmTiles(),
                  MarkerLayer(markers: [
                    for (final s in stations)
                      pin(LatLng(s.lat, s.lng), Icons.water_drop, s.isOpen ? Colors.blue : Colors.grey, onTap: () => _open(s)),
                  ]),
                  osmAttribution(),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: RefreshIndicator(
                onRefresh: () async => setState(() => _f = Api.stations()),
                child: ListView(children: [
                  for (final s in stations)
                    ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(s.name),
                      subtitle: Text(s.address ?? ''),
                      trailing: Text(s.isOpen ? 'Open' : 'Closed', style: TextStyle(color: s.isOpen ? Colors.green : Colors.grey)),
                      onTap: () => _open(s),
                    ),
                ]),
              ),
            ),
          ]);
        },
      );
}
