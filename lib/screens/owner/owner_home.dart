import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/owner_store_billing.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'new_order_alert.dart';
import 'phone_alert.dart';
import 'station_form.dart';
import 'owner_orders.dart';
import 'owner_products.dart';
import 'sales_screen.dart';
import '../network_states.dart';
import '../notifications_screen.dart';

class OwnerHome extends StatefulWidget {
  final Profile profile;
  const OwnerHome({super.key, required this.profile});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  late Future<List<Station>> _f = _load().timeout(const Duration(seconds: 20));
  String? _selectedStationId;
  int _tab = 0;
  VoidCallback? _addProduct;
  StreamSubscription<List<Order>>? _ordersSub;
  final Map<String, String> _seenOrderStatus = {};
  bool _ordersPrimed = false;
  bool _unread = false;
  String? _watchedStationId;

  @override
  void initState() {
    super.initState();
    _loadUnread();
    unawaited(_syncStoreSubscription());
  }

  /// After Apple or Google renews the plan, keep the saved period end in step.
  Future<void> _syncStoreSubscription() async {
    try {
      await OwnerStoreBilling.sync(sb.auth.currentUser?.id);
    } catch (_) {
      // The dashboard still opens if the store cannot be reached.
    }
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    final unread = await Api.hasUnreadNotifications().catchError((_) => false);
    if (mounted) setState(() => _unread = unread);
  }

  void _watchStation(String stationId) {
    if (_watchedStationId == stationId) return;
    _watchedStationId = stationId;
    _ordersPrimed = false;
    _seenOrderStatus.clear();
    _ordersSub?.cancel();
    _ordersSub = Api.watchOrders(stationId: stationId).listen((orders) {
      final result = noticeOrderChanges(seen: _seenOrderStatus, primed: _ordersPrimed, orders: orders);
      _ordersPrimed = result.primed;
      if (!mounted || (result.arrived.isEmpty && result.cancelled.isEmpty)) return;
      final parts = <String>[
        if (result.arrived.isNotEmpty) newOrderMessage(result.arrived),
        if (result.cancelled.isNotEmpty) cancelledOrderMessage(result.cancelled),
      ];
      final message = parts.join(' ');
      final title = result.cancelled.isEmpty
          ? 'New order'
          : result.arrived.isEmpty
              ? 'Order cancelled'
              : 'Order update';
      setState(() => _unread = true);
      showAppNotice(context, message, kind: AppNotice.info);
      showPhoneAlert(title, message);
    }, onError: (_) {});
  }

  void _bindAddProduct(VoidCallback? action) {
    // The new products page mounts before the previous one disposes.
    // Ignoring the clear keeps that dispose from wiping the new action.
    if (action != null) _addProduct = action;
  }

  Future<List<Station>> _load() async {
    final rows = await sb.from('stations').select().eq('owner_id', widget.profile.id).order('name');
    return rows.map(Station.fromMap).toList();
  }

  void _reload() => setState(() => _f = _load().timeout(const Duration(seconds: 20)));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Station>>(
    future: _f,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: SlowLoadingHint()));
      if (snap.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Station unavailable'), actions: [logoutButton()]),
          body: LoadFailureView(error: snap.error!, onRetry: _reload),
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
      _watchStation(s.id);
      final pages = [
        OwnerOrders(key: ValueKey('orders-${s.id}'), station: s),
        OwnerProducts(key: ValueKey('products-${s.id}'), station: s, bindAdd: _bindAddProduct),
        SalesScreen(key: ValueKey('sales-${s.id}'), station: s),
        StationForm(key: ValueKey('station-${s.id}'), ownerId: widget.profile.id, station: s, onSaved: _reload),
      ];
      const items = [(Icons.receipt_long, 'Orders'), (Icons.inventory_2, 'Products'), (Icons.bar_chart, 'Sales'), (Icons.store, 'Station')];
      final wide = MediaQuery.sizeOf(context).width > 800;
      return Scaffold(
        extendBody: !wide,
        appBar: AppBar(
          backgroundColor: RF.bg,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 72,
          title: Column(
            mainAxisSize: MainAxisSize.min,
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
            if (stations.length > 1)
              PopupMenuButton<String>(
                tooltip: 'Select water station',
                icon: const Icon(Icons.storefront_rounded),
                onSelected: (id) => setState(() {
                  _selectedStationId = id;
                  _tab = 0;
                }),
                itemBuilder: (_) => [for (final st in stations) PopupMenuItem(value: st.id, child: Text(st.name))],
              ),
            if (_tab == 1)
              Tooltip(
                message: 'Add product',
                child: CircleIconButton(Icons.add_rounded, onTap: () => _addProduct?.call()),
              ),
            IconButton(
              tooltip: 'Order notifications',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                if (mounted) _loadUnread();
              },
              icon: Badge(
                isLabelVisible: _unread,
                smallSize: 8,
                backgroundColor: RF.accent,
                child: Icon(_unread ? Icons.notifications_active_rounded : Icons.notifications_outlined),
              ),
            ),
            logoutButton(),
            const SizedBox(width: 8),
          ],
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
