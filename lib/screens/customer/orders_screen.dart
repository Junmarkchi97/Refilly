import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'tracking_screen.dart';

class OrdersScreen extends StatelessWidget {
  final Profile profile;
  const OrdersScreen({super.key, required this.profile});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
    stream: Api.watchOrders(customerId: profile.id),
    builder: (context, snap) => StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(snap.hasData),
        child: Builder(
          builder: (context) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const SkeletonList();
            if (snap.data!.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No orders yet',
                subtitle: 'Order water from a station near you and track your rider live here.',
              );
            }
            return ListView(
              padding: EdgeInsets.only(bottom: bottomInset(context, 100)),
              children: [
                for (final (oIdx, o) in (snap.data!).indexed)
                  FadeSlideIn(
                    index: oIdx,
                    child: AppCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackingScreen(orderId: o.id, customerId: profile.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor(o.status).withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              o.status == 'delivered' ? Icons.check_rounded : Icons.local_shipping_rounded,
                              color: statusColor(o.status),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.station?['name'] ?? 'Order',
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${o.items.length} item(s) · ${MaterialLocalizations.of(context).formatShortDate(o.createdAt)}',
                                  style: const TextStyle(color: RF.muted, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                StatusPill(o.status),
                              ],
                            ),
                          ),
                          Text(peso(o.total), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
