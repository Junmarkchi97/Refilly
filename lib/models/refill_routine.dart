class RefillRoutine {
  final String id, customerId, sourceOrderId, stationId;
  final String? lastOrderId;
  final int intervalDays;
  final DateTime nextDueOn;
  final DateTime? lastNotifiedDueOn;

  const RefillRoutine({
    required this.id, required this.customerId, required this.sourceOrderId,
    required this.stationId, required this.intervalDays, required this.nextDueOn,
    this.lastOrderId, this.lastNotifiedDueOn,
  });

  factory RefillRoutine.fromMap(Map<String, dynamic> m) => RefillRoutine(
    id: m['id'] as String,
    customerId: m['customer_id'] as String,
    sourceOrderId: m['source_order_id'] as String,
    stationId: m['station_id'] as String,
    intervalDays: m['interval_days'] as int,
    nextDueOn: DateTime.parse(m['next_due_on'] as String),
    lastOrderId: m['last_order_id'] as String?,
    lastNotifiedDueOn: m['last_notified_due_on'] == null
        ? null : DateTime.parse(m['last_notified_due_on'] as String),
  );

  static DateTime calendarDate(DateTime date) => DateTime(date.year, date.month, date.day);

  int daysUntil(DateTime now) => calendarDate(nextDueOn).difference(calendarDate(now)).inDays;

  bool isDue(DateTime now) => daysUntil(now) <= 0;

  static DateTime snoozedUntil(DateTime due, DateTime now) {
    final base = calendarDate(due).isAfter(calendarDate(now)) ? calendarDate(due) : calendarDate(now);
    return base.add(const Duration(days: 3));
  }

  static DateTime skippedUntil(DateTime due, DateTime now, int interval) {
    final base = calendarDate(due).isAfter(calendarDate(now)) ? calendarDate(due) : calendarDate(now);
    return base.add(Duration(days: interval));
  }
}
