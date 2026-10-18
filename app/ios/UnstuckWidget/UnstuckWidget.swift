import SwiftUI
import WidgetKit

// Home-screen widgets: the task Unstuck would pick right now, in three
// sizes. The app stores its current pick in the shared App Group whenever
// it changes (AppDelegate "updateWidget"); the widget only displays it.

private let appGroup = "group.com.adhdtax.adhdTax"

private let teal = Color(red: 0x5F / 255, green: 0xD8 / 255, blue: 0xBE / 255)
private let ink = Color(red: 0x0D / 255, green: 0x10 / 255, blue: 0x12 / 255)
private let onTeal = Color(red: 0x06 / 255, green: 0x25 / 255, blue: 0x20 / 255)
private let onTealMuted = Color(red: 0x0B / 255, green: 0x40 / 255, blue: 0x38 / 255)

struct NextUp: Hashable {
  let title: String
  let meta: String
  let route: String
}

struct PickEntry: TimelineEntry {
  let date: Date
  let title: String?
  let meta: String
  let step: String
  let empty: String
  let startRoute: String
  let nextUp: [NextUp]

  static let placeholder = PickEntry(
    date: Date(), title: "Your one thing, right now", meta: "Personal · 15 min",
    step: "First: the smallest possible step", empty: "", startRoute: "/",
    nextUp: [
      NextUp(title: "Another one that fits", meta: "5 min", route: "/"),
      NextUp(title: "And one more", meta: "15 min", route: "/"),
    ])

  static func load() -> PickEntry {
    let d = UserDefaults(suiteName: appGroup)?.dictionary(forKey: "widget") as? [String: String] ?? [:]
    let title = d["title"].flatMap { $0.isEmpty ? nil : $0 }
    var next: [NextUp] = []
    for n in 1...2 {
      if let t = d["alt\(n)Title"], !t.isEmpty {
        next.append(NextUp(title: t, meta: d["alt\(n)Meta"] ?? "", route: d["alt\(n)Route"] ?? "/"))
      }
    }
    return PickEntry(
      date: Date(), title: title, meta: d["meta"] ?? "", step: d["step"] ?? "",
      empty: d["empty"] ?? "Open Unstuck and it picks one thing for you.",
      startRoute: d["startRoute"] ?? "/", nextUp: next)
  }
}

/// unstuck://app/focus/<id>?min=N → the app's own route.
private func link(_ route: String) -> URL {
  URL(string: "unstuck://app" + route) ?? URL(string: "unstuck://app/")!
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> PickEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (PickEntry) -> Void) {
    completion(context.isPreview ? .placeholder : PickEntry.load())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PickEntry>) -> Void) {
    // Refreshed by the app whenever the pick changes; no schedule needed.
    completion(Timeline(entries: [PickEntry.load()], policy: .never))
  }
}

struct StartButton: View {
  let route: String
  var compact = false

  var body: some View {
    Link(destination: link(route)) {
      HStack(spacing: 8) {
        Image(systemName: "play.fill").foregroundColor(teal)
        if !compact { Text("Start").fontWeight(.semibold) }
      }
      .font(.system(size: compact ? 15 : 16))
      .foregroundColor(Color(white: 0.95))
      .frame(maxWidth: .infinity, minHeight: 40)
      .background(Capsule().fill(ink))
    }
  }
}

struct AddButton: View {
  var body: some View {
    Link(destination: link("/add")) {
      Image(systemName: "plus")
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(ink)
        .frame(width: 44, height: 40)
        .overlay(Capsule().stroke(ink, lineWidth: 2))
    }
    .accessibilityLabel("Add a task")
  }
}

struct PickView: View {
  @Environment(\.widgetFamily) var family
  let entry: PickEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if family != .systemSmall {
        Text(entry.title == nil ? "Unstuck" : entry.meta)
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(onTealMuted)
          .lineLimit(1)
      }
      Text(entry.title ?? "Nothing picked yet")
        .font(.system(size: family == .systemSmall ? 16 : 19, weight: .bold))
        .foregroundColor(onTeal)
        .lineLimit(family == .systemSmall ? 4 : 2)
      let step = entry.title == nil ? entry.empty : entry.step
      if family != .systemSmall && !step.isEmpty {
        Text(step)
          .font(.system(size: 14))
          .foregroundColor(onTealMuted)
          .lineLimit(2)
      }
      Spacer(minLength: 6)
      if entry.title != nil {
        HStack(spacing: 8) {
          StartButton(route: entry.startRoute, compact: family == .systemSmall)
          if family != .systemSmall { AddButton() }
        }
      } else if family != .systemSmall {
        HStack { Spacer(); AddButton() }
      }
      if family == .systemLarge && entry.title != nil && !entry.nextUp.isEmpty {
        Text("Next up")
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(onTealMuted)
          .padding(.top, 10)
        ForEach(entry.nextUp, id: \.self) { alt in
          Link(destination: link(alt.route)) {
            VStack(alignment: .leading, spacing: 1) {
              Text(alt.title).font(.system(size: 15, weight: .semibold)).foregroundColor(onTeal)
              Text(alt.meta).font(.system(size: 12)).foregroundColor(onTealMuted)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    // The small size can't hold buttons; the whole widget starts the task.
    .widgetURL(link(family == .systemSmall && entry.title != nil ? entry.startRoute : "/"))
    .tealBackground()
  }
}

extension View {
  @ViewBuilder func tealBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(teal, for: .widget)
    } else {
      self.padding().background(teal)
    }
  }
}

struct PickWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PickWidget", provider: Provider()) { entry in
      PickView(entry: entry)
    }
    .configurationDisplayName("Unstuck")
    .description("Your one thing right now, with Start. The large size adds two more that fit.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

@main
struct UnstuckWidgets: WidgetBundle {
  var body: some Widget { PickWidget() }
}
