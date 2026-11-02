import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_notes.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../widgets.dart';
import '../network_states.dart';
import 'reorder.dart';
import 'save_refill_routine.dart';

/// Live order status + rider position (Supabase Realtime), Glide-style.
Future<void> _reviewStation(BuildContext context, Order order) async {
  int rating = 5;
  final note = TextEditingController();
  try {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Rate your water station'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(children: [for (var n = 1; n <= 5; n++) IconButton(
            tooltip: '$n stars',
            icon: Icon(n <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
            onPressed: () => setDialogState(() => rating = n),
          )]),
          TextField(controller: note, maxLength: 1000, maxLines: 3, decoration: const InputDecoration(hintText: 'Optional feedback')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
        ],
      )),
    );
    if (approved != true) return;
    await Api.submitReview(order, rating, note.text);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for reviewing the station!')));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This order may already have a review.')));
  } finally {
    note.dispose();
  }
}

Future<void> _cancel(BuildContext context, Order o) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: const Text('Your order will be cancelled and the supplier will be notified. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep order')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Cancel order'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await Api.cancelOrder(o.id);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel order: $e')));
  }
}

Future<void> _reorder(BuildContext context, Order o) async {
  try {
    final profile = await Api.me();
    if (!context.mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to reorder.')));
      return;
    }
    await startReorder(context, o, profile);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not prepare your reorder. Please retry.')));
    }
  }
}

/// Order progress as a timeline, with live status and rider updates via Supabase Realtime.
class TrackingScreen extends StatelessWidget {
  final String orderId, customerId;
  const TrackingScreen({super.key, required this.orderId, required this.customerId});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Ambient(
      child: SafeArea(
        child: StreamBuilder<Order?>(
          stream: Api.watchOrder(orderId),
          builder: (context, snap) {
            final Widget body;
            if (snap.hasError) {
              body = LoadFailureView(
                error: snap.error!,
                onRetry: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => TrackingScreen(orderId: orderId, customerId: customerId)),
                ),
              );
            } else if (snap.connectionState == ConnectionState.waiting) {
              body = const Center(child: SlowLoadingHint());
            } else if (snap.data == null) {
              body = const EmptyState(icon: Icons.search_off_rounded, title: 'Order not found', subtitle: 'It may have been removed.');
            } else {
              final o = snap.data!;
              body = StreamBuilder<Map<String, dynamic>?>(
                stream: o.status == 'out_for_delivery' ? Api.watchRider(o.id) : const Stream.empty(),
                builder: (context, rs) => _Progress(order: o, rider: rs.data),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      FloatIconButton(Icons.arrow_back_ios_new_rounded, tooltip: 'Back', onTap: () => Navigator.maybePop(context)),
                      const Expanded(
                        child: Text('Order progress', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  final Order order;
  final Map<String, dynamic>? rider;
  const _Progress({required this.order, required this.rider});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final station = o.station;
    final stationName = station?['name']?.toString() ?? 'Your supplier';
    final stationPhone = station?['phone']?.toString();
    final stationPt = station == null ? null : LatLng((station['lat'] as num).toDouble(), (station['lng'] as num).toDouble());
    final drop = o.deliveryLat == null || o.deliveryLng == null ? null : LatLng(o.deliveryLat!, o.deliveryLng!);
    final r = rider;
    final riderPt = r == null ? null : LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
    final lastLocation = DateTime.tryParse(r?['updated_at']?.toString() ?? '');
    final locationAge = lastLocation == null ? null : DateTime.now().difference(lastLocation).inMinutes;
    final eta = o.status == 'out_for_delivery' ? etaText(riderPt ?? stationPt, drop) : null;
    final notes = DeliveryNotes.parse(o.notes);
    final (title, subtitle) = switch (o.status) {
      'pending' => ('Order sent', '$stationName will confirm it shortly.'),
      'accepted' => ('Order confirmed', '$stationName accepted your order.'),
      'preparing' => ('Getting it ready', '$stationName is preparing your order.'),
      'out_for_delivery' => (eta == null ? 'On the way' : 'Arriving in ${eta.replaceAll(' away', '')}', 'Your rider is heading to you.'),
      'delivered' => ('Delivered', 'Enjoy! Thanks for ordering with Refilly.'),
      _ => ('Order cancelled', 'This order will not be delivered.'),
    };
    final itemsTotal = o.items.fold<double>(0, (t, i) => t + i.unitPrice * i.quantity);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset(context, 24)),
      children: [
        SoftCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
                  StatusPill(o.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: RF.muted, fontSize: 14)),
              const SizedBox(height: 14),
              if (o.status != 'cancelled') StatusSteps(o.status, padding: EdgeInsets.zero),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Delivery window',
                value: notes.window ?? 'As soon as possible',
                caption: 'Ordered ${shortDate(o.createdAt.toLocal())}, ${clockLabel(o.createdAt.toLocal())}',
              ),
              DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Deliver to',
                value: o.deliveryAddress.isEmpty ? 'Pinned location' : o.deliveryAddress,
                caption: [
                  if (notes.handoff != null) 'Leave at ${notes.handoff!.toLowerCase()}',
                  if (notes.emptiesToCollect > 0) 'Collect ${notes.emptiesToCollect} empty container${notes.emptiesToCollect == 1 ? '' : 's'}',
                ].join(' · ').ifEmpty(null),
              ),
              if (notes.instructions != null)
                DetailRow(icon: Icons.sticky_note_2_outlined, label: 'Instructions', value: notes.instructions!),
            ],
          ),
        ),
        if (o.riderName != null) ...[
          const SizedBox(height: 12),
          RiderCard(
            name: o.riderName!,
            phone: o.riderPhone,
            eta: o.status == 'out_for_delivery' ? eta : 'Your rider',
            onCall: o.riderPhone == null ? null : () => launchUrl(Uri.parse('tel:${o.riderPhone}')),
          ),
          if (o.status == 'out_for_delivery')
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                riderPt == null
                    ? 'Waiting for the rider to share their location'
                    : locationAge != null && locationAge >= 3
                        ? 'Rider location may be outdated · updated $locationAge min ago'
                        : 'Rider location updated recently',
                style: TextStyle(color: locationAge != null && locationAge >= 3 ? RF.usualInk : RF.muted, fontSize: 13),
              ),
            ),
        ],
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order from $stationName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              for (final i in o.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ProductArt(name: i.productName, imageUrl: i.imageUrl, size: 44, radius: 12),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${i.quantity} × ${i.productName}', style: const TextStyle(fontSize: 14))),
                      Text(peso(i.unitPrice * i.quantity), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const Divider(height: 20),
              _line('Items', peso(itemsTotal)),
              _line('Delivery fee', o.deliveryFee == 0 ? 'Free' : peso(o.deliveryFee)),
              _line('Total · ${o.paymentMethod == 'cod' ? 'Cash on Delivery' : o.paymentMethod.toUpperCase()}', peso(o.total), bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              DetailRow(
                icon: Icons.support_agent_rounded,
                label: 'Need help?',
                value: 'Contact $stationName',
                caption: stationPhone ?? 'This supplier has not listed a phone number yet',
                trailing: stationPhone == null
                    ? null
                    : FloatIconButton(Icons.call_outlined, tooltip: 'Call supplier', onTap: () => launchUrl(Uri.parse('tel:$stationPhone'))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (o.status == 'delivered') ...[
          FilledButton(onPressed: () => _reorder(context, o), child: const Text('Order again')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.repeat_rounded),
            label: const Text('Save to my essentials'),
            onPressed: () => saveRoutineFromOrder(context, o),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('Rate this supplier'),
            onPressed: () => _reviewStation(context, o),
          ),
        ],
        if (o.status == 'cancelled') FilledButton(onPressed: () => _reorder(context, o), child: const Text('Order again')),
        if (o.status == 'pending')
          OutlinedButton(onPressed: () => _cancel(context, o), child: const Text('Cancel order')),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(value, style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ],
    ),
  );
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}

