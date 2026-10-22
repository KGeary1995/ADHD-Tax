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

  private func queue(title: String, link: String) {
    let defaults = UserDefaults(suiteName: appGroup)
    var pending = defaults?.array(forKey: "pendingShares") as? [[String: String]] ?? []
    // Same shape as Android: the subject becomes the title, text the notes.
    pending.append(["subject": title.trimmingCharacters(in: .whitespacesAndNewlines), "text": link])
    defaults?.set(pending, forKey: "pendingShares")
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  override func configurationItems() -> [Any]! { [] }
}
