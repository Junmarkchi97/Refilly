import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/services/owner_billing_ids.dart';

void main() {
  test('store product ids match the monthly and yearly plans', () {
    expect(OwnerBillingIds.productIdForPlan('monthly'), 'refilly_owner_monthly');
    expect(OwnerBillingIds.productIdForPlan('yearly'), 'refilly_owner_yearly');
    expect(OwnerBillingIds.planForProduct('refilly_owner_monthly'), 'monthly');
    expect(OwnerBillingIds.planForProduct('refilly_owner_yearly'), 'yearly');
    expect(OwnerBillingIds.productIdForPlan('sponsored'), isNull);
  });

  test('a free Google Play offer is preferred over the paid base plan', () {
    expect(preferredFreeTrialIndex([249, 0]), 1);
    expect(preferredFreeTrialIndex([0, 1793]), 0);
    expect(preferredFreeTrialIndex([249]), 0);
  });

  test('the longer active subscription wins', () {
    final monthly = OwnerStoreReceipt(
      plan: 'monthly',
      productId: OwnerBillingIds.monthly,
      transactionId: '1',
      store: 'app_store',
      periodEnd: DateTime.utc(2026, 12, 1),
    );
    final yearly = OwnerStoreReceipt(
      plan: 'yearly',
      productId: OwnerBillingIds.yearly,
      transactionId: '2',
      store: 'app_store',
      periodEnd: DateTime.utc(2027, 11, 1),
    );
    expect(latestReceipt([monthly, yearly])?.plan, 'yearly');
    expect(periodEndFromMillis('1000'), DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    expect(storeAccountToken('not-a-uuid'), isNull);
    expect(storeAccountToken('11111111-1111-1111-1111-111111111111'), '11111111-1111-1111-1111-111111111111');
  });
}
