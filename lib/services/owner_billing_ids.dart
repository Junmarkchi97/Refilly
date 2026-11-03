/// Auto-renewing subscriptions. The 7-day free trial is an introductory offer
/// on these same product ids in App Store Connect and Google Play.
class OwnerBillingIds {
  static const monthly = 'refilly_owner_monthly';
  static const yearly = 'refilly_owner_yearly';

  static String? productIdForPlan(String plan) => switch (plan) {
    'monthly' => monthly,
    'yearly' => yearly,
    _ => null,
  };

  static String? planForProduct(String productId) => switch (productId) {
    monthly => 'monthly',
    yearly => 'yearly',
    _ => null,
  };

  static bool isOwnerProduct(String productId) => planForProduct(productId) != null;
}

/// A store purchase Refilly can record. The store, not Refilly, charges the
/// Apple ID or Google account when the trial ends.
class OwnerStoreReceipt {
  final String plan;
  final String productId;
  final String transactionId;
  final String store;
  final DateTime? periodEnd;

  const OwnerStoreReceipt({
    required this.plan,
    required this.productId,
    required this.transactionId,
    required this.store,
    this.periodEnd,
  });
}

class StoreBillingException implements Exception {
  StoreBillingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StorePurchaseCancelled implements Exception {
  const StorePurchaseCancelled();
}

final _accountUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Apple only accepts a UUID as the account token on a transaction.
String? storeAccountToken(String? userId) {
  if (userId == null || !_accountUuid.hasMatch(userId)) return null;
  return userId;
}

/// StoreKit reports subscription expiry as epoch milliseconds.
DateTime? periodEndFromMillis(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final ms = int.tryParse(raw);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// Google Play returns one product row per offer. A free first phase is the trial.
int preferredFreeTrialIndex(Iterable<double> rawPrices) {
  final prices = rawPrices.toList();
  if (prices.isEmpty) return 0;
  final free = prices.indexWhere((price) => price == 0);
  return free >= 0 ? free : 0;
}

/// Prefer the subscription that lasts longer when the store reports more than one.
OwnerStoreReceipt? latestReceipt(List<OwnerStoreReceipt> receipts) {
  if (receipts.isEmpty) return null;
  final sorted = [...receipts]..sort((a, b) {
    final byEnd = (a.periodEnd ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      b.periodEnd ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
    if (byEnd != 0) return byEnd;
    if (a.plan == b.plan) return 0;
    return a.plan == 'yearly' ? 1 : -1;
  });
  return sorted.last;
}
