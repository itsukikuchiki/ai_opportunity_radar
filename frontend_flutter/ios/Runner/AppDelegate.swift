import Flutter
import AVFoundation
import EventKit
import HealthKit
import Speech
import StoreKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      controller.view.backgroundColor = UIColor(
        red: 1,
        green: 0.9882352941,
        blue: 0.9568627451,
        alpha: 1
      )
      NativeStoreKitBridge.register(with: controller.binaryMessenger)
      SpeechRecognitionBridge.register(with: controller.binaryMessenger)
      ExternalEnergyBridge.register(with: controller.binaryMessenger)
      LocalNotificationBridge.register(with: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class LocalNotificationBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "signalpath/local_notifications",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "scheduleReminder":
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String,
              let title = args["title"] as? String,
              let body = args["body"] as? String,
              let scheduledAt = args["scheduledAt"] as? String else {
          result(FlutterError(code: "bad_args", message: "Missing reminder fields.", details: nil))
          return
        }
        scheduleReminder(id: id, title: title, body: body, scheduledAt: scheduledAt, result: result)
      case "cancelReminder":
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String else {
          result(FlutterError(code: "bad_args", message: "Missing reminder id.", details: nil))
          return
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
          withIdentifiers: [notificationIdentifier(id)]
        )
        result(nil)
      case "cancelAllScheduleReminders":
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
          let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix("signalpath.schedule.") }
          center.removePendingNotificationRequests(withIdentifiers: identifiers)
          DispatchQueue.main.async {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func scheduleReminder(
    id: String,
    title: String,
    body: String,
    scheduledAt: String,
    result: @escaping FlutterResult
  ) {
    guard let fireDate = ISO8601DateFormatter().date(from: scheduledAt) else {
      result(FlutterError(code: "bad_date", message: "Invalid scheduledAt.", details: nil))
      return
    }

    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_failed", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_denied", message: "Notification permission was denied.", details: nil))
        }
        return
      }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default

      let triggerDate = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: fireDate
      )
      let request = UNNotificationRequest(
        identifier: notificationIdentifier(id),
        content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
      )

      center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(id)])
      center.add(request) { addError in
        DispatchQueue.main.async {
          if let addError = addError {
            result(FlutterError(code: "schedule_failed", message: addError.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    }
  }

  private static func notificationIdentifier(_ id: String) -> String {
    return "signalpath.schedule.\(id)"
  }
}

private final class SpeechRecognitionBridge {
  private static let audioEngine = AVAudioEngine()
  private static var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private static var recognitionTask: SFSpeechRecognitionTask?
  private static var latestTranscript = ""
  private static var pendingStopResult: FlutterResult?
  private static var stopCompleted = false

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "signalpath/speech",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "startVoiceRecognition":
        let arguments = call.arguments as? [String: Any]
        let localeIdentifier = arguments?["localeIdentifier"] as? String
        start(localeIdentifier: localeIdentifier, result: result)
      case "stopVoiceRecognition":
        stop(result: result)
      case "cancelVoiceRecognition":
        cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func start(localeIdentifier: String?, result: @escaping FlutterResult) {
    latestTranscript = ""
    pendingStopResult = nil
    stopCompleted = false
    requestPermissions { granted in
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "speech_permission_denied",
            message: "Speech recognition or microphone permission was denied.",
            details: nil
          ))
        }
        return
      }

      DispatchQueue.main.async {
        do {
          try startRecognitionSession(localeIdentifier: localeIdentifier)
          result(nil)
        } catch {
          result(FlutterError(
            code: "speech_start_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private static func stop(result: @escaping FlutterResult) {
    let transcriptAtStop = latestTranscript
    DispatchQueue.main.async {
      pendingStopResult = result
      stopCompleted = false
      finishAudioInput()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
        completeStopIfNeeded(fallbackTranscript: transcriptAtStop)
      }
    }
  }

  private static func cancel() {
    stopAudio()
    latestTranscript = ""
  }

  private static func requestPermissions(completion: @escaping (Bool) -> Void) {
    SFSpeechRecognizer.requestAuthorization { speechStatus in
      guard speechStatus == .authorized else {
        completion(false)
        return
      }
      AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
        completion(micGranted)
      }
    }
  }

  private static func startRecognitionSession(localeIdentifier: String?) throws {
    stopAudio()

    let preferredLocale = Locale(identifier: sanitizedLocaleIdentifier(localeIdentifier))
    let currentLocale = Locale.current
    let englishFallbackLocale = Locale(identifier: "en-US")
    let recognizers = [
      SFSpeechRecognizer(locale: preferredLocale),
      SFSpeechRecognizer(locale: currentLocale),
      SFSpeechRecognizer(locale: englishFallbackLocale)
    ].compactMap { $0 }
    guard let recognizer = recognizers.first(where: {
      $0.isAvailable && $0.supportsOnDeviceRecognition
    }) else {
      throw NSError(
        domain: "signalpath.speech",
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey:
            "On-device speech recognition is unavailable for this language."
        ]
      )
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    // Privacy contract: never fall back to Apple's network recognizer.
    request.requiresOnDeviceRecognition = true
    recognitionRequest = request

    recognitionTask = recognizer.recognitionTask(with: request) { result, error in
      if let result = result {
        Self.latestTranscript = result.bestTranscription.formattedString
      }
      if error != nil || result?.isFinal == true {
        let transcript = Self.latestTranscript
        Self.finishAudioInput()
        if Self.pendingStopResult != nil {
          Self.completeStopIfNeeded(fallbackTranscript: transcript)
        } else {
          Self.cancelRecognitionTask()
        }
      }
    }

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      Self.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()
  }

  private static func sanitizedLocaleIdentifier(_ identifier: String?) -> String {
    let trimmed = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty {
      return Locale.current.identifier
    }
    return trimmed
  }

  private static func finishAudioInput() {
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionRequest = nil
  }

  private static func completeStopIfNeeded(fallbackTranscript: String) {
    guard !stopCompleted else { return }
    stopCompleted = true
    let transcript = latestTranscript.isEmpty ? fallbackTranscript : latestTranscript
    let result = pendingStopResult
    pendingStopResult = nil
    cancelRecognitionTask()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    result?(transcript)
  }

  private static func cancelRecognitionTask() {
    recognitionTask?.cancel()
    recognitionTask = nil
  }

  private static func stopAudio() {
    finishAudioInput()
    pendingStopResult = nil
    stopCompleted = false
    cancelRecognitionTask()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
        calendarScheduleHintsIfAuthorized(result: result)
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

  private static func calendarScheduleHintsIfAuthorized(
    result: @escaping FlutterResult
  ) {
    // Calendar is a future Target in this release. Keep the privacy-safe read
    // implementation for an already-authorized device, but never present an
    // EventKit permission sheet from the current runtime.
    let status = calendarPermissionStatus()
    guard status == "authorized" else {
      result(["permission_status": status, "blocks": []])
      return
    }
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let end = calendar.date(byAdding: .day, value: 7, to: start) ?? Date()
    let predicate = eventStore.predicateForEvents(
      withStart: start,
      end: end,
      calendars: nil
    )
    let blocks = eventStore.events(matching: predicate)
      .filter { !$0.isAllDay }
      .map { event in
        [
          "start_at": ISO8601DateFormatter().string(from: event.startDate),
          "end_at": ISO8601DateFormatter().string(from: event.endDate),
          "is_busy": event.availability != .free
        ] as [String: Any]
      }
    result([
      "permission_status": "authorized",
      "blocks": blocks
    ])
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
    healthStore.requestAuthorization(toShare: nil, read: types) { requestCompleted, error in
      // HealthKit deliberately does not reveal whether each read type was
      // granted. This Boolean only means the authorization request completed,
      // so never translate a false value into a user-level "denied" claim.
      guard requestCompleted, error == nil else {
        DispatchQueue.main.async {
          result([
            "permission_status": "unavailable",
            "read_failed": true
          ])
        }
        return
      }
      Task {
        let sleepHours = await averageSleepHours()
        let steps = await averageSteps()
        let workoutMinutes = await totalWorkoutMinutes()
        let sleepScore = sleepHours.map { min(max($0 / 7.5, 0.0), 1.0) }
        let movementScore = steps.map { min(max($0 / 8000.0, 0.0), 1.0) }
        let workoutLoadScore = workoutMinutes.map { min(max($0 / 180.0, 0.0), 1.0) }

        var recoveryComponents: [(score: Double, weight: Double)] = []
        if let sleepScore {
          recoveryComponents.append((sleepScore, 0.55))
        }
        if let movementScore {
          recoveryComponents.append((movementScore, 0.25))
        }
        if let workoutLoadScore {
          recoveryComponents.append((1.0 - workoutLoadScore, 0.20))
        }
        let totalWeight = recoveryComponents.reduce(0.0) { $0 + $1.weight }
        let recoveryScore = totalWeight > 0
          ? recoveryComponents.reduce(0.0) { $0 + ($1.score * $1.weight) } / totalWeight
          : nil

        var payload: [String: Any] = [
          // "authorized" here means the request flow and local read queries
          // completed. Apple does not expose per-type read authorization.
          "permission_status": "authorized",
          "days_covered": 7
        ]
        if let sleepScore {
          payload["sleep_recovery_score"] = sleepScore
        }
        if let movementScore {
          payload["movement_recovery_score"] = movementScore
        }
        if let workoutLoadScore {
          payload["workout_load_score"] = workoutLoadScore
        }
        if let recoveryScore {
          payload["recovery_score"] = recoveryScore
        }
        if recoveryComponents.isEmpty {
          payload["no_data"] = true
        }
        DispatchQueue.main.async {
          result(payload)
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

  private static func averageSteps() async -> Double? {
    guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return nil }
    return await withCheckedContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: weekPredicate(),
        options: .cumulativeSum
      ) { _, stats, error in
        guard error == nil, let sum = stats?.sumQuantity() else {
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(returning: sum.doubleValue(for: .count()) / 7.0)
      }
      healthStore.execute(query)
    }
  }

  private static func totalWorkoutMinutes() async -> Double? {
    await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: .workoutType(),
        predicate: weekPredicate(),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, error in
        guard error == nil,
              let workouts = samples as? [HKWorkout],
              !workouts.isEmpty else {
          continuation.resume(returning: nil)
          return
        }
        let minutes = workouts
          .reduce(0.0) { $0 + $1.duration / 60.0 }
        continuation.resume(returning: minutes)
      }
      healthStore.execute(query)
    }
  }

  private static func averageSleepHours() async -> Double? {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: weekPredicate(),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, error in
        guard error == nil, let sleepSamples = samples as? [HKCategorySample] else {
          continuation.resume(returning: nil)
          return
        }
        let asleepSamples = sleepSamples
          .filter { sample in sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
        guard !asleepSamples.isEmpty else {
          continuation.resume(returning: nil)
          return
        }
        let seconds = asleepSamples
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
            let appReceipt = await appStoreReceiptDataRefreshingIfNeeded()
            result(transactionMap(
              transaction,
              verification: verification,
              appReceipt: appReceipt
            ))
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
      let args = call.arguments as? [String: Any]
      let requestedProductIDs = Set(args?["ids"] as? [String] ?? [])
      let syncIfEmpty = args?["syncIfEmpty"] as? Bool ?? true
      Task {
        storeKitLog("restore start requested=\(requestedProductIDs.sorted().joined(separator: ","))")
        var snapshot = await currentEntitlementSnapshot(for: requestedProductIDs)
        storeKitLog(
          "currentEntitlements before sync count=\(snapshot.transactions.count) " +
          "products=\(productIds(snapshot.transactions)) " +
          "unverified=\(snapshot.unverifiedProductIds.joined(separator: ","))"
        )

        var syncError: String?
        if snapshot.transactions.isEmpty && syncIfEmpty {
          do {
            try await AppStore.sync()
            storeKitLog("AppStore.sync success after empty entitlement")
          } catch {
            syncError = describe(error)
            storeKitLog("AppStore.sync failed after empty entitlement error=\(syncError!)")
          }
          snapshot = await currentEntitlementSnapshot(for: requestedProductIDs)
          storeKitLog(
            "currentEntitlements after sync count=\(snapshot.transactions.count) " +
            "products=\(productIds(snapshot.transactions)) " +
            "unverified=\(snapshot.unverifiedProductIds.joined(separator: ","))"
          )
        }

        let environment = restoreEnvironment(snapshot.transactions)
        storeKitLog(
          "restore result count=\(snapshot.transactions.count) " +
          "products=\(productIds(snapshot.transactions)) environment=\(environment) " +
          "syncError=\(syncError ?? "none")"
        )
        result([
          "transactions": snapshot.transactions,
          "environment": environment,
          "syncError": syncError ?? "",
          "unverifiedProductIds": snapshot.unverifiedProductIds
        ])
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
    verification: VerificationResult<Transaction>,
    appReceipt: String?
  ) -> [String: Any] {
    var value: [String: Any] = [
      "productId": transaction.productID,
      "transactionId": String(transaction.id),
      "originalTransactionId": String(transaction.originalID),
      "purchaseDate": ISO8601DateFormatter().string(from: transaction.purchaseDate),
      // The backend verifyReceipt endpoint accepts an App Receipt, not a
      // StoreKit 2 transaction JWS. Keep the JWS in its own field for a future
      // App Store Server API verifier, but never disguise it as a receipt.
      "verificationData": appReceipt ?? "",
      "verificationSource": appReceipt == nil ? "storekit2_local_verified" : "app_store_receipt",
      "jwsRepresentation": verification.jwsRepresentation,
      "backendVerificationEligible": appReceipt != nil,
      "environment": transaction.environmentStringRepresentation
    ]
    if let expirationDate = transaction.expirationDate {
      value["expirationDate"] = ISO8601DateFormatter().string(from: expirationDate)
    }
    return value
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

  private struct EntitlementSnapshot {
    let transactions: [[String: Any]]
    let unverifiedProductIds: [String]
  }

  @available(iOS 15.0, *)
  private static func currentEntitlementSnapshot(
    for requestedProductIDs: Set<String>
  ) async -> EntitlementSnapshot {
    var transactions: [[String: Any]] = []
    var unverifiedProductIds: [String] = []
    var appReceipt = appStoreReceiptData()
    var attemptedReceiptRefresh = false
    for await verification in Transaction.currentEntitlements {
      switch verification {
      case .verified(let transaction):
        if requestedProductIDs.isEmpty || requestedProductIDs.contains(transaction.productID) {
          if appReceipt == nil && !attemptedReceiptRefresh {
            attemptedReceiptRefresh = true
            appReceipt = await appStoreReceiptDataRefreshingIfNeeded()
          }
          transactions.append(transactionMap(
            transaction,
            verification: verification,
            appReceipt: appReceipt
          ))
        }
      case .unverified(let transaction, let error):
        guard requestedProductIDs.isEmpty || requestedProductIDs.contains(transaction.productID) else {
          continue
        }
        unverifiedProductIds.append(transaction.productID)
        storeKitLog(
          "ignored unverified entitlement product=\(transaction.productID) error=\(describe(error))"
        )
      }
    }
    return EntitlementSnapshot(
      transactions: transactions,
      unverifiedProductIds: unverifiedProductIds
    )
  }

  private static func appStoreReceiptData() -> String? {
    guard let url = Bundle.main.appStoreReceiptURL,
          let data = try? Data(contentsOf: url),
          !data.isEmpty else {
      return nil
    }
    return data.base64EncodedString()
  }

  private static func appStoreReceiptDataRefreshingIfNeeded() async -> String? {
    if let receipt = appStoreReceiptData() {
      return receipt
    }

    do {
      try await AppReceiptRefreshOperation.refresh()
    } catch {
      storeKitLog("App Receipt refresh failed; keeping local StoreKit entitlement error=\(describe(error))")
      return nil
    }

    guard let receipt = appStoreReceiptData() else {
      storeKitLog("App Receipt refresh completed without receipt data; keeping local StoreKit entitlement")
      return nil
    }
    storeKitLog("App Receipt refresh succeeded")
    return receipt
  }

  private static func restoreEnvironment(_ transactions: [[String: Any]]) -> String {
    if let transactionEnvironment = transactions
      .compactMap({ $0["environment"] as? String })
      .first(where: { !$0.isEmpty }) {
      return transactionEnvironment
    }

    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
      return "Unknown"
    }
    let fileName = receiptURL.lastPathComponent.lowercased()
    if fileName.contains("sandbox") {
      return "Sandbox"
    }
    return "Production"
  }

  private static func storeKitLog(_ message: String) {
    NSLog("[SignalPath][StoreKit] %@", message)
  }

  private static func describe(_ error: Error) -> String {
    let nsError = error as NSError
    return "\(nsError.domain)#\(nsError.code): \(nsError.localizedDescription)"
  }

  private static func productIds(_ items: [[String: Any]]) -> String {
    let ids = items.compactMap { $0["productId"] as? String }
    return ids.isEmpty ? "none" : ids.joined(separator: ",")
  }
}

private final class AppReceiptRefreshOperation: NSObject, SKRequestDelegate {
  private static let operationsLock = NSLock()
  private static var activeOperations: [UUID: AppReceiptRefreshOperation] = [:]

  private let id = UUID()
  private let completionLock = NSLock()
  private var continuation: CheckedContinuation<Void, Error>?
  private var request: SKReceiptRefreshRequest?

  private init(continuation: CheckedContinuation<Void, Error>) {
    self.continuation = continuation
  }

  static func refresh() async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      let operation = AppReceiptRefreshOperation(continuation: continuation)
      retain(operation)
      DispatchQueue.main.async {
        operation.start()
      }
    }
  }

  private static func retain(_ operation: AppReceiptRefreshOperation) {
    operationsLock.lock()
    activeOperations[operation.id] = operation
    operationsLock.unlock()
  }

  private static func release(_ operation: AppReceiptRefreshOperation) {
    operationsLock.lock()
    activeOperations.removeValue(forKey: operation.id)
    operationsLock.unlock()
  }

  private func start() {
    let request = SKReceiptRefreshRequest()
    self.request = request
    request.delegate = self
    request.start()

    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
      self?.finish(error: NSError(
        domain: "signalpath.storekit.receipt",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "App Receipt refresh timed out."]
      ))
    }
  }

  func requestDidFinish(_ request: SKRequest) {
    finish(error: nil)
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    finish(error: error)
  }

  private func finish(error: Error?) {
    completionLock.lock()
    guard let continuation = continuation else {
      completionLock.unlock()
      return
    }
    self.continuation = nil
    let request = self.request
    self.request = nil
    completionLock.unlock()

    request?.cancel()
    Self.release(self)
    if let error = error {
      continuation.resume(throwing: error)
    } else {
      continuation.resume()
    }
  }
}
