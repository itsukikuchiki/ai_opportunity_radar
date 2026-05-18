import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      NativeStoreKitBridge.register(with: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class NativeStoreKitBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "signalpath/storekit",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      if #available(iOS 15.0, *) {
        handle(call: call, result: result)
      } else {
        result(FlutterError(
          code: "UNAVAILABLE",
          message: "StoreKit 2 requires iOS 15 or newer.",
          details: nil
        ))
      }
    }
  }

  @available(iOS 15.0, *)
  private static func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "queryProducts":
      guard
        let args = call.arguments as? [String: Any],
        let ids = args["ids"] as? [String]
      else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing product ids.", details: nil))
        return
      }
      Task {
        do {
          let products = try await Product.products(for: ids)
          result(products.map(productMap))
        } catch {
          result(FlutterError(
            code: "QUERY_FAILED",
            message: error.localizedDescription,
            details: "\(error)"
          ))
        }
      }
    case "purchase":
      guard
        let args = call.arguments as? [String: Any],
        let id = args["id"] as? String
      else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing product id.", details: nil))
        return
      }
      Task {
        do {
          guard let product = try await Product.products(for: [id]).first else {
            result(FlutterError(
              code: "PRODUCT_NOT_FOUND",
              message: "Product was not returned by StoreKit.",
              details: id
            ))
            return
          }
          let purchaseResult = try await product.purchase()
          switch purchaseResult {
          case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            result(transactionMap(transaction, verification: verification))
          case .pending:
            result(FlutterError(
              code: "PURCHASE_PENDING",
              message: "The purchase is pending approval.",
              details: nil
            ))
          case .userCancelled:
            result(FlutterError(
              code: "PURCHASE_CANCELLED",
              message: "The purchase was cancelled.",
              details: nil
            ))
          @unknown default:
            result(FlutterError(
              code: "PURCHASE_UNKNOWN",
              message: "The store returned an unknown purchase result.",
              details: nil
            ))
          }
        } catch {
          result(FlutterError(
            code: "PURCHASE_FAILED",
            message: error.localizedDescription,
            details: "\(error)"
          ))
        }
      }
    case "restore":
      Task {
        do {
          var restored: [[String: Any]] = []
          for await verification in Transaction.currentEntitlements {
            let transaction = try checkVerified(verification)
            restored.append(transactionMap(transaction, verification: verification))
          }
          result(restored)
        } catch {
          result(FlutterError(
            code: "RESTORE_FAILED",
            message: error.localizedDescription,
            details: "\(error)"
          ))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 15.0, *)
  private static func productMap(_ product: Product) -> [String: Any] {
    return [
      "id": product.id,
      "title": product.displayName,
      "description": product.description,
      "price": product.displayPrice,
      "rawPrice": NSDecimalNumber(decimal: product.price).doubleValue,
      "currencyCode": product.priceFormatStyle.currencyCode
    ]
  }

  @available(iOS 15.0, *)
  private static func transactionMap(
    _ transaction: Transaction,
    verification: VerificationResult<Transaction>
  ) -> [String: Any] {
    return [
      "productId": transaction.productID,
      "transactionId": String(transaction.id),
      "originalTransactionId": String(transaction.originalID),
      "purchaseDate": ISO8601DateFormatter().string(from: transaction.purchaseDate),
      "verificationData": verification.jwsRepresentation,
      "verificationSource": "storekit2"
    ]
  }

  @available(iOS 15.0, *)
  private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .verified(let safe):
      return safe
    case .unverified(_, let error):
      throw error
    }
  }
}
