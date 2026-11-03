import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'api.dart';
import 'owner_billing_ids.dart';

final _client = _OwnerStoreClient();

Future<OwnerStoreReceipt> purchaseOwnerPlan(String plan, {String? userId}) => _client.purchase(plan, userId: userId);

Future<OwnerStoreReceipt?> restoreOwnerPlan({String? userId}) => _client.restore(userId: userId);

Future<void> syncOwnerPlan(String? userId) async {
  if (userId == null || userId.isEmpty) return;
  await _client.sync();
}

class _OwnerStoreClient {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, Completer<OwnerStoreReceipt>> _waiters = {};
  Completer<OwnerStoreReceipt?>? _restoreWaiter;

  bool get _isApple => Platform.isIOS;
  bool get _isPlay => Platform.isAndroid;

  Future<OwnerStoreReceipt> purchase(String plan, {String? userId}) async {
    _requireMobile();
    final productId = OwnerBillingIds.productIdForPlan(plan);
    if (productId == null) {
      throw StoreBillingException('Choose a monthly or yearly plan.');
    }
    if (!await _iap.isAvailable()) {
      throw StoreBillingException('Payments are unavailable on this device right now.');
    }
    final response = await _iap.queryProductDetails({productId});
    final products = response.productDetails.where((product) => product.id == productId).toList();
    if (products.isEmpty) {
      throw StoreBillingException('This plan is not available in the store yet.');
    }
    final product = products[preferredFreeTrialIndex(products.map((item) => item.rawPrice))];
    final completer = Completer<OwnerStoreReceipt>();
    _waiters[productId] = completer;
    _listen();
    try {
      final started = await _iap.buyNonConsumable(purchaseParam: _param(product, userId));
      if (!started) {
        _waiters.remove(productId);
        throw StoreBillingException('Could not open the payment sheet. Please try again.');
      }
    } catch (e) {
      _waiters.remove(productId);
      if (e is StoreBillingException || e is StorePurchaseCancelled) rethrow;
      throw StoreBillingException('Could not open the payment sheet. Please try again.');
    }
    return completer.future;
  }

  Future<OwnerStoreReceipt?> restore({String? userId}) async {
    _requireMobile();
    final current = await currentEntitlement();
    if (current != null) return current;
    if (!_isApple) return null;
    _listen();
    final completer = Completer<OwnerStoreReceipt?>();
    _restoreWaiter = completer;
    try {
      await _iap.restorePurchases(applicationUserName: storeAccountToken(userId));
    } catch (_) {
      _restoreWaiter = null;
      throw StoreBillingException('Could not restore purchases. Please try again.');
    }
    return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
      _restoreWaiter = null;
      return null;
    });
  }

  Future<void> sync() async {
    try {
      if (!_isApple && !_isPlay) return;
      final receipt = await currentEntitlement();
      if (receipt == null) return;
      await Api.recordOwnerStorePurchase(receipt);
    } catch (_) {
      // A later visit can refresh the saved period end.
    }
  }

  Future<OwnerStoreReceipt?> currentEntitlement() async {
    if (_isApple) return _appleEntitlement();
    if (_isPlay) return _playEntitlement();
    return null;
  }

  Future<OwnerStoreReceipt?> _appleEntitlement() async {
    final transactions = await SK2Transaction.currentEntitlements();
    final now = DateTime.now().toUtc();
    final receipts = <OwnerStoreReceipt>[];
    for (final transaction in transactions) {
      final plan = OwnerBillingIds.planForProduct(transaction.productId);
      if (plan == null || transaction.id.isEmpty) continue;
      final periodEnd = periodEndFromMillis(transaction.expirationDate);
      if (periodEnd != null && !periodEnd.isAfter(now)) continue;
      receipts.add(OwnerStoreReceipt(
        plan: plan,
        productId: transaction.productId,
        transactionId: transaction.id,
        store: 'app_store',
        periodEnd: periodEnd,
      ));
    }
    return latestReceipt(receipts);
  }

  Future<OwnerStoreReceipt?> _playEntitlement() async {
    if (!await _iap.isAvailable()) return null;
    final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) return null;
    final receipts = <OwnerStoreReceipt>[];
    for (final purchase in response.pastPurchases) {
      if (purchase.status != PurchaseStatus.purchased && purchase.status != PurchaseStatus.restored) continue;
      final receipt = _receiptFrom(purchase);
      if (receipt == null) continue;
      receipts.add(receipt);
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    return latestReceipt(receipts);
  }

  void _listen() {
    _subscription ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {
      final pending = List<Completer<OwnerStoreReceipt>>.of(_waiters.values);
      _waiters.clear();
      for (final waiter in pending) {
        if (!waiter.isCompleted) {
          waiter.completeError(StoreBillingException('The store could not complete the payment.'));
        }
      }
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          _fail(purchase.productID, const StorePurchaseCancelled());
          break;
        case PurchaseStatus.error:
          _fail(purchase.productID, StoreBillingException('The payment did not go through. Please try again.'));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final receipt = _receiptFrom(purchase);
          if (receipt != null) _succeed(purchase.productID, receipt);
          break;
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (_) {
          // The store already has the payment. Recording it still matters.
        }
      }
    }
  }

  OwnerStoreReceipt? _receiptFrom(PurchaseDetails purchase) {
    final plan = OwnerBillingIds.planForProduct(purchase.productID);
    final transactionId = _transactionId(purchase);
    if (plan == null || transactionId == null) return null;
    return OwnerStoreReceipt(
      plan: plan,
      productId: purchase.productID,
      transactionId: transactionId,
      store: _isApple ? 'app_store' : 'play_store',
      periodEnd: purchase is SK2PurchaseDetails ? periodEndFromMillis(purchase.expirationDate) : null,
    );
  }

  String? _transactionId(PurchaseDetails purchase) {
    final id = purchase.purchaseID?.trim();
    if (id != null && id.isNotEmpty) return id;
    final token = purchase.verificationData.serverVerificationData.trim();
    if (token.isEmpty || token.length > 2048) return null;
    return token;
  }

  PurchaseParam _param(ProductDetails product, String? userId) {
    final account = storeAccountToken(userId);
    if (product is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: account,
        offerToken: product.offerToken,
      );
    }
    return PurchaseParam(productDetails: product, applicationUserName: account);
  }

  void _succeed(String productId, OwnerStoreReceipt receipt) {
    final waiter = _waiters.remove(productId);
    if (waiter != null && !waiter.isCompleted) waiter.complete(receipt);
    final restore = _restoreWaiter;
    if (restore != null && !restore.isCompleted) {
      _restoreWaiter = null;
      restore.complete(receipt);
    }
  }

  void _fail(String productId, Exception error) {
    final waiter = _waiters.remove(productId);
    if (waiter != null && !waiter.isCompleted) waiter.completeError(error);
  }

  void _requireMobile() {
    if (_isApple || _isPlay) return;
    throw StoreBillingException('Start the free trial in the Refilly app on iPhone or Android.');
  }
}
