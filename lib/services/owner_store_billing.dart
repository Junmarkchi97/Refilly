import 'owner_billing_ids.dart';
import 'owner_store_billing_unsupported.dart'
    if (dart.library.io) 'owner_store_billing_io.dart' as store;

export 'owner_billing_ids.dart';

/// Apple In-App Purchase and Google Play Billing for the station-owner plans.
class OwnerStoreBilling {
  static Future<OwnerStoreReceipt> purchase(String plan, {String? userId}) =>
      store.purchaseOwnerPlan(plan, userId: userId);

  static Future<OwnerStoreReceipt?> restore({String? userId}) => store.restoreOwnerPlan(userId: userId);

  /// Refreshes the saved period end from the store after a renewal. Failures stay quiet.
  static Future<void> sync(String? userId) => store.syncOwnerPlan(userId);
}
