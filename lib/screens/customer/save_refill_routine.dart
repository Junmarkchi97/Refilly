import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';

/// Turns a delivered order into a customer-controlled recurring refill reminder.
/// No subscriptions, auto-charges, or automatic orders are created.
Future<bool> saveRoutineFromOrder(BuildContext context, Order order) async {
  if (order.status != 'delivered') return false;
  var selectedDays = 7;
  var custom = false;
  var saving = false;
  final controller = TextEditingController(text: '21');
  try {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Save to My Essentials'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How often do you usually need these items? We will remind you when it may be time to refill.'),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [(7, 'Weekly'), (14, 'Every 2 weeks'), (30, 'Monthly')])
                      ChoiceChip(
                        label: Text(entry.$2),
                        selected: !custom && selectedDays == entry.$1,
                        onSelected: saving ? null : (_) => update(() {
                          selectedDays = entry.$1;
                          custom = false;
                        }),
                      ),
                    ChoiceChip(
                      label: const Text('Custom'),
                      selected: custom,
                      onSelected: saving ? null : (_) => update(() => custom = true),
                    ),
                  ],
                ),
                if (custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repeat every (days)',
                      helperText: 'Choose 1–365 days',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Reminders are suggestions. You always review prices, delivery and the order before placing it.',
                  style: TextStyle(color: RF.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                final days = custom ? int.tryParse(controller.text.trim()) : selectedDays;
                if (days == null || days < 1 || days > 365) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a number from 1 to 365 days.')),
                  );
                  return;
                }
                update(() => saving = true);
                try {
                  await Api.saveRefillRoutine(order.id, days);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (dialogContext.mounted) {
                    update(() => saving = false);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Could not save routine: $e')),
                    );
                  }
                }
              },
              child: Text(saving ? 'Saving…' : 'Save routine'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved! Find this refill in My Essentials.')),
      );
    }
    return saved ?? false;
  } finally {
    controller.dispose();
  }
}
