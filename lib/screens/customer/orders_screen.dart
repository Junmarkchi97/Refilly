import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../widgets.dart';
import 'tracking_screen.dart';

class OrdersScreen extends StatelessWidget {
  final Profile profile;
  const OrdersScreen({super.key, required this.profile});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
        stream: Api.watchOrders(customerId: profile.id),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) return const Center(child: Text('No orders yet'));
          return ListView(children: [
            for (final o in snap.data!)
              ListTile(
                title: Text(o.station?['name'] ?? 'Order'),
                subtitle: Text('${o.items.length} item(s) · ${peso(o.total)}'),
                trailing: Chip(label: Text(statusLabel(o.status), style: const TextStyle(fontSize: 11)), backgroundColor: statusColor(o.status).withValues(alpha: .15)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(orderId: o.id, customerId: profile.id))),
              ),
          ]);
        },
      );
}
