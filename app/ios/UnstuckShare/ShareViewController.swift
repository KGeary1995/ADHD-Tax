import Social
import UIKit
import UniformTypeIdentifiers

/// "Share → Gumption": Apple's standard compose sheet. Post queues the text
/// (and any link) in the App Group; the app opens Quick add with it the next
/// time it comes to the front. Extensions can't open their app directly.
class ShareViewController: SLComposeServiceViewController {
  private let appGroup = "group.com.adhdtax.adhdTax"

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Gumption"
    placeholder = "What needs doing?"
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Add"
  }

  override func isContentValid() -> Bool {
    !(contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  override func didSelectPost() {
    let text = contentText ?? ""
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    guard let url = providers.first(where: {
      $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
    }) else {
      queue(title: text, link: "")
      return
    }
    url.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
      let link = (item as? URL)?.absoluteString ?? ""
      DispatchQueue.main.async {
        // The compose text is often the page title, which makes a good task.
        self.queue(title: text, link: link == text ? "" : link)
      }
    }
  }

  /// One file per share in the App Group's "Shares" folder, named so they
  /// sort oldest first (UnstuckBridge.takeShare in the app). Written under
  /// a temporary name and then renamed, so the app never reads half a file.
  private func queue(title: String, link: String) {
    // Same shape as Android: the subject becomes the title, text the notes.
    let share = ["subject": title.trimmingCharacters(in: .whitespacesAndNewlines), "text": link]
    if let folder = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent("Shares", isDirectory: true),
      let data = try? JSONSerialization.data(withJSONObject: share)
    {
      let name = "\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
      let temp = folder.appendingPathComponent(name + ".tmp")
      do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: temp)
        try FileManager.default.moveItem(
          at: temp, to: folder.appendingPathComponent(name + ".json"))
      } catch {
        try? FileManager.default.removeItem(at: temp)
      }
    }
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  override func configurationItems() -> [Any]! { [] }
}
