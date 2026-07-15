import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/build_environment.dart';
import '../diagnostics/privacy_safe_logger.dart';
import 'native_storekit_gateway.dart';

abstract interface class PurchaseStore {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

class DefaultPurchaseStore implements PurchaseStore {
  final InAppPurchase _store;

  DefaultPurchaseStore([InAppPurchase? store])
      : _store = store ?? InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) =>
      _store.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _store.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _store.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}

enum PurchaseRestoreStatus {
  idle,
  checkingStore,
  restored,
  noEntitlement,
  storeUnavailable,
  verificationPending,
  failed,
}

class PurchaseController extends ChangeNotifier {
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
  static const String entitlementEnvironmentKey =
      'premium_entitlement_environment';
  static const String entitlementServerVerifiedKey =
      'premium_entitlement_server_verified';
  static const String entitlementServerReasonKey =
      'premium_entitlement_server_reason';
  static const String noRestorableSubscriptionMessage =
      'No active Pro subscription was found in this StoreKit environment.';
  static const String restoreTemporarilyUnavailableMessage =
      'Unable to restore purchases right now. Please try again from App Store purchases.';
  static const String sandboxRestoreMessage =
      'This TestFlight or sandbox build can only restore Pro purchased in the same sandbox environment.';
  static const String localStoreKitRestoreMessage =
      'This development build can only restore purchases made in its StoreKit test environment.';
  static const String entitlementEnvironmentReconciliationMessage =
      'Pro was verified in another or unknown StoreKit environment. Access is kept while the entitlement is reconciled.';

  final PurchaseStore _purchaseStore;
  final NativeStoreKitGateway _nativeStoreKitGateway;
  final ApiClient? _apiClient;
  final bool _storeSupported;
  final bool _useNativeStoreKit;
  final Duration _restoreStreamGracePeriod;
  final Duration _backendVerificationRetryBaseDelay;
  final int _backendVerificationMaxAttempts;
  final bool _silentEntitlementRefreshOnInit;
  final bool _qaShowcaseMode;
  final PrivacySafeLogger _logger;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _backendVerificationRetryTimer;
  Completer<bool>? _restoreAttempt;
  Future<void>? _initFuture;
  int _backendVerificationGeneration = 0;
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
  String? entitlementEnvironment;
  bool serverVerified = false;
  String? serverVerificationReason;
  String? lastRestoreEnvironment;
  PurchaseRestoreStatus restoreStatus = PurchaseRestoreStatus.idle;

  PurchaseController({
    PurchaseStore? purchaseStore,
    NativeStoreKitGateway? nativeStoreKitGateway,
    ApiClient? apiClient,
    bool? storeSupported,
    bool? useNativeStoreKit,
    Duration restoreStreamGracePeriod = const Duration(seconds: 6),
    Duration backendVerificationRetryBaseDelay = const Duration(seconds: 2),
    int backendVerificationMaxAttempts = 3,
    bool silentEntitlementRefreshOnInit = true,
    bool qaShowcaseMode = BuildEnvironment.qaShowcaseData,
    PrivacySafeLogger? logger,
  })  : _purchaseStore = purchaseStore ?? DefaultPurchaseStore(),
        _nativeStoreKitGateway =
            nativeStoreKitGateway ?? const MethodChannelNativeStoreKitGateway(),
        _apiClient = apiClient,
        _storeSupported = storeSupported ?? _platformSupportsStore,
        _useNativeStoreKit = useNativeStoreKit ?? _platformCanUseNativeStoreKit,
        _restoreStreamGracePeriod = restoreStreamGracePeriod,
        _backendVerificationRetryBaseDelay = backendVerificationRetryBaseDelay,
        _backendVerificationMaxAttempts = backendVerificationMaxAttempts,
        _silentEntitlementRefreshOnInit = silentEntitlementRefreshOnInit,
        _qaShowcaseMode = qaShowcaseMode,
        _logger = logger ?? PrivacySafeLogger.instance {
    if (_storeSupported && !_qaShowcaseMode) {
      try {
        _purchaseSubscription = _purchaseStore.purchaseStream.listen(
          _handlePurchaseUpdates,
          onError: (Object error) {
            _capturePurchaseException(
              error,
              StackTrace.current,
              operation: 'purchase_stream',
            );
            purchasePending = false;
            errorMessage = _friendlyPurchaseError(error);
            if (restoring) {
              restoreStatus = PurchaseRestoreStatus.failed;
            }
            _completeRestoreAttempt(false);
            notifyListeners();
          },
        );
      } catch (error, stackTrace) {
        _capturePurchaseException(
          error,
          stackTrace,
          operation: 'purchase_stream_setup',
        );
        errorMessage = 'Purchases are temporarily unavailable.';
      }
    }
    init();
  }

  ProductDetails? get proMonthlyProduct => _proProducts[proMonthlyProductId];

  ProductDetails? get proYearlyProduct => _proProducts[proYearlyProductId];

  String get proMonthlyDisplayPrice => proMonthlyProduct?.price ?? '\$2.99';

  String get proYearlyDisplayPrice => proYearlyProduct?.price ?? '\$29.99';

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
      !isPremium && storeAvailable && _useNativeStoreKit && !purchasePending;

  bool get entitlementReconciliationPending =>
      isPremium &&
      !serverVerified &&
      _hasLegacyReceiptForBackendVerification &&
      _apiClient != null;

  bool get _hasLegacyReceiptForBackendVerification {
    if (entitlementVerificationData?.trim().isNotEmpty != true) return false;
    final source = entitlementVerificationSource?.trim().toLowerCase();
    return source == 'app_store_receipt' || source == 'app_store';
  }

  static bool get _platformSupportsStore {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool get _platformCanUseNativeStoreKit {
    if (kIsWeb) return false;
    return Platform.isIOS;
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

    if (_qaShowcaseMode) {
      isPremium = true;
      storeAvailable = false;
      entitlementProductId = 'qa_showcase_preview';
      entitlementVerificationSource = 'qa_showcase';
      serverVerified = true;
      serverVerificationReason = null;
      restoreStatus = PurchaseRestoreStatus.restored;
      loading = false;
      notifyListeners();
      return;
    }

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
      entitlementEnvironment = prefs.getString(entitlementEnvironmentKey);
      serverVerified = prefs.getBool(entitlementServerVerifiedKey) ?? false;
      serverVerificationReason = prefs.getString(entitlementServerReasonKey);

      if (isPremium) {
        restoreStatus = entitlementReconciliationPending
            ? PurchaseRestoreStatus.verificationPending
            : PurchaseRestoreStatus.restored;
        if (entitlementReconciliationPending) {
          _startBackendVerification(prefs);
        }
      }

      if (!_storeSupported) {
        storeAvailable = false;
        return;
      }

      storeAvailable = await _purchaseStore.isAvailable();
      if (!storeAvailable) {
        return;
      }

      final response = await _purchaseStore.queryProductDetails(proProductIds);

      if (response.error != null) {
        _capturePurchaseException(
          response.error!,
          StackTrace.current,
          operation: 'purchase_products_response',
        );
        errorMessage = 'Purchases are temporarily unavailable.';
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
      if (_silentEntitlementRefreshOnInit) {
        await refreshCurrentEntitlements(notify: false);
      }
    } catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'purchase_products_load',
      );
      errorMessage = 'Purchases are temporarily unavailable.';
      await _loadNativeStoreKitProducts();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool _shouldUseNativeStoreKitFallback(ProductDetailsResponse response) {
    if (!_useNativeStoreKit) return false;
    return response.productDetails.isEmpty || response.error != null;
  }

  Future<void> _loadNativeStoreKitProducts() async {
    if (!_useNativeStoreKit) return;

    try {
      final products =
          await _nativeStoreKitGateway.queryProducts(proProductIds);
      if (products.isEmpty) {
        errorMessage = null;
        return;
      }

      _nativeStoreKitProductIds.clear();
      _proProducts
        ..clear()
        ..addEntries(products.map((data) {
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
    } on PlatformException catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'storekit_products_load',
      );
      errorMessage = 'Purchases are temporarily unavailable.';
    } catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'storekit_products_load',
      );
      errorMessage = 'Purchases are temporarily unavailable.';
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
      if (_useNativeStoreKit) {
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
      started = await _purchaseStore.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'purchase_start',
      );
      purchasePending = false;
      errorMessage = _friendlyPurchaseError(error);
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
      final transaction = await _nativeStoreKitGateway.purchase(productId);
      if (transaction == null) {
        errorMessage = 'The store did not return a transaction.';
        return;
      }
      await _activatePremiumFromNativeStoreKit(transaction);
      errorMessage = null;
    } on PlatformException catch (error, stackTrace) {
      if (error.code != 'PURCHASE_CANCELLED') {
        _capturePurchaseException(
          error,
          stackTrace,
          operation: 'storekit_purchase',
        );
        errorMessage = _friendlyPurchaseError(error);
      }
    } catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'storekit_purchase',
      );
      errorMessage = _friendlyPurchaseError(error);
    } finally {
      purchasePending = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (restoring) return;

    final hadLocalPremium = isPremium;

    _purchaseLog(
      'restore start isPremium=$isPremium platformNative=$_useNativeStoreKit',
    );
    restoring = true;
    errorMessage = null;
    lastRestoreEnvironment = null;
    restoreStatus = PurchaseRestoreStatus.checkingStore;
    notifyListeners();

    try {
      if (!_storeSupported) {
        _purchaseLog('restore unavailable: unsupported platform');
        errorMessage = 'Purchases are not available on this platform.';
        restoreStatus = PurchaseRestoreStatus.storeUnavailable;
        return;
      }

      Object? nativeFailure;
      if (_useNativeStoreKit) {
        try {
          final result = await _nativeStoreKitGateway.restore(proProductIds);
          lastRestoreEnvironment = result.environment;
          final purchases = result.transactions
              .where(
                (item) => proProductIds.contains(item['productId'] as String?),
              )
              .toList(growable: false);
          _purchaseLog(
            'restore native returned count=${result.transactions.length} '
            'environment=${result.environment ?? 'unknown'} '
            'syncError=${result.syncError != null} '
            'unverifiedCount=${result.unverifiedProductIds.length}',
          );
          _purchaseLog(
            'restore native pro matches count=${purchases.length} '
            'products=${_productIdsForLog(purchases)}',
          );
          if (purchases.isNotEmpty) {
            await _activatePremiumFromNativeStoreKit(
              purchases.first,
              fallbackEnvironment: result.environment,
            );
            errorMessage = null;
            restoreStatus = entitlementReconciliationPending
                ? PurchaseRestoreStatus.verificationPending
                : PurchaseRestoreStatus.restored;
            return;
          }

          final hasUnverifiedProEntitlement = result.unverifiedProductIds.any(
            proProductIds.contains,
          );
          if (result.syncError == null && !hasUnverifiedProEntitlement) {
            _purchaseLog('restore native completed with no Pro entitlement');
            if (!hadLocalPremium ||
                _sameKnownStoreEnvironment(
                  entitlementEnvironment,
                  result.environment,
                )) {
              await _deactivatePremium();
              errorMessage = _emptyRestoreMessage(result.environment);
              restoreStatus = PurchaseRestoreStatus.noEntitlement;
            } else {
              _purchaseLog(
                'restore empty environment mismatch cached=${entitlementEnvironment ?? 'unknown'} current=${result.environment ?? 'unknown'}; preserving Pro',
              );
              errorMessage = entitlementEnvironmentReconciliationMessage;
              restoreStatus = PurchaseRestoreStatus.storeUnavailable;
            }
            return;
          }
          nativeFailure = result.syncError ??
              'StoreKit returned an unverified Pro entitlement.';
          _purchaseLog(
            'restore native refresh failed; trying plugin fallback',
          );
        } on PlatformException catch (error, stackTrace) {
          if (error.code != 'UNAVAILABLE') {
            nativeFailure = error;
          }
          _capturePurchaseException(
            error,
            stackTrace,
            operation: 'purchase_restore_native',
          );
          _purchaseLog('restore native unavailable; trying plugin fallback');
        } catch (error, stackTrace) {
          nativeFailure = error;
          _capturePurchaseException(
            error,
            stackTrace,
            operation: 'purchase_restore_native',
          );
          _purchaseLog('restore native failed; trying plugin fallback');
        }
      }

      final pluginRestored = await _restoreThroughPurchaseStream();
      if (pluginRestored) {
        errorMessage = null;
        restoreStatus = entitlementReconciliationPending
            ? PurchaseRestoreStatus.verificationPending
            : PurchaseRestoreStatus.restored;
        return;
      }

      if (hadLocalPremium) {
        _purchaseLog(
          'restore was inconclusive; retaining the locally verified entitlement',
        );
        errorMessage = _restoreFailureMessage(lastRestoreEnvironment);
        restoreStatus = entitlementReconciliationPending
            ? PurchaseRestoreStatus.verificationPending
            : PurchaseRestoreStatus.storeUnavailable;
      } else if (nativeFailure != null) {
        _purchaseLog('restore failed after native and plugin paths');
        errorMessage = _restoreFailureMessage(lastRestoreEnvironment);
        restoreStatus = PurchaseRestoreStatus.storeUnavailable;
      } else {
        errorMessage = _emptyRestoreMessage(lastRestoreEnvironment);
        restoreStatus = PurchaseRestoreStatus.noEntitlement;
      }
    } catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'purchase_restore_plugin',
      );
      errorMessage = _restoreFailureMessage(lastRestoreEnvironment);
      restoreStatus = PurchaseRestoreStatus.failed;
    } finally {
      _purchaseLog('restore end status=${restoreStatus.name}');
      _restoreAttempt = null;
      restoring = false;
      notifyListeners();
    }
  }

  /// Reads StoreKit 2's current entitlement snapshot without presenting UI or
  /// calling AppStore.sync(). This is safe on launch/foreground; explicit
  /// restore remains the only path that asks Apple to synchronize accounts.
  Future<void> refreshCurrentEntitlements({bool notify = true}) async {
    if (!_storeSupported || !_useNativeStoreKit) return;
    try {
      final result = await _nativeStoreKitGateway.restore(
        proProductIds,
        syncIfEmpty: false,
      );
      lastRestoreEnvironment = result.environment;
      final purchases = result.transactions
          .where(
            (item) => proProductIds.contains(item['productId'] as String?),
          )
          .toList(growable: false);
      if (purchases.isNotEmpty) {
        await _activatePremiumFromNativeStoreKit(
          purchases.first,
          fallbackEnvironment: result.environment,
        );
        restoreStatus = entitlementReconciliationPending
            ? PurchaseRestoreStatus.verificationPending
            : PurchaseRestoreStatus.restored;
      } else if (result.unverifiedProductIds.any(proProductIds.contains)) {
        // An unverified result is inconclusive; preserve a previously verified
        // local unlock instead of turning a store issue into a revoke.
      } else {
        if (!isPremium ||
            _sameKnownStoreEnvironment(
              entitlementEnvironment,
              result.environment,
            )) {
          await _deactivatePremium();
          errorMessage = null;
          restoreStatus = PurchaseRestoreStatus.noEntitlement;
        } else {
          _purchaseLog(
            'silent empty environment mismatch cached=${entitlementEnvironment ?? 'unknown'} current=${result.environment ?? 'unknown'}; preserving Pro',
          );
          errorMessage = entitlementEnvironmentReconciliationMessage;
          restoreStatus = PurchaseRestoreStatus.storeUnavailable;
        }
      }
    } catch (error, stackTrace) {
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'purchase_entitlement_refresh',
      );
      // Silent checks never replace an existing entitlement with an error.
    } finally {
      if (notify) notifyListeners();
    }
  }

  Future<bool> _restoreThroughPurchaseStream() async {
    _purchaseLog('restore using in_app_purchase restorePurchases fallback');
    final attempt = Completer<bool>();
    _restoreAttempt = attempt;
    await _purchaseStore.restorePurchases();

    return attempt.future.timeout(
      _restoreStreamGracePeriod,
      onTimeout: () => false,
    );
  }

  Future<void> unlockForLocalTesting() async {
    await _activatePremium();
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    var sawProPurchase = false;
    for (final purchase in purchases) {
      if (!proProductIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _purchaseStore.completePurchase(purchase);
        }
        continue;
      }
      sawProPurchase = true;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          errorMessage = null;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchaseLog(
            'purchase stream ${purchase.status.name} product=${purchase.productID} source=${purchase.verificationData.source}',
          );
          await _activatePremium(purchase);
          purchasePending = false;
          errorMessage = null;
          _completeRestoreAttempt(true);
          break;
        case PurchaseStatus.error:
          final purchaseError = purchase.error;
          if (purchaseError != null) {
            _capturePurchaseException(
              purchaseError,
              StackTrace.current,
              operation: 'purchase_stream_status',
            );
          }
          purchasePending = false;
          errorMessage = _friendlyPurchaseError(purchaseError);
          if (restoring) {
            restoreStatus = PurchaseRestoreStatus.failed;
          }
          _completeRestoreAttempt(false);
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          _completeRestoreAttempt(false);
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _purchaseStore.completePurchase(purchase);
      }
    }

    if (purchases.isEmpty || !sawProPurchase) {
      _completeRestoreAttempt(false);
    }

    notifyListeners();
  }

  void _completeRestoreAttempt(bool restored) {
    final attempt = _restoreAttempt;
    if (attempt != null && !attempt.isCompleted) {
      attempt.complete(restored);
    }
  }

  Future<void> _activatePremium([PurchaseDetails? purchase]) async {
    isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumEntitlementKey, true);

    if (purchase == null) {
      restoreStatus = PurchaseRestoreStatus.restored;
      return;
    }

    _purchaseLog(
        'activate premium product=${purchase.productID} source=${purchase.verificationData.source}');
    entitlementProductId = purchase.productID;
    entitlementVerificationData =
        purchase.verificationData.serverVerificationData.isNotEmpty
            ? purchase.verificationData.serverVerificationData
            : purchase.verificationData.localVerificationData;
    entitlementVerificationSource = purchase.verificationData.source;
    entitlementTransactionDate = purchase.transactionDate;
    // The legacy plugin callback does not expose a trustworthy StoreKit
    // environment. Keep it unknown so a later empty snapshot cannot revoke a
    // verified unlock across Sandbox/Production boundaries.
    entitlementEnvironment = null;
    serverVerified = false;
    serverVerificationReason = 'verification_pending';

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
    await prefs.remove(entitlementEnvironmentKey);
    await prefs.setBool(entitlementServerVerifiedKey, false);
    await prefs.setString(
      entitlementServerReasonKey,
      serverVerificationReason!,
    );
    _startBackendVerification(prefs, resetAttempts: true);
  }

  Future<void> _activatePremiumFromNativeStoreKit(
    Map<String, dynamic> transaction, {
    String? fallbackEnvironment,
  }) async {
    isPremium = true;
    entitlementProductId =
        transaction['productId'] as String? ?? proMonthlyProductId;
    _purchaseLog(
      'activate premium native product=$entitlementProductId',
    );
    final rawVerificationSource =
        transaction['verificationSource'] as String? ??
            'storekit2_local_verified';
    final hasAppReceipt =
        rawVerificationSource.trim().toLowerCase() == 'app_store_receipt';
    entitlementVerificationData =
        hasAppReceipt ? transaction['verificationData'] as String? : '';
    entitlementVerificationSource =
        hasAppReceipt ? 'app_store_receipt' : 'storekit2_local_verified';
    entitlementTransactionDate = transaction['purchaseDate'] as String?;
    entitlementEnvironment = _knownStoreEnvironment(
      transaction['environment'] as String? ?? fallbackEnvironment,
    );
    serverVerified = false;
    serverVerificationReason =
        entitlementVerificationData?.trim().isNotEmpty == true
            ? 'verification_pending'
            : 'app_receipt_unavailable';

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
    if (entitlementEnvironment == null) {
      await prefs.remove(entitlementEnvironmentKey);
    } else {
      await prefs.setString(
        entitlementEnvironmentKey,
        entitlementEnvironment!,
      );
    }
    await prefs.setBool(entitlementServerVerifiedKey, false);
    await prefs.setString(
      entitlementServerReasonKey,
      serverVerificationReason!,
    );
    _startBackendVerification(prefs, resetAttempts: true);
  }

  Future<void> _deactivatePremium() async {
    _backendVerificationGeneration += 1;
    _backendVerificationRetryTimer?.cancel();
    isPremium = false;
    entitlementProductId = null;
    entitlementVerificationData = null;
    entitlementVerificationSource = null;
    entitlementTransactionDate = null;
    entitlementEnvironment = null;
    serverVerified = false;
    serverVerificationReason = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(premiumEntitlementKey, false);
    await Future.wait([
      prefs.remove(entitlementProductIdKey),
      prefs.remove(entitlementVerificationDataKey),
      prefs.remove(entitlementVerificationSourceKey),
      prefs.remove(entitlementTransactionDateKey),
      prefs.remove(entitlementEnvironmentKey),
      prefs.remove(entitlementServerVerifiedKey),
      prefs.remove(entitlementServerReasonKey),
    ]);
  }

  void _startBackendVerification(
    SharedPreferences prefs, {
    bool resetAttempts = false,
  }) {
    final apiClient = _apiClient;
    final verificationData = entitlementVerificationData;
    if (apiClient == null ||
        verificationData == null ||
        !_hasLegacyReceiptForBackendVerification) {
      _purchaseLog(
        'backend verify skipped apiClient=${apiClient != null} verificationDataPresent=${verificationData?.trim().isNotEmpty == true}',
      );
      serverVerified = false;
      serverVerificationReason ??= 'app_receipt_unavailable';
      restoreStatus = PurchaseRestoreStatus.restored;
      return;
    }

    _backendVerificationRetryTimer?.cancel();
    if (resetAttempts) {
      _backendVerificationGeneration += 1;
    }
    final generation = _backendVerificationGeneration;
    serverVerified = false;
    serverVerificationReason = 'verification_pending';
    restoreStatus = PurchaseRestoreStatus.verificationPending;
    unawaited(
      _persistPendingAndVerify(
        prefs,
        generation: generation,
      ),
    );
  }

  Future<void> _persistPendingAndVerify(
    SharedPreferences prefs, {
    required int generation,
  }) async {
    await prefs.setBool(entitlementServerVerifiedKey, false);
    await prefs.setString(
      entitlementServerReasonKey,
      serverVerificationReason!,
    );
    await _verifyWithBackend(
      prefs,
      generation: generation,
      attempt: 0,
    );
  }

  Future<void> _verifyWithBackend(
    SharedPreferences prefs, {
    required int generation,
    required int attempt,
  }) async {
    if (generation != _backendVerificationGeneration) return;
    final apiClient = _apiClient;
    final verificationData = entitlementVerificationData;
    if (apiClient == null ||
        verificationData == null ||
        verificationData.trim().isEmpty) {
      return;
    }

    try {
      _purchaseLog(
        'backend verify start product=${entitlementProductId ?? proMonthlyProductId} source=$entitlementVerificationSource',
      );
      final res = await apiClient.postJson('/api/v1/purchases/verify', {
        'product_id': entitlementProductId ?? proMonthlyProductId,
        'verification_data': verificationData,
        'verification_source': entitlementVerificationSource,
        'transaction_date': entitlementTransactionDate,
      });
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      if (generation != _backendVerificationGeneration) return;
      serverVerified = data['verified'] == true;
      serverVerificationReason = data['reason'] as String?;
      _purchaseLog(
        'backend verify result verified=$serverVerified',
      );
      await prefs.setBool(entitlementServerVerifiedKey, serverVerified);
      if (serverVerificationReason != null) {
        await prefs.setString(
          entitlementServerReasonKey,
          serverVerificationReason!,
        );
      } else {
        await prefs.remove(entitlementServerReasonKey);
      }
      if (serverVerified) {
        _backendVerificationRetryTimer?.cancel();
        restoreStatus = PurchaseRestoreStatus.restored;
      } else {
        restoreStatus = PurchaseRestoreStatus.verificationPending;
        _scheduleBackendVerificationRetry(
          prefs,
          generation: generation,
          attempt: attempt + 1,
        );
      }
    } catch (error, stackTrace) {
      if (generation != _backendVerificationGeneration) return;
      serverVerified = false;
      serverVerificationReason = 'verification_request_failed';
      restoreStatus = PurchaseRestoreStatus.verificationPending;
      _capturePurchaseException(
        error,
        stackTrace,
        operation: 'purchase_backend_verification',
      );
      await prefs.setBool(entitlementServerVerifiedKey, false);
      await prefs.setString(
        entitlementServerReasonKey,
        serverVerificationReason!,
      );
      _scheduleBackendVerificationRetry(
        prefs,
        generation: generation,
        attempt: attempt + 1,
      );
    }
    notifyListeners();
  }

  void _scheduleBackendVerificationRetry(
    SharedPreferences prefs, {
    required int generation,
    required int attempt,
  }) {
    if (generation != _backendVerificationGeneration ||
        attempt >= _backendVerificationMaxAttempts) {
      return;
    }
    final exponent = attempt <= 1 ? 0 : (attempt > 9 ? 8 : attempt - 1);
    final multiplier = 1 << exponent;
    final delay = _backendVerificationRetryBaseDelay * multiplier;
    _backendVerificationRetryTimer?.cancel();
    _backendVerificationRetryTimer = Timer(delay, () {
      unawaited(
        _verifyWithBackend(
          prefs,
          generation: generation,
          attempt: attempt,
        ),
      );
    });
  }

  void _purchaseLog(String message) {
    debugPrint('[SignalPath][Purchase] $message');
  }

  void _capturePurchaseException(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    _logger.capture(
      error,
      stackTrace,
      operation: operation,
    );
  }

  String _productIdsForLog(List<Map<String, dynamic>> purchases) {
    final ids = purchases
        .map((item) => item['productId']?.toString())
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toList();
    return ids.isEmpty ? 'none' : ids.join(',');
  }

  String _emptyRestoreMessage(String? environment) {
    final normalized = environment?.trim().toLowerCase() ?? '';
    if (normalized.contains('sandbox')) {
      return sandboxRestoreMessage;
    }
    if (normalized.contains('xcode') || normalized.contains('local')) {
      return localStoreKitRestoreMessage;
    }
    return noRestorableSubscriptionMessage;
  }

  bool _sameKnownStoreEnvironment(String? cached, String? current) {
    final normalizedCached = _knownStoreEnvironment(cached);
    final normalizedCurrent = _knownStoreEnvironment(current);
    return normalizedCached != null && normalizedCached == normalizedCurrent;
  }

  String? _knownStoreEnvironment(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.contains('sandbox')) return 'Sandbox';
    if (normalized.contains('production')) return 'Production';
    if (normalized.contains('xcode') || normalized.contains('local')) {
      return 'Xcode';
    }
    return null;
  }

  String _restoreFailureMessage(String? environment) {
    final normalized = environment?.trim().toLowerCase() ?? '';
    if (normalized.contains('sandbox')) {
      return sandboxRestoreMessage;
    }
    if (normalized.contains('xcode') || normalized.contains('local')) {
      return localStoreKitRestoreMessage;
    }
    return restoreTemporarilyUnavailableMessage;
  }

  String _friendlyPurchaseError(Object? error) {
    if (error is PlatformException && error.code == 'RESTORE_FAILED') {
      return restoreTemporarilyUnavailableMessage;
    }
    return 'Purchase failed. Please try again.';
  }

  @override
  void dispose() {
    _backendVerificationGeneration += 1;
    _backendVerificationRetryTimer?.cancel();
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
