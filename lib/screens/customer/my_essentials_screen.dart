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
        showFailureNotice(context, e, failed: 'Unable to update this routine.');
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
                  showAppNotice(c, 'Enter 1–365 days.');
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
        showFailureNotice(context, e, failed: 'Unable to prepare this refill.');
      }
    } finally {
      if (mounted) setState(() => _working.remove(routine.id));
    }
  }

  final Map<String, Future<Order?>> _orders = {};
  Future<Order?> _order(RefillRoutine r) => _orders.putIfAbsent(r.sourceOrderId, () => Api.orderById(r.sourceOrderId));

  String _dueLabel(RefillRoutine routine) {
    final remaining = routine.daysUntil(DateTime.now());
    if (remaining < 0) return '${-remaining} day${remaining == -1 ? '' : 's'} overdue';
    if (remaining == 0) return 'Due today';
    if (remaining == 1) return 'Due tomorrow';
    return 'Next refill ${shortDate(routine.nextDueOn)}';
  }

  String _schedule(int days) => switch (days) {
    7 => 'Every week',
    14 => 'Every 2 weeks',
    30 => 'Every month',
    _ => 'Every $days days',
  };

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      _orders.clear();
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
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset(context, 120)),
          children: [
            Row(
              children: [
                Expanded(child: Text('My essentials', style: Theme.of(context).textTheme.headlineSmall)),
                FloatIconButton(Icons.refresh_rounded, tooltip: 'Refresh essentials', onTap: () {
                  _orders.clear();
                  _refresh();
                }),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Your usuals, ready when you need them.', style: TextStyle(color: RF.muted, fontSize: 15)),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const IconBubble(Icons.notifications_none_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dueCount == 0 ? 'Reminders, never surprise orders' : '$dueCount usual${dueCount == 1 ? ' is' : 's are'} due for a refill',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const Text(
                          'We remind you when it may be time. Nothing is ordered until you confirm.',
                          style: TextStyle(color: RF.muted, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (items.isEmpty) ...[
              const SizedBox(height: 30),
              const EmptyState(
                artwork: EssentialsSticker(),
                title: 'No usuals yet',
                subtitle: 'After a delivery, save the order to your essentials. Next time it takes one tap to refill.',
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: widget.onExplore, child: const Text('Order water')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: widget.onOrders, child: const Text('See past orders')),
            ],
            for (final routine in items) _routineCard(routine),
          ],
        );
      },
    ),
  );

  Widget _routineCard(RefillRoutine routine) {
    final busy = _working.contains(routine.id);
    final due = routine.isDue(DateTime.now());
    return SoftCard(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Order?>(
        future: _order(routine),
        builder: (context, snap) {
          final order = snap.data;
          final first = order?.items.firstOrNull;
          final qty = order?.items.fold(0, (t, i) => t + i.quantity) ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductArt(name: first?.productName ?? 'Water refill', imageUrl: first?.imageUrl, size: 76, radius: 18),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first?.productName ?? 'Saved refill',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order?.station?['name']?.toString() ?? 'Your supplier',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: RF.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (qty > 0) Tag('Usual × $qty'),
                            Tag(_schedule(routine.intervalDays), background: RF.fill, foreground: RF.muted),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    enabled: !busy,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) {
                      switch (action) {
                        case 'skip': _action(routine, 'skip');
                        case 'remove': _remove(routine);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'skip', child: Text('Skip this time')),
                      PopupMenuItem(value: 'remove', child: Text('Remove from essentials')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 18, color: due ? RF.usualInk : RF.muted),
                  const SizedBox(width: 6),
                  Text(
                    _dueLabel(routine),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: due ? RF.usualInk : RF.ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: busy ? null : () => _refill(routine), child: const Text('Refill now')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _action(routine, 'snooze'),
                      child: const Text('Snooze 3 days'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _changeInterval(routine),
                      child: const Text('Edit schedule'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

