import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'station_form.dart';
import 'owner_orders.dart';
import 'owner_products.dart';
import 'sales_screen.dart';
import '../notifications_screen.dart';

class OwnerHome extends StatefulWidget {
  final Profile profile;
  const OwnerHome({super.key, required this.profile});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  late Future<List<Station>> _f = _load();
  String? _selectedStationId;
  int _tab = 0;

  Future<List<Station>> _load() async {
    final rows = await sb.from('stations').select().eq('owner_id', widget.profile.id).order('name');
    return rows.map(Station.fromMap).toList();
  }

  void _reload() => setState(() => _f = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Station>>(
    future: _f,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snap.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Station unavailable'), actions: [logoutButton()]),
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load your station.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reload, child: const Text('Retry')),
          ])),
        );
      }
      final stations = snap.data ?? <Station>[];
      if (stations.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('No station yet'), actions: [logoutButton()]),
          body: const Center(child: Text('Your station is created when an admin approves your application.')),
        );
      }
      final s = stations.where((item) => item.id == _selectedStationId).firstOrNull ?? stations.first;
      final pages = [
        OwnerOrders(key: ValueKey('orders-${s.id}'), station: s),
        OwnerProducts(key: ValueKey('products-${s.id}'), station: s),
        SalesScreen(key: ValueKey('sales-${s.id}'), station: s),
        StationForm(key: ValueKey('station-${s.id}'), ownerId: widget.profile.id, station: s, onSaved: _reload),
      ];
      const items = [(Icons.receipt_long, 'Orders'), (Icons.inventory_2, 'Products'), (Icons.bar_chart, 'Sales'), (Icons.store, 'Station')];
      final wide = MediaQuery.sizeOf(context).width > 800;
      return Scaffold(
        extendBody: !wide,
        appBar: AppBar(
          toolbarHeight: 72,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(items[_tab].$2, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                s.name,
                style: const TextStyle(fontSize: 13, color: RF.muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
             if (stations.length > 1) PopupMenuButton<String>(
               tooltip: 'Select water station',
               icon: const Icon(Icons.storefront_rounded),
               onSelected: (id) => setState(() { _selectedStationId = id; _tab = 0; }),
               itemBuilder: (_) => [for (final st in stations) PopupMenuItem(value: st.id, child: Text(st.name))],
             ),
             IconButton(tooltip: 'Order notifications', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), icon: const Icon(Icons.notifications_outlined)), logoutButton(), const SizedBox(width: 8)],
        ),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    backgroundColor: RF.bg,
                    indicatorColor: RF.ink,
                    selectedIconTheme: const IconThemeData(color: Colors.white),
                    selectedIndex: _tab,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: [for (final i in items) NavigationRailDestination(icon: Icon(i.$1), label: Text(i.$2))],
                  ),
                  Expanded(child: pages[_tab]),
                ],
              )
            : pages[_tab],
        bottomNavigationBar: wide ? null : FloatingNav(index: _tab, onTap: (i) => setState(() => _tab = i), items: items),
      );
    },
  );
}
