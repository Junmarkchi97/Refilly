import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/refill_routine.dart';

RefillRoutine routine(String due, {int days = 7}) => RefillRoutine(
  id: 'routine-1',
  customerId: 'user-1',
  sourceOrderId: 'order-1',
  stationId: 'station-1',
  intervalDays: days,
  nextDueOn: DateTime.parse(due),
);

void main() {
  test('due reminder is based on calendar dates, not time of day', () {
    final due = routine('2026-11-07');
    expect(due.daysUntil(DateTime(2026, 11, 7, 23, 59)), 0);
    expect(due.isDue(DateTime(2026, 11, 6, 23, 59)), isFalse);
    expect(due.isDue(DateTime(2026, 11, 7, 0, 0)), isTrue);
    expect(due.daysUntil(DateTime(2026, 11, 9, 1)), -2);
  });

  test('snoozing a due reminder delays it three days from today', () {
    final next = RefillRoutine.snoozedUntil(
      DateTime(2026, 10, 22), DateTime(2026, 10, 31, 18),
    );
    expect(next, DateTime(2026, 11, 3));
  });

  test('snoozing an upcoming reminder preserves its future target', () {
    expect(
      RefillRoutine.snoozedUntil(DateTime(2026, 11, 10), DateTime(2026, 10, 31)),
      DateTime(2026, 11, 13),
    );
  });

  test('skipping adds one frequency interval rather than silently ordering', () {
    expect(
      RefillRoutine.skippedUntil(DateTime(2026, 10, 20), DateTime(2026, 10, 31), 14),
      DateTime(2026, 11, 14),
    );
  });

  test('model parsing preserves routine source order and frequencies', () {
    final parsed = RefillRoutine.fromMap({
      'id': 'routine-1',
      'customer_id': 'user-1',
      'source_order_id': 'order-1',
      'station_id': 'station-1',
      'interval_days': 14,
      'next_due_on': '2026-11-14',
      'last_notified_due_on': null,
      'last_order_id': 'order-2',
    });
    expect(parsed.intervalDays, 14);
    expect(parsed.sourceOrderId, 'order-1');
    expect(parsed.lastOrderId, 'order-2');
    expect(parsed.isDue(DateTime(2026, 11, 10)), isFalse);
  });
}
