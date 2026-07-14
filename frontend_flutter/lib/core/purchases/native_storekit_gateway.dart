import 'package:flutter/services.dart';

class NativeStoreKitRestoreResult {
  final List<Map<String, dynamic>> transactions;
  final String? environment;
  final String? syncError;
  final List<String> unverifiedProductIds;

  const NativeStoreKitRestoreResult({
    required this.transactions,
    this.environment,
    this.syncError,
    this.unverifiedProductIds = const [],
  });

  factory NativeStoreKitRestoreResult.fromMap(Map<dynamic, dynamic> value) {
    final rawTransactions = value['transactions'] as List<dynamic>? ?? const [];
    final rawUnverified =
        value['unverifiedProductIds'] as List<dynamic>? ?? const [];
    return NativeStoreKitRestoreResult(
      transactions: rawTransactions
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      environment: _nonEmptyString(value['environment']),
      syncError: _nonEmptyString(value['syncError']),
      unverifiedProductIds: rawUnverified
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

abstract interface class NativeStoreKitGateway {
  Future<List<Map<String, dynamic>>> queryProducts(Set<String> productIds);

  Future<Map<String, dynamic>?> purchase(String productId);

  Future<NativeStoreKitRestoreResult> restore(
    Set<String> productIds, {
    bool syncIfEmpty = true,
  });
}

class MethodChannelNativeStoreKitGateway implements NativeStoreKitGateway {
  static const MethodChannel _channel = MethodChannel('signalpath/storekit');

  const MethodChannelNativeStoreKitGateway();

  @override
  Future<List<Map<String, dynamic>>> queryProducts(
    Set<String> productIds,
  ) async {
    final products = await _channel.invokeListMethod<dynamic>(
      'queryProducts',
      {'ids': productIds.toList(growable: false)},
    );
    return products
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false) ??
        const [];
  }

  @override
  Future<Map<String, dynamic>?> purchase(String productId) async {
    final transaction = await _channel.invokeMapMethod<dynamic, dynamic>(
      'purchase',
      {'id': productId},
    );
    return transaction == null ? null : Map<String, dynamic>.from(transaction);
  }

  @override
  Future<NativeStoreKitRestoreResult> restore(
    Set<String> productIds, {
    bool syncIfEmpty = true,
  }) async {
    final value = await _channel.invokeMapMethod<dynamic, dynamic>(
      'restore',
      {
        'ids': productIds.toList(growable: false),
        'syncIfEmpty': syncIfEmpty,
      },
    );
    if (value == null) {
      return const NativeStoreKitRestoreResult(transactions: []);
    }
    return NativeStoreKitRestoreResult.fromMap(value);
  }
}
