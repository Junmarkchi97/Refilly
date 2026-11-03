import 'owner_billing_ids.dart';

Future<OwnerStoreReceipt> purchaseOwnerPlan(String plan, {String? userId}) async {
  throw StoreBillingException('Start the free trial in the Refilly app on iPhone or Android.');
}

Future<OwnerStoreReceipt?> restoreOwnerPlan({String? userId}) async {
  throw StoreBillingException('Restore purchases in the Refilly app on iPhone or Android.');
}

Future<void> syncOwnerPlan(String? userId) async {}
