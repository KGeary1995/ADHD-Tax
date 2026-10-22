import Flutter
import UIKit
import UserNotifications
import WidgetKit

/// Shared with the widget and share extensions (App Group).
let appGroup = "group.com.adhdtax.adhdTax"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets reminders show as banners while Gumption is open, too.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UnstuckBridge") {
      UnstuckBridge.register(with: registrar)
    }
  }
}

/// The iOS side of the "unstuck/android" channel (the name predates iOS):
/// hands Dart text queued by the share extension, and stores the current
/// pick for the home-screen widget. Widget taps arrive as unstuck:// links,
/// which Flutter routes directly.
class UnstuckBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "unstuck/android", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(UnstuckBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let defaults = UserDefaults(suiteName: appGroup)
    switch call.method {
    case "takeLaunchRequest":
      // One shared item at a time; the rest wait for the next resume.
      var queue = defaults?.array(forKey: "pendingShares") as? [[String: String]] ?? []
      if queue.isEmpty {
        result(nil)
        return
      }
      let next = queue.removeFirst()
      defaults?.set(queue, forKey: "pendingShares")
      result([
        "type": "share",
        "text": next["text"] ?? "",
        "subject": next["subject"] ?? "",
      ])
    case "updateWidget":
      let data = call.arguments as? [String: String] ?? [:]
      defaults?.set(data, forKey: "widget")
      WidgetCenter.shared.reloadAllTimelines()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
