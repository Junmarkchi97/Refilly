import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'tracking_screen.dart';
import 'reorder.dart';
import 'save_refill_routine.dart';
import '../network_states.dart';

class OrdersScreen extends StatefulWidget {
  final Profile profile;
  const OrdersScreen({super.key, required this.profile});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Stream<List<Order>> _orders = Api.watchOrders(customerId: widget.profile.id);

  void _retry() => setState(() => _orders = Api.watchOrders(customerId: widget.profile.id));

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Order>>(
    stream: _orders,
    builder: (context, snap) => StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(snap.hasData),
        child: Builder(
          builder: (context) {
            if (snap.hasError) return LoadFailureView(error: snap.error!, onRetry: _retry);
            if (!snap.hasData) return const Column(children: [SlowLoadingHint(), Expanded(child: SkeletonList())]);
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
                          builder: (_) => TrackingScreen(orderId: o.id, customerId: widget.profile.id),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                          (o.station?['photo_url'] as String?)?.isNotEmpty ?? false
                              ? Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    StationAvatar(o.station!['photo_url'], size: 48),
                                    Positioned(
                                      right: -3,
                                      bottom: -3,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(color: statusColor(o.status), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                        child: Icon(o.status == 'delivered' ? Icons.check_rounded : Icons.local_shipping_rounded, size: 11, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
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
                          ]),
                          if (o.status == 'delivered') ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => saveRoutineFromOrder(context, o),
                              icon: const Icon(Icons.event_repeat_rounded),
                              label: const Text('Save to My Essentials'),
                            ),
                          ],
                          if (o.status == 'delivered' || o.status == 'cancelled') ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => startReorder(context, o, widget.profile),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reorder'),
                            ),
                          ],
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
