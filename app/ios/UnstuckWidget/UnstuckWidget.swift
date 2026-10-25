import SwiftUI
import WidgetKit

// Home-screen widgets: the task Gumption would pick right now, in three
// sizes. The app stores its current pick in the shared App Group whenever
// it changes (AppDelegate "updateWidget"); the widget only displays it.
// The look is the 1.1 design's: Night or Dawn, following the phone.

private let appGroup = "group.com.adhdtax.adhdTax"

private func rgb(_ hex: UInt32) -> Color {
  Color(
    red: Double((hex >> 16) & 0xFF) / 255,
    green: Double((hex >> 8) & 0xFF) / 255,
    blue: Double(hex & 0xFF) / 255)
}

/// The app's tokens (core/theme/app_themes.dart) the widgets use.
struct Palette {
  let bgTop, bg, ink, ink2, ink3, line2, star, starDeep, accent, personal, work: Color
  let onStar = rgb(0x1A1406)

  static let night = Palette(
    bgTop: rgb(0x151C33), bg: rgb(0x0A0F1F), ink: rgb(0xEEF0F8), ink2: rgb(0xA3AAC2),
    ink3: rgb(0x717894), line2: rgb(0x323B58), star: rgb(0xF4C76A), starDeep: rgb(0xA8782A),
    accent: rgb(0xF4C76A), personal: rgb(0xF29E7A), work: rgb(0x8DB4FF))
  static let dawn = Palette(
    bgTop: rgb(0xFBE2C6), bg: rgb(0xF7F1E8), ink: rgb(0x19203A), ink2: rgb(0x555C77),
    ink3: rgb(0x878B9E), line2: rgb(0xD6CCBC), star: rgb(0xE8A73C), starDeep: rgb(0x9A6413),
    accent: rgb(0x8F5D0E), personal: rgb(0xD9704A), work: rgb(0x3D6FD1))

  static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? night : dawn }
}

struct NextUp: Hashable {
  let title: String
  let meta: String
  let route: String
}

struct PickEntry: TimelineEntry {
  let date: Date
  let title: String?
  let header: String
  let work: Bool
  let length: String
  let lines: [String]
  let empty: String
  let startRoute: String
  let fiveRoute: String
  let streak: String
  let nextUp: [NextUp]

  static let placeholder = PickEntry(
    date: Date(), title: "List the five calls we get most", header: "Work · Step 2 of 4",
    work: true, length: "30 min",
    lines: ["Open last week's call log", "Tally the ones that repeat"], empty: "",
    startRoute: "/", fiveRoute: "/", streak: "13 days",
    nextUp: [
      NextUp(title: "Another one that fits", meta: "5 min", route: "/"),
      NextUp(title: "And one more", meta: "15 min", route: "/"),
    ])

  static func load() -> PickEntry {
    let d = UserDefaults(suiteName: appGroup)?.dictionary(forKey: "widget") as? [String: String] ?? [:]
    func get(_ key: String) -> String { d[key] ?? "" }
    let title = d["title"].flatMap { $0.isEmpty ? nil : $0 }
    var next: [NextUp] = []
    for n in 1...2 {
      if let t = d["alt\(n)Title"], !t.isEmpty {
        next.append(NextUp(title: t, meta: get("alt\(n)Meta"), route: d["alt\(n)Route"] ?? "/"))
      }
    }
    // Data saved by a build before 1.1 has only meta and step.
    var first = get("line1")
    if first.isEmpty && get("step").hasPrefix("First: ") {
      first = String(get("step").dropFirst("First: ".count))
    }
    let lines = [first, get("line2")].filter { !$0.isEmpty }
    return PickEntry(
      date: Date(), title: title, header: get("header").isEmpty ? get("meta") : get("header"),
      work: get("work") == "1", length: get("length"), lines: lines,
      empty: d["empty"] ?? "Open Gumption and it picks one thing for you.",
      startRoute: d["startRoute"] ?? "/", fiveRoute: get("fiveRoute"), streak: get("streak"),
      nextUp: next)
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

/// The primary button: star fill on a 4pt starDeep "pressed edge".
struct StartLabel: View {
  let p: Palette
  var text = "Start"
  var glyph = true

  var body: some View {
    HStack(spacing: 6) {
      if glyph { Text("✦") }
      Text(text)
    }
    .font(.system(size: 16, weight: .bold))
    .foregroundColor(p.onStar)
    .frame(maxWidth: .infinity, minHeight: 40)
    .background(RoundedRectangle(cornerRadius: 14).fill(p.star))
    .padding(.bottom, 4)
    .background(RoundedRectangle(cornerRadius: 14).fill(p.starDeep))
  }
}

struct OutlineLabel: View {
  let p: Palette
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 15, weight: .bold))
      .foregroundColor(p.ink)
      .frame(width: 70, height: 44)
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.ink, lineWidth: 2))
  }
}

/// One checklist line with its empty box.
struct StepLine: View {
  let p: Palette
  let text: String
  var lines = 1

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      RoundedRectangle(cornerRadius: 3)
        .stroke(p.ink3, lineWidth: 1.5)
        .frame(width: 12, height: 12)
      Text(text)
        .font(.system(size: 13))
        .foregroundColor(p.ink2)
        .lineLimit(lines)
    }
  }
}

struct PickView: View {
  @Environment(\.widgetFamily) var family
  @Environment(\.colorScheme) var scheme
  let entry: PickEntry

  var body: some View {
    let p = Palette.of(scheme)
    Group {
      switch family {
      case .systemSmall: small(p)
      case .systemLarge: large(p)
      default: medium(p)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    // The small size can't hold separate buttons; the whole widget starts
    // the task.
    .widgetURL(link(family == .systemSmall && entry.title != nil ? entry.startRoute : "/"))
    .skyBackground(p)
  }

  private func title(_ p: Palette, size: CGFloat) -> some View {
    Text(entry.title ?? "Nothing picked yet")
      .font(.system(size: size, weight: .semibold))
      .foregroundColor(p.ink)
      .lineLimit(2)
  }

  private func header(_ p: Palette) -> some View {
    HStack(spacing: 7) {
      RoundedRectangle(cornerRadius: 2)
        .fill(entry.work ? p.work : p.personal)
        .frame(width: 8, height: 8)
      Text(entry.title == nil ? "Gumption" : entry.header)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(p.ink2)
        .lineLimit(1)
    }
  }

  private func steps(_ p: Palette, count: Int, lines: Int = 1) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      if entry.title == nil {
        Text(entry.empty).font(.system(size: 13)).foregroundColor(p.ink2).lineLimit(3)
      } else {
        ForEach(Array(entry.lines.prefix(count)), id: \.self) { StepLine(p: p, text: $0, lines: lines) }
      }
    }
  }

  private func buttons(_ p: Palette) -> some View {
    HStack(spacing: 8) {
      Link(destination: link(entry.startRoute)) { StartLabel(p: p, glyph: false) }
      if !entry.fiveRoute.isEmpty {
        Link(destination: link(entry.fiveRoute)) { OutlineLabel(p: p, text: "5 min") }
      }
    }
  }

  // Star, length, the task, the step you're on, Start.
  private func small(_ p: Palette) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Circle().fill(p.star).frame(width: 10, height: 10)
        Spacer()
        Text(entry.length).font(.system(size: 13, weight: .bold)).foregroundColor(p.ink2)
      }
      title(p, size: 16)
      steps(p, count: 1, lines: 2)
      Spacer(minLength: 4)
      if entry.title != nil { StartLabel(p: p) }
    }
  }

  // Workspace · step, the task, two steps, Start + 5 min; Add a task and
  // the streak in a divided right column.
  private func medium(_ p: Palette) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        header(p)
        title(p, size: 15)
        steps(p, count: 2)
        Spacer(minLength: 4)
        if entry.title != nil { buttons(p) }
      }
      Rectangle().fill(p.line2).frame(width: 2)
      VStack(spacing: 8) {
        Link(destination: link("/add")) {
          VStack(spacing: 4) {
            Text("+").font(.system(size: 26)).foregroundColor(p.accent)
            Text("Add a task").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line2, lineWidth: 2))
        }
        .accessibilityLabel("Add a task")
        if !entry.streak.isEmpty {
          Text("✦ \(entry.streak)").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink2)
        }
      }
      .frame(width: 88)
    }
  }

  // The medium card's left side, then two more that fit right now.
  private func large(_ p: Palette) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      header(p)
      title(p, size: 18)
      steps(p, count: 2)
      if entry.title != nil {
        HStack(spacing: 8) {
          buttons(p)
          Link(destination: link("/add")) { OutlineLabel(p: p, text: "+") }
            .accessibilityLabel("Add a task")
        }
        .padding(.top, 6)
      }
      if entry.title != nil && !entry.nextUp.isEmpty {
        Text("NEXT UP")
          .font(.system(size: 11, weight: .bold))
          .kerning(0.9)
          .foregroundColor(p.ink3)
          .padding(.top, 10)
        ForEach(entry.nextUp, id: \.self) { alt in
          Link(destination: link(alt.route)) {
            VStack(alignment: .leading, spacing: 1) {
              Text(alt.title).font(.system(size: 15, weight: .semibold)).foregroundColor(p.ink)
              Text(alt.meta).font(.system(size: 12)).foregroundColor(p.ink3)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
          }
        }
      }
      Spacer(minLength: 0)
    }
  }
}

extension View {
  @ViewBuilder func skyBackground(_ p: Palette) -> some View {
    let sky = LinearGradient(colors: [p.bgTop, p.bg], startPoint: .top, endPoint: .bottom)
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) { sky }
    } else {
      self.padding().background(sky)
    }
  }
}

struct PickWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PickWidget", provider: Provider()) { entry in
      PickView(entry: entry)
    }
    .configurationDisplayName("Gumption")
    .description("Your one thing right now, with Start. The large size adds two more that fit.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

@main
struct UnstuckWidgets: WidgetBundle {
  var body: some Widget { PickWidget() }
}
