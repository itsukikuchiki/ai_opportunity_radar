import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

class PurchaseController extends ChangeNotifier {
  static const MethodChannel _nativeStoreKitChannel =
      MethodChannel('signalpath/storekit');
  static const String proMonthlyProductId = 'jp.sunrise.signalpath.pro.monthly';
  static const String proYearlyProductId = 'jp.sunrise.signalpath.pro.yearly';
  static const Set<String> proProductIds = {
    proMonthlyProductId,
    proYearlyProductId,
  };
  static const String premiumEntitlementKey = 'premium_entitlement_active';
  static const String entitlementProductIdKey =
      'premium_entitlement_product_id';
  static const String entitlementVerificationDataKey =
      'premium_entitlement_verification_data';
  static const String entitlementVerificationSourceKey =
      'premium_entitlement_verification_source';
  static const String entitlementTransactionDateKey =
      'premium_entitlement_transaction_date';
  static const String entitlementServerVerifiedKey =
      'premium_entitlement_server_verified';
  static const String entitlementServerReasonKey =
      'premium_entitlement_server_reason';

  final InAppPurchase _inAppPurchase;
  final ApiClient? _apiClient;
  final bool _storeSupported;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Future<void>? _initFuture;
  final Map<String, ProductDetails> _proProducts = {};
  final Set<String> _nativeStoreKitProductIds = {};

  bool loading = true;
  bool storeAvailable = false;
  bool isPremium = false;
  bool purchasePending = false;
  bool restoring = false;
  String? errorMessage;
  List<String> notFoundProductIds = const [];
  String? entitlementProductId;
  String? entitlementVerificationData;
  String? entitlementVerificationSource;
  String? entitlementTransactionDate;
  bool serverVerified = false;
  String? serverVerificationReason;

  PurchaseController({
    InAppPurchase? inAppPurchase,
    ApiClient? apiClient,
  })  : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
        _apiClient = apiClient,
        _storeSupported = inAppPurchase != null || _platformSupportsStore {
    if (_storeSupported) {
      try {
        _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
          _handlePurchaseUpdates,
          onError: (Object error) {
            purchasePending = false;
            restoring = false;
            errorMessage = error.toString();
            notifyListeners();
          },
        );
      } catch (e) {
        errorMessage = e.toString();
      }
    }
    init();
  }

  ProductDetails? get proMonthlyProduct => _proProducts[proMonthlyProductId];

  ProductDetails? get proYearlyProduct => _proProducts[proYearlyProductId];

  String get proMonthlyDisplayPrice => proMonthlyProduct?.price ?? '\$0.99';

  String get proYearlyDisplayPrice => proYearlyProduct?.price ?? '\$9.99';

  bool get canBuyPro =>
      !isPremium &&
      storeAvailable &&
      _proProducts.isNotEmpty &&
      !purchasePending;

  bool canBuyProduct(String productId) =>
      !isPremium &&
      storeAvailable &&
      _proProducts.containsKey(productId) &&
      !purchasePending;

  bool get canAttemptNativeStoreKitPurchase =>
      !isPremium && storeAvailable && _canUseNativeStoreKit && !purchasePending;

  static bool get _platformSupportsStore {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> init() async {
    final inFlight = _initFuture;
    if (inFlight != null) {
      return inFlight;
    }

    _initFuture = _loadProducts();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _loadProducts() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      isPremium = prefs.getBool(premiumEntitlementKey) ?? false;
      entitlementProductId = prefs.getString(entitlementProductIdKey);
      entitlementVerificationData = prefs.getString(
        entitlementVerificationDataKey,
      );
      entitlementVerificationSource = prefs.getString(
        entitlementVerificationSourceKey,
      );
      entitlementTransactionDate = prefs.getString(
        entitlementTransactionDateKey,
      );
      serverVerified = prefs.getBool(entitlementServerVerifiedKey) ?? false;
      serverVerificationReason = prefs.getString(entitlementServerReasonKey);

      if (!_storeSupported) {
        storeAvailable = false;
        return;
      }

      storeAvailable = await _inAppPurchase.isAvailable();
      if (!storeAvailable) {
        return;
      }

      final response = await _inAppPurchase.queryProductDetails(proProductIds);

      if (response.error != null) {
        errorMessage = response.error!.message;
      }

      notFoundProductIds = response.notFoundIDs;
      _proProducts
        ..clear()
        ..addEntries(
          response.productDetails.map((product) {
            return MapEntry(product.id, product);
          }),
        );

      if (_shouldUseNativeStoreKitFallback(response)) {
        await _loadNativeStoreKitProducts();
      }
    } catch (e) {
      errorMessage = e.toString();
      await _loadNativeStoreKitProducts();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool _shouldUseNativeStoreKitFallback(ProductDetailsResponse response) {
    if (!_canUseNativeStoreKit) return false;
    return response.productDetails.isEmpty || response.error != null;
  }

  bool get _canUseNativeStoreKit {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  Future<void> _loadNativeStoreKitProducts() async {
    if (!_canUseNativeStoreKit) return;

    try {
      final products = await _nativeStoreKitChannel.invokeListMethod<dynamic>(
        'queryProducts',
        {'ids': proProductIds.toList()},
      );
      if (products == null || products.isEmpty) {
        errorMessage = null;
        return;
      }

      _nativeStoreKitProductIds.clear();
      _proProducts
        ..clear()
        ..addEntries(products.map((item) {
          final data = Map<String, dynamic>.from(item as Map);
          final id = data['id'] as String;
          _nativeStoreKitProductIds.add(id);
          return MapEntry(
            id,
            ProductDetails(
              id: id,
              title: data['title'] as String? ?? id,
              description: data['description'] as String? ?? '',
              price: data['price'] as String? ?? '',
              rawPrice: (data['rawPrice'] as num?)?.toDouble() ?? 0,
              currencyCode: data['currencyCode'] as String? ?? '',
            ),
          );
        }));
      errorMessage = null;
      notFoundProductIds = const [];
    } on PlatformException catch (e) {
      errorMessage = 'StoreKit fallback: ${e.message ?? e.code}';
    } catch (e) {
      errorMessage = 'StoreKit fallback: $e';
    }
  }

  Future<void> buyProMonthly() async {
    await buyProProduct(proMonthlyProductId);
  }

  Future<void> buyProYearly() async {
    await buyProProduct(proYearlyProductId);
  }

  Future<void> buyProProduct(String productId) async {
    errorMessage = null;

    if (!_proProducts.containsKey(productId)) {
      await init();
    }

    final product = _proProducts[productId] ??
        _proProducts[proYearlyProductId] ??
        _proProducts[proMonthlyProductId];
    if (product == null) {
      if (_canUseNativeStoreKit) {
        await _buyWithNativeStoreKit(productId);
        return;
      }
      errorMessage = 'Premium product is not available from the store yet.';
      notifyListeners();
      return;
    }

    if (_nativeStoreKitProductIds.contains(product.id)) {
      await _buyWithNativeStoreKit(product.id);
      return;
    }

    purchasePending = true;
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: product);
    bool started;
    try {
      started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (e) {
      purchasePending = false;
      errorMessage = e.toString();
      notifyListeners();
      return;
    }

    if (!started) {
      purchasePending = false;
      errorMessage = 'The store could not start the purchase.';
      notifyListeners();
    }
  }

  Future<void> _buyWithNativeStoreKit(String productId) async {
    purchasePending = true;
    notifyListeners();

    try {
      final transaction = await _nativeStoreKitChannel.invokeMapMethod(
        'purchase',
        {'id': productId},
      );
      if (transaction == null) {
        errorMessage = 'The store did not return a transaction.';
        return;
      }
      await _activatePremiumFromNativeStoreKit(
        Map<String, dynamic>.from(transaction),
      );
      errorMessage = null;
    } on PlatformException catch (e) {
      if (e.code != 'PURCHASE_CANCELLED') {
        errorMessage = e.message ?? e.code;
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      purchasePending = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    restoring = true;
    errorMessage = null;
    notifyListeners();

    if (!_storeSupported) {
      restoring = false;
      errorMessage = 'Purchases are not available on this platform.';
      notifyListeners();
      return;
    }

    try {
      if (_canUseNativeStoreKit && _nativeStoreKitProductIds.isNotEmpty) {
        final restored = await _nativeStoreKitChannel.invokeListMethod<dynamic>(
          'restore',
        );
        final purchases = restored
                ?.map((item) => Map<String, dynamic>.from(item as Map))
                .where(
                  (item) =>
                      proProductIds.contains(item['productId'] as String?),
                )
                .toList() ??
            const [];
        if (purchases.isNotEmpty) {
          await _activatePremiumFromNativeStoreKit(purchases.first);
        }
      } else {
        await _inAppPurchase.restorePurchases();
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> unlockForLocalTesting() async {
    await _activatePremium();
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (!proProductIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          errorMessage = null;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _activatePremium(purchase);
          purchasePending = false;
          restoring = false;
          errorMessage = null;
          break;
        case PurchaseStatus.error:
          purchasePending = false;
          restoring = false;
          errorMessage = purchase.error?.message ?? 'Purchase failed.';
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          restoring = false;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }

    if (purchases.isEmpty) {
      restoring = false;
    }

    notifyListeners();
  }

  Future<void> _activatePremium([PurchaseDetails? purchase]) async {
    isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumEntitlementKey, true);

    if (purchase == null) return;

    entitlementProductId = purchase.productID;
    entitlementVerificationData =
        purchase.verificationData.serverVerificationData.isNotEmpty
            ? purchase.verificationData.serverVerificationData
            : purchase.verificationData.localVerificationData;
    entitlementVerificationSource = purchase.verificationData.source;
    entitlementTransactionDate = purchase.transactionDate;

    await prefs.setString(entitlementProductIdKey, entitlementProductId!);
    await prefs.setString(
      entitlementVerificationDataKey,
      entitlementVerificationData ?? '',
    );
    await prefs.setString(
      entitlementVerificationSourceKey,
      entitlementVerificationSource ?? '',
    );
    if (entitlementTransactionDate != null) {
      await prefs.setString(
        entitlementTransactionDateKey,
        entitlementTransactionDate!,
      );
    }
    await _verifyWithBackend(prefs);
  }

  Future<void> _activatePremiumFromNativeStoreKit(
    Map<String, dynamic> transaction,
  ) async {
    isPremium = true;
    entitlementProductId =
        transaction['productId'] as String? ?? proMonthlyProductId;
    entitlementVerificationData = transaction['verificationData'] as String?;
    entitlementVerificationSource =
        transaction['verificationSource'] as String? ?? 'storekit2';
    entitlementTransactionDate = transaction['purchaseDate'] as String?;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumEntitlementKey, true);
    await prefs.setString(entitlementProductIdKey, entitlementProductId!);
    await prefs.setString(
      entitlementVerificationDataKey,
      entitlementVerificationData ?? '',
    );
    await prefs.setString(
      entitlementVerificationSourceKey,
      entitlementVerificationSource ?? '',
    );
    if (entitlementTransactionDate != null) {
      await prefs.setString(
        entitlementTransactionDateKey,
        entitlementTransactionDate!,
      );
    }
    await _verifyWithBackend(prefs);
  }

  Future<void> _verifyWithBackend(SharedPreferences prefs) async {
    final apiClient = _apiClient;
    final verificationData = entitlementVerificationData;
    if (apiClient == null ||
        verificationData == null ||
        verificationData.trim().isEmpty) {
      return;
    }

    try {
      final res = await apiClient.postJson('/api/v1/purchases/verify', {
        'product_id': entitlementProductId ?? proMonthlyProductId,
        'verification_data': verificationData,
        'verification_source': entitlementVerificationSource,
        'transaction_date': entitlementTransactionDate,
      });
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      serverVerified = data['verified'] == true;
      serverVerificationReason = data['reason'] as String?;
      await prefs.setBool(entitlementServerVerifiedKey, serverVerified);
      if (serverVerificationReason != null) {
        await prefs.setString(
          entitlementServerReasonKey,
          serverVerificationReason!,
        );
      } else {
        await prefs.remove(entitlementServerReasonKey);
      }
    } catch (_) {
      serverVerified = false;
      serverVerificationReason = 'verification_request_failed';
      await prefs.setBool(entitlementServerVerifiedKey, false);
      await prefs.setString(
        entitlementServerReasonKey,
        serverVerificationReason!,
      );
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
