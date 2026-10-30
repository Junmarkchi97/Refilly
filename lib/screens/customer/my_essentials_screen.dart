import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../models/refill_routine.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../network_states.dart';
import '../widgets.dart';
import 'reorder.dart';

class MyEssentialsScreen extends StatefulWidget {
  const MyEssentialsScreen({
    super.key, required this.profile, required this.onExplore, required this.onOrders,
  });

  final Profile profile;
  final VoidCallback onExplore, onOrders;

  @override
  State<MyEssentialsScreen> createState() => _MyEssentialsScreenState();
}

class _MyEssentialsScreenState extends State<MyEssentialsScreen> {
  late Future<List<RefillRoutine>> _routines = _load();
  final Set<String> _working = {};

  Future<List<RefillRoutine>> _load() async {
    // At most one notification per due date is claimed by the database,
    // even if a customer opens Refilly on multiple devices simultaneously.
    try {
      await Api.claimRefillReminders().timeout(const Duration(seconds: 10));
    } catch (_) {
      // A notification failure cannot prevent a customer from seeing saved items.
    }
    return Api.refillRoutines().timeout(const Duration(seconds: 20));
  }

  void _refresh() {
    if (!mounted) { return; }
    setState(() => _routines = _load());
  }

  Future<void> _action(RefillRoutine routine, String action, {int? days}) async {
    if (_working.contains(routine.id)) return;
    setState(() => _working.add(routine.id));
    try {
      await Api.manageRefillRoutine(routine.id, action, days: days);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update routine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working.remove(routine.id));
    }
  }

  Future<void> _changeInterval(RefillRoutine routine) async {
    final daysController = TextEditingController(text: routine.intervalDays.toString());
    try {
      final days = await showDialog<int>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Refill frequency'),
          content: TextField(
            controller: daysController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Every how many days?', helperText: '1–365 days'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(daysController.text.trim());
                if (value == null || value < 1 || value > 365) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('Enter 1–365 days.')),
                  );
                  return;
                }
                Navigator.pop(c, value);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (days != null && mounted) await _action(routine, 'frequency', days: days);
    } finally {
      daysController.dispose();
    }
  }

  Future<void> _remove(RefillRoutine routine) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove this essential?'),
        content: const Text('This deletes the refill reminder, not any previous orders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true && mounted) await _action(routine, 'remove');
  }

  Future<void> _refill(RefillRoutine routine) async {
    if (_working.contains(routine.id)) return;
    setState(() => _working.add(routine.id));
    try {
      final order = await Api.orderById(routine.sourceOrderId);
      if (!mounted) return;
      if (order == null) throw StateError('This saved order is unavailable.');
      await startReorder(context, order, widget.profile, routine: routine);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to prepare refill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working.remove(routine.id));
    }
  }

  String _dueLabel(RefillRoutine routine) {
    final remaining = routine.daysUntil(DateTime.now());
    if (remaining < 0) return '${-remaining} day${remaining == -1 ? '' : 's'} overdue';
    if (remaining == 0) return 'Refill due today';
    if (remaining == 1) return 'Refill due tomorrow';
    return 'Refill in $remaining days';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      _refresh();
      await _routines;
    },
    child: FutureBuilder<List<RefillRoutine>>(
      future: _routines,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LoadFailureView(error: snapshot.error!, onRetry: _refresh);
        }
        if (!snapshot.hasData) { return const Center(child: SlowLoadingHint()); }
        final items = snapshot.data!;
        final dueCount = items.where((r) => r.isDue(DateTime.now())).length;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, bottomInset(context, 120)),
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: RF.accent, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('My Essentials', style: Theme.of(context).textTheme.headlineSmall),
                ),
                IconButton(onPressed: _refresh, tooltip: 'Refresh routines', icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Refill the things you use again and again. No automatic charges or surprise orders.',
              style: TextStyle(color: RF.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (dueCount > 0)
              Card(
                color: RF.accentSoft,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: RF.accent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        '$dueCount essential${dueCount == 1 ? ' may' : 's may'} need a refill.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )),
                    ],
                  ),
                ),
              ),
            if (items.isEmpty) ...[
              const SizedBox(height: 38),
              const EmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'Your essentials, on repeat',
                subtitle: 'Order water once, then save a delivered order as a refill routine. We will remind you when it may be time.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: widget.onExplore,
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Explore water stations'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onOrders,
                child: const Text('See my past orders'),
              ),
            ],
            for (final routine in items)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: RF.accentSoft,
                            child: Icon(Icons.repeat_rounded, color: RF.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _dueLabel(routine),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: routine.isDue(DateTime.now()) ? RF.accent : RF.ink,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Manage routine',
                            onSelected: (action) {
                              switch (action) {
                                case 'frequency': _changeInterval(routine);
                                case 'remove': _remove(routine);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'frequency', child: Text('Change frequency')),
                              PopupMenuItem(value: 'remove', child: Text('Remove routine')),
                            ],
                          ),
                        ],
                      ),
                      FutureBuilder<Order?>(
                        future: Api.orderById(routine.sourceOrderId),
                        builder: (context, orderSnap) {
                          final order = orderSnap.data;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order?.station?['name']?.toString() ?? 'Saved refill',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                const SizedBox(height: 4),
                                Text(
                                  order == null
                                      ? 'Every ${routine.intervalDays} days'
                                      : '${order.items.map((e) => '${e.quantity} × ${e.productName}').join(', ')} · Every ${routine.intervalDays} days',
                                  maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: RF.muted, height: 1.4),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      FilledButton.icon(
                        onPressed: _working.contains(routine.id) ? null : () => _refill(routine),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Refill now · Review cart'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _working.contains(routine.id) ? null : () => _action(routine, 'snooze'),
                              child: const Text('Snooze 3 days'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _working.contains(routine.id) ? null : () => _action(routine, 'skip'),
                              child: const Text('Skip this time'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
