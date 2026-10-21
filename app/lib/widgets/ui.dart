import 'package:flutter/material.dart';

import '../core/theme/app_themes.dart';

/// A card: the surface color, a hairline edge in dark mode, big radius.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: color == null && s.isDark
          ? BorderSide(color: s.border)
          : BorderSide.none,
    );
    return Material(
      color: color ?? s.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Big screen title (Tasks, Progress, Settings) with an optional mono
/// subtitle and a trailing action.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: s.display(38)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: s.mono(13)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// "Up next 5": a list heading with a quiet count.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (count != null)
              TextSpan(
                text: '  $count',
                style: TextStyle(color: s.faint, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: s.onSurface,
        ),
      ),
    );
  }
}

/// Label above a form group ("How long?") or a settings group.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.inset = 0});
  final String text;
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.spec.isDark ? context.spec.text2 : context.spec.muted,
      ),
    ),
  );
}

/// Settings-style group: a labelled card of rows with hairlines between.
class Group extends StatelessWidget {
  const Group({super.key, this.label, required this.children});
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: s.muted,
              ),
            ),
          ),
        Panel(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(
            children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 16, endIndent: 16),
                c,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in a [Group]: title, optional subtitle, trailing control.
class GroupRow extends StatelessWidget {
  const GroupRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleMono = false,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool subtitleMono;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: s.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: subtitleMono
                            ? s.mono(13)
                            : TextStyle(fontSize: 13, color: s.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A [GroupRow] with a switch. The whole row toggles.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleMono = false,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool subtitleMono;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GroupRow(
      title: title,
      subtitle: subtitle,
      subtitleMono: subtitleMono,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// Pill-shaped segmented control (Light / Dark / Match phone).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.inset = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  /// Sits on a surface (a sheet), so the track uses the page color.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: inset ? s.background : s.surface,
        shape: StadiumBorder(
          side: s.isDark ? BorderSide(color: s.navBorder) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                selected: v == selected,
                inMutuallyExclusiveGroup: true,
                button: true,
                child: Material(
                  color: v == selected ? s.selected : Colors.transparent,
                  shape: const StadiumBorder(),
                  elevation: v == selected && !s.isDark ? 1 : 0,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelected(v),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: Text(
                            labelOf(v),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: v == selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: v == selected ? s.onSurface : s.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A round pill: outlined when off, teal when on. [solid] uses the text
/// color instead of teal when on (filter tabs).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.mono = false,
    this.solid = false,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;
  final bool solid;
  final IconData? icon;

  /// Keeps the icon's own color (e.g. a project's dot) instead of the
  /// text color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final bg = !selected
        ? Colors.transparent
        : solid
        ? s.onSurface
        : s.accent;
    final fg = !selected
        ? s.text2
        : solid
        ? s.background
        : s.onAccent;
    final style = TextStyle(
      fontFamily: mono ? Fonts.mono : Fonts.ui,
      fontSize: 14,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: fg,
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: s.outline),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: iconColor == null ? 17 : 12,
                      color: iconColor ?? fg,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(child: Text(label, style: style)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick exactly one of a few options. Pills wrap onto the next line on a
/// narrow phone instead of squeezing their labels.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.mono = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final bool mono;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final v in values)
        Pill(
          label: labelOf(v),
          selected: v == selected,
          mono: mono,
          onTap: () => onSelected(v),
        ),
    ],
  );
}

/// The Unstuck mark: a tangle pulled straight into an arrow.
class UnstuckMark extends StatelessWidget {
  const UnstuckMark({super.key, this.size = 22, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MarkPainter(color ?? context.spec.primary),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24×24 grid, same as the SVG in the design.
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final tangle = Path()
      ..moveTo(3, 16)
      ..cubicTo(5, 16, 6, 15, 6, 13)
      ..cubicTo(6, 11, 4.5, 8, 2.5, 8)
      ..cubicTo(0.5, 8, 1, 10, 3, 13)
      ..cubicTo(5, 16, 8, 16, 10, 15)
      ..lineTo(19, 8);
    final head = Path()
      ..moveTo(14, 7.5)
      ..lineTo(19.5, 7.5)
      ..lineTo(19.5, 13);
    canvas
      ..drawPath(tangle, paint)
      ..drawPath(head, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// Logo mark plus the word "Unstuck".
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const UnstuckMark(),
      const SizedBox(width: 9),
      Text(
        'Unstuck',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.spec.onSurface,
        ),
      ),
    ],
  );
}

/// Centers content with a max width so desktop layouts stay readable.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Bottom padding that keeps the last item clear of the floating nav
/// (the shell's Scaffold adds the nav's height to MediaQuery.padding).
double navClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 24;

/// At this width and up the nav is a side rail instead of a bottom pill.
const wideBreakpoint = 760.0;

/// Swipe a row left to delete it, and (when [onDone] is given) right to
/// mark it done. The callers show an Undo bar, so a mis-swipe costs nothing.
class SwipeActions extends StatelessWidget {
  const SwipeActions({
    required super.key,
    required this.child,
    required this.onDelete,
    this.onDone,
  });

  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    Widget bg(Color color, Color fg, IconData icon, String label, bool left) =>
        Container(
          color: color,
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
    return Dismissible(
      key: key!,
      direction: onDone == null
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      background: onDone == null
          ? const SizedBox.shrink()
          : bg(s.accent, s.onAccent, Icons.check_rounded, 'Done', true),
      secondaryBackground: bg(
        s.danger,
        Colors.white,
        Icons.delete_outline_rounded,
        'Delete',
        false,
      ),
      onDismissed: (d) =>
          d == DismissDirection.startToEnd ? onDone?.call() : onDelete(),
      child: child,
    );
  }
}

/// Below this content width, screens with a sidebar fall back to their
/// phone layout (filters inline above the list).
const sidebarBreakpoint = 980.0;

/// Desktop layout for list screens: a filter sidebar on the left and the
/// main column on the right, together centered and capped at [maxWidth].
/// Narrower, only the main column shows, capped at [narrowMaxWidth].
/// [builder] gets `wide` so it can leave out its inline filters.
class SidebarLayout extends StatelessWidget {
  const SidebarLayout({
    super.key,
    required this.sidebar,
    required this.builder,
    this.maxWidth = 1240,
    this.narrowMaxWidth = 640,
  });

  final Widget sidebar;
  final Widget Function(BuildContext context, bool wide) builder;
  final double maxWidth;
  final double narrowMaxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < sidebarBreakpoint) {
        return ContentWidth(
          maxWidth: narrowMaxWidth,
          child: builder(context, false),
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 248,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 40, 4, 24),
                  children: [sidebar],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: builder(context, true)),
            ],
          ),
        ),
      );
    },
  );
}

/// A labelled group of [SideItem]s.
class SideSection extends StatelessWidget {
  const SideSection({super.key, required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              label.toUpperCase(),
              style: s.mono(11, color: s.muted, weight: FontWeight.w500),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// One sidebar row: icon or colored dot, label, and a quiet count.
class SideItem extends StatelessWidget {
  const SideItem({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.dot,
    this.count,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// A project color instead of an icon.
  final Color? dot;
  final int? count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final fg = selected ? s.onSurface : s.text2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? s.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: dot != null
                      ? Center(
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          size: 18,
                          color: selected ? s.primary : s.muted,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (count != null && count! > 0)
                  Text('$count', style: s.mono(12, color: s.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main content and a side column next to it on wide screens; stacked
/// (main first) when there isn't room. For use inside a scroll view.
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 380,
    this.gap = 28,
    this.breakpoint = 900,
  });

  final List<Widget> main;
  final List<Widget> side;
  final double sideWidth;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...main, ...side],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: main,
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: sideWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: side,
            ),
          ),
        ],
      );
    },
  );
}
