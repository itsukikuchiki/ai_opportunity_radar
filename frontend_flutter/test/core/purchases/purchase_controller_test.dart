import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/diagnostics/privacy_safe_logger.dart';
import 'package:ai_opportunity_radar/core/purchases/native_storekit_gateway.dart';
import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('startup reads current StoreKit entitlement without account sync',
      () async {
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: NativeStoreKitRestoreResult(
        transactions: [
          _nativeTransaction(
            productId: PurchaseController.proMonthlyProductId,
            verificationData: '',
            verificationSource: 'storekit2_local_verified',
          ),
        ],
        environment: 'Production',
      ),
    );
    final controller = PurchaseController(
      purchaseStore: store,
      nativeStoreKitGateway: native,
      storeSupported: true,
      useNativeStoreKit: true,
      silentEntitlementRefreshOnInit: true,
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });

    await controller.init();

    expect(controller.isPremium, isTrue);
    expect(native.restoreCalls, 1);
    expect(native.syncIfEmptyValues, [false]);
    expect(store.restoreCalls, 0);
  });

  test('native active yearly entitlement restores and persists Pro', () async {
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: NativeStoreKitRestoreResult(
        transactions: [
          _nativeTransaction(
            productId: PurchaseController.proYearlyProductId,
          ),
        ],
        environment: 'Sandbox',
        unverifiedProductIds: const ['unrelated.product'],
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isTrue);
    expect(controller.restoring, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.restoreStatus, PurchaseRestoreStatus.restored);
    expect(controller.lastRestoreEnvironment, 'Sandbox');
    expect(
        controller.entitlementProductId, PurchaseController.proYearlyProductId);
    expect(controller.entitlementVerificationData, 'receipt-data');
    expect(controller.entitlementVerificationSource, 'app_store_receipt');
    expect(controller.entitlementEnvironment, 'Sandbox');
    expect(native.restoreCalls, 1);
    expect(store.restoreCalls, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PurchaseController.premiumEntitlementKey), isTrue);
    expect(
      prefs.getString(PurchaseController.entitlementProductIdKey),
      PurchaseController.proYearlyProductId,
    );
    expect(
      prefs.getString(PurchaseController.entitlementEnvironmentKey),
      'Sandbox',
    );
  });

  test('native sync failure falls back and waits for delayed restore stream',
      () async {
    final restoreStarted = Completer<void>();
    final store = _FakePurchaseStore(
      onRestore: () async {
        restoreStarted.complete();
      },
    );
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        environment: 'Sandbox',
        syncError: 'ASDErrorDomain#500',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    final restoreFuture = controller.restorePurchases();
    await restoreStarted.future;

    expect(controller.restoring, isTrue);
    expect(controller.isPremium, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.restoreStatus, PurchaseRestoreStatus.checkingStore);

    final purchase = _restoredPurchase(
      productId: PurchaseController.proMonthlyProductId,
    )..pendingCompletePurchase = true;
    store.emit([purchase]);
    await restoreFuture;

    expect(controller.isPremium, isTrue);
    expect(controller.restoring, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.restoreStatus, PurchaseRestoreStatus.restored);
    expect(store.completedPurchases, [purchase]);
  });

  test('empty TestFlight entitlement explains sandbox isolation', () async {
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        environment: 'Sandbox',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isFalse);
    expect(controller.errorMessage, PurchaseController.sandboxRestoreMessage);
    expect(controller.restoreStatus, PurchaseRestoreStatus.noEntitlement);
    expect(store.restoreCalls, 0);
  });

  test('iOS 13 and 14 native unavailable falls back to purchase plugin',
      () async {
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreError: PlatformException(
        code: 'UNAVAILABLE',
        message: 'StoreKit 2 requires iOS 15 or newer.',
      ),
    );
    final controller = _controller(
      store: store,
      native: native,
      gracePeriod: Duration.zero,
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(store.restoreCalls, 1);
    expect(controller.isPremium, isFalse);
    expect(
      controller.errorMessage,
      PurchaseController.noRestorableSubscriptionMessage,
    );
    expect(controller.restoreStatus, PurchaseRestoreStatus.noEntitlement);
  });

  test('native and plugin failures stay distinct from no subscription',
      () async {
    final store = _FakePurchaseStore(
      restoreError: StateError('store unavailable'),
    );
    final native = _FakeNativeStoreKitGateway(
      restoreError: PlatformException(
        code: 'RESTORE_FAILED',
        message: 'Could not sync.',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isFalse);
    expect(
      controller.errorMessage,
      PurchaseController.restoreTemporarilyUnavailableMessage,
    );
    expect(controller.restoreStatus, PurchaseRestoreStatus.failed);
  });

  test('same-environment explicit empty StoreKit result revokes local Pro',
      () async {
    SharedPreferences.setMockInitialValues({
      PurchaseController.premiumEntitlementKey: true,
      PurchaseController.entitlementProductIdKey:
          PurchaseController.proYearlyProductId,
      PurchaseController.entitlementEnvironmentKey: 'Production',
    });
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        environment: 'Production',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isFalse);
    expect(
      controller.errorMessage,
      PurchaseController.noRestorableSubscriptionMessage,
    );
    expect(controller.restoreStatus, PurchaseRestoreStatus.noEntitlement);
    expect(native.restoreCalls, 1);
    expect(store.restoreCalls, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PurchaseController.premiumEntitlementKey), isFalse);
    expect(
      prefs.getString(PurchaseController.entitlementProductIdKey),
      isNull,
    );
    expect(
      prefs.getString(PurchaseController.entitlementEnvironmentKey),
      isNull,
    );
  });

  test('same-environment silent empty StoreKit result revokes local Pro',
      () async {
    SharedPreferences.setMockInitialValues({
      PurchaseController.premiumEntitlementKey: true,
      PurchaseController.entitlementProductIdKey:
          PurchaseController.proYearlyProductId,
      PurchaseController.entitlementEnvironmentKey: 'Sandbox',
    });
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        environment: 'Sandbox',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.refreshCurrentEntitlements();

    expect(controller.isPremium, isFalse);
    expect(controller.restoreStatus, PurchaseRestoreStatus.noEntitlement);
    expect(native.syncIfEmptyValues, [false]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PurchaseController.premiumEntitlementKey), isFalse);
    expect(
      prefs.getString(PurchaseController.entitlementEnvironmentKey),
      isNull,
    );
  });

  test('cross-environment explicit empty result preserves local Pro', () async {
    SharedPreferences.setMockInitialValues({
      PurchaseController.premiumEntitlementKey: true,
      PurchaseController.entitlementProductIdKey:
          PurchaseController.proYearlyProductId,
      PurchaseController.entitlementEnvironmentKey: 'Production',
    });
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        environment: 'Sandbox',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isTrue);
    expect(controller.entitlementEnvironment, 'Production');
    expect(
      controller.errorMessage,
      PurchaseController.entitlementEnvironmentReconciliationMessage,
    );
    expect(controller.restoreStatus, PurchaseRestoreStatus.storeUnavailable);
    expect(native.restoreCalls, 1);
    expect(store.restoreCalls, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PurchaseController.premiumEntitlementKey), isTrue);
    expect(
      prefs.getString(PurchaseController.entitlementEnvironmentKey),
      'Production',
    );
  });

  test('unknown cached environment survives silent empty result', () async {
    SharedPreferences.setMockInitialValues({
      PurchaseController.premiumEntitlementKey: true,
      PurchaseController.entitlementProductIdKey:
          PurchaseController.proYearlyProductId,
    });
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        environment: 'Production',
      ),
    );
    final controller = _controller(store: store, native: native);
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.refreshCurrentEntitlements();

    expect(controller.isPremium, isTrue);
    expect(controller.entitlementEnvironment, isNull);
    expect(
      controller.errorMessage,
      PurchaseController.entitlementEnvironmentReconciliationMessage,
    );
    expect(controller.restoreStatus, PurchaseRestoreStatus.storeUnavailable);
  });

  test('existing local Pro stays unlocked when StoreKit recheck is uncertain',
      () async {
    SharedPreferences.setMockInitialValues({
      PurchaseController.premiumEntitlementKey: true,
      PurchaseController.entitlementProductIdKey:
          PurchaseController.proYearlyProductId,
    });
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        syncError: 'network unavailable',
      ),
    );
    final controller = _controller(
      store: store,
      native: native,
      gracePeriod: const Duration(milliseconds: 10),
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isTrue);
    expect(
      controller.errorMessage,
      PurchaseController.restoreTemporarilyUnavailableMessage,
    );
    expect(controller.restoreStatus, PurchaseRestoreStatus.storeUnavailable);
    expect(native.restoreCalls, 1);
    expect(store.restoreCalls, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PurchaseController.premiumEntitlementKey), isTrue);
  });

  test('unverified native entitlement does not revoke cached Pro', () async {
    SharedPreferences.setMockInitialValues({
      PurchaseController.premiumEntitlementKey: true,
    });
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        unverifiedProductIds: [PurchaseController.proMonthlyProductId],
      ),
    );
    final controller = _controller(
      store: store,
      native: native,
      gracePeriod: Duration.zero,
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isTrue);
    expect(controller.restoreStatus, PurchaseRestoreStatus.storeUnavailable);
    expect(native.restoreCalls, 1);
    expect(store.restoreCalls, 1);
  });

  test('plugin fallback accepts a StoreKit callback delayed by 1.2 seconds',
      () async {
    late _FakePurchaseStore store;
    store = _FakePurchaseStore(
      onRestore: () async {
        Timer(const Duration(milliseconds: 1200), () {
          store.emit([
            _restoredPurchase(
              productId: PurchaseController.proMonthlyProductId,
            ),
          ]);
        });
      },
    );
    final native = _FakeNativeStoreKitGateway(
      restoreResult: const NativeStoreKitRestoreResult(
        transactions: [],
        syncError: 'temporary sync failure',
      ),
    );
    final controller = _controller(
      store: store,
      native: native,
      gracePeriod: const Duration(seconds: 2),
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isTrue);
    expect(controller.restoreStatus, PurchaseRestoreStatus.restored);
    expect(controller.errorMessage, isNull);
  });

  test('StoreKit 2 JWS never reaches the legacy receipt backend', () async {
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: NativeStoreKitRestoreResult(
        transactions: [
          _nativeTransaction(
            productId: PurchaseController.proYearlyProductId,
            verificationData: 'header.payload.signature',
            verificationSource: 'storekit2_jws',
          ),
        ],
      ),
    );
    final api = _CountingApiClient();
    final controller = _controller(
      store: store,
      native: native,
      apiClient: api,
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(controller.isPremium, isTrue);
    expect(controller.restoreStatus, PurchaseRestoreStatus.restored);
    expect(controller.entitlementVerificationData, isEmpty);
    expect(
        controller.entitlementVerificationSource, 'storekit2_local_verified');
    expect(controller.serverVerified, isFalse);
    expect(api.calls, 0);
  });

  test('verified StoreKit unlocks immediately while backend retries', () async {
    final store = _FakePurchaseStore();
    final native = _FakeNativeStoreKitGateway(
      restoreResult: NativeStoreKitRestoreResult(
        transactions: [
          _nativeTransaction(
            productId: PurchaseController.proYearlyProductId,
          ),
        ],
        environment: 'Sandbox',
      ),
    );
    final api = _RetryingApiClient();
    final controller = _controller(
      store: store,
      native: native,
      apiClient: api,
      backendRetryDelay: Duration.zero,
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();
    await api.firstRequestStarted.future;

    expect(controller.isPremium, isTrue);
    expect(controller.serverVerified, isFalse);
    expect(controller.entitlementReconciliationPending, isTrue);
    expect(
      controller.restoreStatus,
      PurchaseRestoreStatus.verificationPending,
    );

    api.releaseFirstRequest.complete();
    await _waitFor(() => controller.serverVerified);

    expect(api.calls, 2);
    expect(controller.isPremium, isTrue);
    expect(controller.serverVerified, isTrue);
    expect(controller.restoreStatus, PurchaseRestoreStatus.restored);
  });

  test('purchase failures emit metadata without raw StoreKit details',
      () async {
    final records = <PrivacySafeLogRecord>[];
    final logger = PrivacySafeLogger(
      sink: records.add,
      idFactory: () => 'purchase-safe-reference',
    );
    final store = _FakePurchaseStore(
      restoreError: StateError('private account text from plugin'),
    );
    final native = _FakeNativeStoreKitGateway(
      restoreError: PlatformException(
        code: 'RESTORE_FAILED',
        message: 'private Apple account detail',
        details: '/private/device/path',
      ),
    );
    final controller = PurchaseController(
      purchaseStore: store,
      nativeStoreKitGateway: native,
      storeSupported: true,
      useNativeStoreKit: true,
      restoreStreamGracePeriod: Duration.zero,
      silentEntitlementRefreshOnInit: false,
      logger: logger,
    );
    addTearDown(() async {
      controller.dispose();
      await store.dispose();
    });
    await controller.init();

    await controller.restorePurchases();

    expect(records, isNotEmpty);
    final safeOutput = records.map((record) => record.toSafeLine()).join(' ');
    expect(safeOutput, isNot(contains('private account')));
    expect(safeOutput, isNot(contains('/private/device/path')));
    expect(safeOutput, isNot(contains('Apple account detail')));
    expect(
      records.map((record) => record.operation),
      containsAll([
        'purchase_restore_native',
        'purchase_restore_plugin',
      ]),
    );
  });
}

PurchaseController _controller({
  required _FakePurchaseStore store,
  required _FakeNativeStoreKitGateway native,
  Duration gracePeriod = const Duration(seconds: 1),
  ApiClient? apiClient,
  Duration backendRetryDelay = const Duration(seconds: 2),
}) {
  return PurchaseController(
    purchaseStore: store,
    nativeStoreKitGateway: native,
    storeSupported: true,
    useNativeStoreKit: true,
    restoreStreamGracePeriod: gracePeriod,
    apiClient: apiClient,
    backendVerificationRetryBaseDelay: backendRetryDelay,
    silentEntitlementRefreshOnInit: false,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 50; i += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not met before timeout');
}

Map<String, dynamic> _nativeTransaction({
  required String productId,
  String verificationData = 'receipt-data',
  String verificationSource = 'app_store_receipt',
}) =>
    {
      'productId': productId,
      'transactionId': 'transaction-1',
      'originalTransactionId': 'original-1',
      'purchaseDate': '2026-07-10T01:00:00Z',
      'verificationData': verificationData,
      'verificationSource': verificationSource,
      'environment': 'Sandbox',
    };

PurchaseDetails _restoredPurchase({required String productId}) {
  return PurchaseDetails(
    purchaseID: 'purchase-1',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-receipt',
      serverVerificationData: 'server-receipt',
      source: 'app_store',
    ),
    transactionDate: '1783645200000',
    status: PurchaseStatus.restored,
  );
}

class _FakePurchaseStore implements PurchaseStore {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final Future<void> Function()? onRestore;
  final Object? restoreError;

  int restoreCalls = 0;
  final List<PurchaseDetails> completedPurchases = [];

  _FakePurchaseStore({
    this.onRestore,
    this.restoreError,
  });

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: identifiers
          .map(
            (id) => ProductDetails(
              id: id,
              title: id,
              description: '',
              price: id == PurchaseController.proYearlyProductId
                  ? r'$29.99'
                  : r'$2.99',
              rawPrice:
                  id == PurchaseController.proYearlyProductId ? 29.99 : 2.99,
              currencyCode: 'USD',
            ),
          )
          .toList(growable: false),
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
    final error = restoreError;
    if (error != null) throw error;
    await onRestore?.call();
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  void emit(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }

  Future<void> dispose() => _controller.close();
}

class _FakeNativeStoreKitGateway implements NativeStoreKitGateway {
  final NativeStoreKitRestoreResult? restoreResult;
  final Object? restoreError;

  int restoreCalls = 0;
  final List<bool> syncIfEmptyValues = [];

  _FakeNativeStoreKitGateway({
    this.restoreResult,
    this.restoreError,
  });

  @override
  Future<List<Map<String, dynamic>>> queryProducts(
    Set<String> productIds,
  ) async =>
      const [];

  @override
  Future<Map<String, dynamic>?> purchase(String productId) async => null;

  @override
  Future<NativeStoreKitRestoreResult> restore(
    Set<String> productIds, {
    bool syncIfEmpty = true,
  }) async {
    restoreCalls += 1;
    syncIfEmptyValues.add(syncIfEmpty);
    final error = restoreError;
    if (error != null) throw error;
    return restoreResult ?? const NativeStoreKitRestoreResult(transactions: []);
  }
}

class _RetryingApiClient extends ApiClient {
  final Completer<void> firstRequestStarted = Completer<void>();
  final Completer<void> releaseFirstRequest = Completer<void>();
  int calls = 0;

  _RetryingApiClient() : super(baseUrl: 'https://example.invalid', userId: 'u');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    calls += 1;
    if (calls == 1) {
      firstRequestStarted.complete();
      await releaseFirstRequest.future;
      throw StateError('temporary verification outage');
    }
    return {
      'data': {'verified': true, 'reason': 'verified'},
    };
  }
}

class _CountingApiClient extends ApiClient {
  int calls = 0;

  _CountingApiClient() : super(baseUrl: 'https://example.invalid', userId: 'u');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    calls += 1;
    return {
      'data': {'verified': true, 'reason': 'verified'},
    };
  }
}
