import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'station_form.dart';
import 'owner_orders.dart';
import 'owner_products.dart';
import 'sales_screen.dart';

class OwnerHome extends StatefulWidget {
  final Profile profile;
  const OwnerHome({super.key, required this.profile});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  late Future<Station?> _f = _load();
  int _tab = 0;

  Future<Station?> _load() async {
    final r = await sb.from('stations').select().eq('owner_id', widget.profile.id).limit(1).maybeSingle();
    return r == null ? null : Station.fromMap(r);
  }

  void _reload() => setState(() => _f = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<Station?>(
    future: _f,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final s = snap.data;
      if (s == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('No station yet'), actions: [logoutButton()]),
          body: const Center(child: Text('Your station is created when an admin approves your application.')),
        );
      }
      final pages = [
        OwnerOrders(station: s),
        OwnerProducts(station: s),
        SalesScreen(station: s),
        StationForm(ownerId: widget.profile.id, station: s, onSaved: _reload),
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
          actions: [logoutButton(), const SizedBox(width: 8)],
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
