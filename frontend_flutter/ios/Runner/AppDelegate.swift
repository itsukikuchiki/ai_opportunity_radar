import Flutter
import EventKit
import HealthKit
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
      ExternalEnergyBridge.register(with: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class ExternalEnergyBridge {
  private static let eventStore = EKEventStore()
  private static let healthStore = HKHealthStore()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "signalpath/external_energy",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "calendarPermissionStatus":
        result(calendarPermissionStatus())
      case "healthPermissionStatus":
        result(healthPermissionStatus())
      case "requestCalendarScheduleHints":
        requestCalendarScheduleHints(result: result)
      case "requestHealthRecoveryHints":
        requestHealthRecoveryHints(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func calendarPermissionStatus() -> String {
    if #available(iOS 17.0, *) {
      switch EKEventStore.authorizationStatus(for: .event) {
      case .fullAccess:
        return "authorized"
      case .writeOnly:
        return "denied"
      case .denied, .restricted:
        return "denied"
      case .notDetermined:
        return "not_requested"
      @unknown default:
        return "unavailable"
      }
    }
    switch EKEventStore.authorizationStatus(for: .event) {
    case .authorized:
      return "authorized"
    case .denied, .restricted:
      return "denied"
    case .notDetermined:
      return "not_requested"
    @unknown default:
      return "unavailable"
    }
  }

  private static func requestCalendarScheduleHints(result: @escaping FlutterResult) {
    let finish: (Bool) -> Void = { granted in
      guard granted else {
        DispatchQueue.main.async {
          result(["permission_status": "denied", "blocks": []])
        }
        return
      }
      let calendar = Calendar.current
      let start = calendar.startOfDay(for: Date())
      let end = calendar.date(byAdding: .day, value: 7, to: start) ?? Date()
      let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
      let blocks = eventStore.events(matching: predicate)
        .filter { !$0.isAllDay }
        .map { event in
          [
            "start_at": ISO8601DateFormatter().string(from: event.startDate),
            "end_at": ISO8601DateFormatter().string(from: event.endDate),
            "is_busy": event.availability != .free
          ] as [String: Any]
        }
      DispatchQueue.main.async {
        result(["permission_status": "authorized", "blocks": blocks])
      }
    }

    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents { granted, _ in finish(granted) }
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in finish(granted) }
    }
  }

  private static func healthPermissionStatus() -> String {
    guard HKHealthStore.isHealthDataAvailable() else { return "unavailable" }
    // HealthKit does not expose a reliable global read authorization status.
    // Treat it as not requested until a read request succeeds.
    return "not_requested"
  }

  private static func requestHealthRecoveryHints(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      DispatchQueue.main.async {
        result(["permission_status": "unavailable", "read_failed": true])
      }
      return
    }
    let types = healthReadTypes()
    healthStore.requestAuthorization(toShare: nil, read: types) { granted, _ in
      guard granted else {
        DispatchQueue.main.async {
          result(["permission_status": "denied", "read_failed": true])
        }
        return
      }
      Task {
        let sleepHours = await averageSleepHours()
        let steps = await averageSteps()
        let workoutMinutes = await totalWorkoutMinutes()
        let sleepScore = min(max(sleepHours / 7.5, 0.0), 1.0)
        let movementScore = min(max(steps / 8000.0, 0.0), 1.0)
        let workoutLoadScore = min(max(workoutMinutes / 180.0, 0.0), 1.0)
        let recoveryScore = (sleepScore * 0.55) + (movementScore * 0.25) + ((1.0 - workoutLoadScore) * 0.20)
        DispatchQueue.main.async {
          result([
            "permission_status": "authorized",
            "sleep_recovery_score": sleepScore,
            "movement_recovery_score": movementScore,
            "workout_load_score": workoutLoadScore,
            "recovery_score": recoveryScore,
            "days_covered": 7
          ])
        }
      }
    }
  }

  private static func healthReadTypes() -> Set<HKObjectType> {
    var types: Set<HKObjectType> = []
    if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      types.insert(sleep)
    }
    if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
      types.insert(steps)
    }
    if let workout = HKObjectType.workoutType() as HKObjectType? {
      types.insert(workout)
    }
    return types
  }

  private static func weekPredicate() -> NSPredicate {
    let end = Date()
    let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
    return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
  }

  private static func averageSteps() async -> Double {
    guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
    return await withCheckedContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: weekPredicate(),
        options: .cumulativeSum
      ) { _, stats, _ in
        let total = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
        continuation.resume(returning: total / 7.0)
      }
      healthStore.execute(query)
    }
  }

  private static func totalWorkoutMinutes() async -> Double {
    await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: .workoutType(),
        predicate: weekPredicate(),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        let minutes = (samples as? [HKWorkout] ?? [])
          .reduce(0.0) { $0 + $1.duration / 60.0 }
        continuation.resume(returning: minutes)
      }
      healthStore.execute(query)
    }
  }

  private static func averageSleepHours() async -> Double {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: weekPredicate(),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        let seconds = (samples as? [HKCategorySample] ?? [])
          .filter { sample in sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
          .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        continuation.resume(returning: seconds / 3600.0 / 7.0)
      }
      healthStore.execute(query)
    }
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
          try await AppStore.sync()
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
