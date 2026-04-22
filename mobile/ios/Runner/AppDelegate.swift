import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
  private let badgeChannelName = "production_chat_app/badge"
  private let apnsTokenChannelName = "production_chat_app/apns_token"
  private let iosNotificationChannelName = "production_chat_app/notifications_ios"
  private let iosNotificationEventsChannelName = "production_chat_app/notifications_ios_events"

  private var currentApnsToken: String?
  private var pendingApnsTokenResults: [FlutterResult] = []
  private var initialNotificationPayload: String?
  private var notificationEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self

    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      initialNotificationPayload = buildNotificationPayload(
        userInfo: remoteNotification,
        fallbackMessageId: nil
      )
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      configureBadgeChannel(binaryMessenger: controller.binaryMessenger)
      configureApnsTokenChannel(binaryMessenger: controller.binaryMessenger)
      configureIosNotificationMethodChannel(binaryMessenger: controller.binaryMessenger)
      configureIosNotificationEventsChannel(binaryMessenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)

    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    currentApnsToken = token
    resolvePendingApnsTokenResults(with: buildApnsTokenPayload(token: token))
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    resolvePendingApnsTokenResults(with: nil)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let payload = buildNotificationPayload(
      userInfo: notification.request.content.userInfo,
      fallbackMessageId: notification.request.identifier
    )
    emitNotificationEvent(type: "foreground", payload: payload)

    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let payload = buildNotificationPayload(
      userInfo: response.notification.request.content.userInfo,
      fallbackMessageId: response.notification.request.identifier
    )

    if notificationEventSink == nil {
      initialNotificationPayload = payload
    } else {
      emitNotificationEvent(type: "opened", payload: payload)
    }

    completionHandler()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    notificationEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    notificationEventSink = nil
    return nil
  }

  private func configureBadgeChannel(binaryMessenger: FlutterBinaryMessenger) {
    let badgeChannel = FlutterMethodChannel(
      name: badgeChannelName,
      binaryMessenger: binaryMessenger
    )

    badgeChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setBadgeCount" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let count = (call.arguments as? NSNumber)?.intValue ?? 0
      self?.setApplicationBadgeCount(count)
      result(nil)
    }
  }

  private func configureApnsTokenChannel(binaryMessenger: FlutterBinaryMessenger) {
    let apnsTokenChannel = FlutterMethodChannel(
      name: apnsTokenChannelName,
      binaryMessenger: binaryMessenger
    )

    apnsTokenChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "requestDevicePushToken":
        self.requestDevicePushToken(result: result)
      case "getCurrentDevicePushToken":
        if let token = self.currentApnsToken {
          result(self.buildApnsTokenPayload(token: token))
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureIosNotificationMethodChannel(binaryMessenger: FlutterBinaryMessenger) {
    let notificationChannel = FlutterMethodChannel(
      name: iosNotificationChannelName,
      binaryMessenger: binaryMessenger
    )

    notificationChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "getInitialNotificationPayload":
        result(self.initialNotificationPayload)
        self.initialNotificationPayload = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureIosNotificationEventsChannel(binaryMessenger: FlutterBinaryMessenger) {
    let eventsChannel = FlutterEventChannel(
      name: iosNotificationEventsChannelName,
      binaryMessenger: binaryMessenger
    )
    eventsChannel.setStreamHandler(self)
  }

  private func requestDevicePushToken(result: @escaping FlutterResult) {
    var options: UNAuthorizationOptions = [.alert, .badge, .sound]

    if #available(iOS 12.0, *) {
      options.insert(.provisional)
    }

    UNUserNotificationCenter.current().requestAuthorization(options: options) {
      [weak self] granted, error in
      guard let self else {
        result(nil)
        return
      }

      if let error {
        result(
          FlutterError(
            code: "apns_authorization_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      guard granted else {
        result(nil)
        return
      }

      if let token = self.currentApnsToken {
        result(self.buildApnsTokenPayload(token: token))
      } else {
        self.pendingApnsTokenResults.append(result)
      }

      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  private func resolvePendingApnsTokenResults(with payload: [String: Any]?) {
    let pendingResults = pendingApnsTokenResults
    pendingApnsTokenResults.removeAll()

    for result in pendingResults {
      result(payload)
    }
  }

  private func buildApnsTokenPayload(token: String) -> [String: Any] {
    return [
      "provider": "apns",
      "token": token,
      "pushEnvironment": currentPushEnvironment(),
    ]
  }

  private func currentPushEnvironment() -> String {
    #if DEBUG
      return "sandbox"
    #else
      return "production"
    #endif
  }

  private func emitNotificationEvent(type: String, payload: String) {
    guard let notificationEventSink else {
      return
    }

    notificationEventSink([
      "type": type,
      "payload": payload,
    ])
  }

  private func buildNotificationPayload(
    userInfo: [AnyHashable: Any],
    fallbackMessageId: String?
  ) -> String {
    let normalizedUserInfo = normalizeDictionary(userInfo)
    var payload: [String: Any] = [:]

    payload["messageId"] =
      normalizedUserInfo["messageId"] ??
      normalizedUserInfo["message_id"] ??
      fallbackMessageId
    payload["conversationId"] =
      normalizedUserInfo["conversationId"] ??
      normalizedUserInfo["conversation_id"] ??
      normalizedUserInfo["targetConversationId"]
    payload["badgeCount"] =
      normalizedUserInfo["badgeCount"] ??
      normalizedUserInfo["badge_count"] ??
      extractBadgeCount(from: normalizedUserInfo["aps"])
    payload["latestSequence"] =
      normalizedUserInfo["latestSequence"] ??
      normalizedUserInfo["latest_sequence"] ??
      normalizedUserInfo["sequence"]

    let apsAlert = extractAlertDictionary(from: normalizedUserInfo["aps"])
    payload["title"] =
      normalizedUserInfo["title"] ??
      normalizedUserInfo["senderName"] ??
      apsAlert?["title"]
    payload["body"] =
      normalizedUserInfo["body"] ??
      normalizedUserInfo["messagePreview"] ??
      normalizedUserInfo["preview"] ??
      apsAlert?["body"]

    let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [])
    return jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }

  private func extractAlertDictionary(from apsValue: Any?) -> [String: Any]? {
    guard let aps = apsValue as? [String: Any] else {
      return nil
    }

    if let alert = aps["alert"] as? [String: Any] {
      return alert
    }

    if let alert = aps["alert"] as? String {
      return [
        "body": alert
      ]
    }

    return nil
  }

  private func extractBadgeCount(from apsValue: Any?) -> Int? {
    guard let aps = apsValue as? [String: Any] else {
      return nil
    }

    if let badge = aps["badge"] as? NSNumber {
      return badge.intValue
    }

    if let badge = aps["badge"] as? String {
      return Int(badge)
    }

    return nil
  }

  private func normalizeDictionary(_ value: [AnyHashable: Any]) -> [String: Any] {
    var normalized: [String: Any] = [:]

    for (key, value) in value {
      normalized[String(describing: key)] = normalizeJsonValue(value)
    }

    return normalized
  }

  private func normalizeJsonValue(_ value: Any) -> Any {
    if let dictionary = value as? [AnyHashable: Any] {
      return normalizeDictionary(dictionary)
    }

    if let array = value as? [Any] {
      return array.map { normalizeJsonValue($0) }
    }

    if let number = value as? NSNumber {
      return number
    }

    if let string = value as? String {
      return string
    }

    if let boolValue = value as? Bool {
      return boolValue
    }

    return String(describing: value)
  }

  private func setApplicationBadgeCount(_ count: Int) {
    DispatchQueue.main.async {
      UIApplication.shared.applicationIconBadgeNumber = max(count, 0)
    }
  }
}
