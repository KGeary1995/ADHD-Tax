import CryptoKit
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudBridge") {
      ICloudBridge.register(with: registrar)
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

/// The iOS side of "gumption/icloud" (lib/icloud/icloud_store.dart): sync
/// files in a hidden "Sync/<workspace>/" folder of the app's iCloud Drive
/// container. Outside "Documents", so the Files app doesn't show it. Each
/// device writes only its own file, so iCloud never has two versions of a
/// file to reconcile. Ids are "<workspace>/<file name>".
class ICloudBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "gumption/icloud", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ICloudBridge(), channel: channel)
  }

  private enum Failure: Error {
    case unavailable
    case io(String)
  }

  /// File work and finding the container can block, so they run here.
  private let work = DispatchQueue(label: "gumption.icloud", qos: .utility)
  private var root: URL?
  /// Running metadata queries, kept alive until they finish.
  private var queries: [NSMetadataQuery] = []

  /// "<container>/Sync", or nil when iCloud Drive isn't available (signed
  /// out, iCloud Drive off for the app, or no iCloud entitlement).
  private func syncRoot() -> URL? {
    guard FileManager.default.ubiquityIdentityToken != nil else { return nil }
    if let r = root { return r }
    guard let c = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      return nil
    }
    root = c.appendingPathComponent("Sync", isDirectory: true)
    return root
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    work.async {
      do {
        switch call.method {
        case "identity":
          self.reply(result, try self.identity())
        case "list":
          guard let root = self.syncRoot() else { throw Failure.unavailable }
          let ws = args["workspace"] as? String ?? ""
          let prefix = args["prefix"] as? String ?? ""
          // Metadata queries need the main run loop.
          DispatchQueue.main.async {
            self.list(root: root, workspace: ws, prefix: prefix, result: result)
          }
        case "read":
          self.reply(result, try self.read(args))
        case "write":
          self.reply(result, try self.write(args))
        default:
          self.reply(result, FlutterMethodNotImplemented)
        }
      } catch Failure.unavailable {
        self.reply(result, FlutterError(code: "unavailable", message: nil, details: nil))
      } catch Failure.io(let message) {
        self.reply(result, FlutterError(code: "io", message: message, details: nil))
      } catch {
        self.reply(
          result, FlutterError(code: "io", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  /// A short hash of this device's iCloud identity: the same Apple ID gives
  /// the same value, so the app can tell when the account changed. The
  /// Apple ID itself is never exposed to apps.
  private func identity() throws -> String {
    guard let token = FileManager.default.ubiquityIdentityToken, syncRoot() != nil else {
      throw Failure.unavailable
    }
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: token, requiringSecureCoding: false)
    return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
  }

  private func url(for id: String) throws -> URL {
    guard let root = syncRoot() else { throw Failure.unavailable }
    let parts = id.split(separator: "/")
    // Exactly "<workspace>/<name>": never let an id point outside Sync/.
    guard parts.count == 2, !parts.contains(where: { $0 == ".." || $0 == "." }) else {
      throw Failure.io("Bad file id")
    }
    return root.appendingPathComponent(String(parts[0]), isDirectory: true)
      .appendingPathComponent(String(parts[1]))
  }

  private func list(
    root: URL, workspace: String, prefix: String, result: @escaping FlutterResult
  ) {
    let query = NSMetadataQuery()
    // Files outside Documents, including ones not downloaded yet.
    query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
    query.predicate = NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemFSNameKey, prefix)
    var observer: NSObjectProtocol?
    var finished = false
    let finish = { [weak self] in
      guard !finished else { return }
      finished = true
      query.disableUpdates()
      query.stop()
      if let o = observer { NotificationCenter.default.removeObserver(o) }
      self?.queries.removeAll { $0 === query }
      var rows: [[String: String]] = []
      for case let item as NSMetadataItem in query.results {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
        let folder = url.deletingLastPathComponent()
        guard folder.lastPathComponent == workspace,
          folder.deletingLastPathComponent().lastPathComponent == "Sync"
        else { continue }
        let size = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? -1
        let changed =
          (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)?
          .timeIntervalSince1970 ?? 0
        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        if status != NSMetadataUbiquitousItemDownloadingStatusCurrent {
          // Start fetching now; read() waits for it to arrive.
          try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        rows.append([
          "id": "\(workspace)/\(url.lastPathComponent)",
          "name": url.lastPathComponent,
          "checksum": "\(changed)-\(size)",
        ])
      }
      result(rows)
    }
    observer = NotificationCenter.default.addObserver(
      forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
    ) { _ in finish() }
    queries.append(query)
    query.start()
    // Don't hang the sync if iCloud never answers.
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { finish() }
  }

  /// Waits (up to 30 s) for iCloud to bring the latest version down.
  private func waitUntilDownloaded(_ url: URL) {
    for _ in 0..<60 {
      var u = url
      u.removeAllCachedResourceValues()
      let status = (try? u.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
        .ubiquitousItemDownloadingStatus
      if status == .current { return }
      if status == nil && FileManager.default.fileExists(atPath: url.path) { return }
      try? FileManager.default.startDownloadingUbiquitousItem(at: url)
      Thread.sleep(forTimeInterval: 0.5)
    }
  }

  private func read(_ args: [String: Any]) throws -> FlutterStandardTypedData {
    let url = try self.url(for: args["id"] as? String ?? "")
    waitUntilDownloaded(url)
    var data: Data?
    var failure: Error?
    var coordination: NSError?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordination) { u in
      do { data = try Data(contentsOf: u) } catch { failure = error }
    }
    if let e = (coordination as Error?) ?? failure { throw Failure.io(e.localizedDescription) }
    return FlutterStandardTypedData(bytes: data ?? Data())
  }

  private func write(_ args: [String: Any]) throws -> String {
    let id: String
    if let existing = args["id"] as? String {
      id = existing
    } else {
      let ws = args["workspace"] as? String ?? ""
      let name = args["name"] as? String ?? ""
      id = "\(ws)/\(name)"
    }
    let url = try self.url(for: id)
    guard let bytes = (args["bytes"] as? FlutterStandardTypedData)?.data else {
      throw Failure.io("Nothing to write")
    }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var failure: Error?
    var coordination: NSError?
    NSFileCoordinator().coordinate(
      writingItemAt: url, options: .forReplacing, error: &coordination
    ) { u in
      do { try bytes.write(to: u, options: .atomic) } catch { failure = error }
    }
    if let e = (coordination as Error?) ?? failure { throw Failure.io(e.localizedDescription) }
    return id
  }
}
