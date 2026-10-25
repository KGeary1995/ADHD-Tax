import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_themes.dart';
import '../core/theme/ph.dart';

/// A card: a 2px outline, a light fill in Dawn, radius 14.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = Radii.lg,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final r = math.min(radius, Radii.lg);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
      side: color != null && borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor ?? s.line2, width: 2),
    );
    return Material(
      color: color ?? (s.isDark ? Colors.transparent : s.raised.withAlpha(150)),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Big screen title (Tasks, Notes, Your sky) with an optional subtitle
/// and trailing actions.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: s.display(34)),
              if (subtitle != null) ...[
                const SizedBox(height: Gap.s1),
                Text(subtitle!, style: s.mono(13, color: s.ink2)),
              ],
            ],
          ),
        ),
        if (trailing != null)
          Padding(padding: const EdgeInsets.only(top: 2), child: trailing),
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
      padding: const EdgeInsets.only(bottom: Gap.s2),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (count != null)
              TextSpan(
                text: ' $count',
                style: TextStyle(color: s.ink3, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        style: s.display(17),
      ),
    );
  }
}

/// Label above a form group or a settings group: "STEPS", "SYNC".
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.inset = 0});
  final String text;
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(inset, 0, inset, Gap.s4),
    child: Text(text.toUpperCase(), style: context.spec.overline()),
  );
}

/// Settings-style group: an overline label, then rows with hairlines
/// between them. No card around it.
class Group extends StatelessWidget {
  const Group({super.key, this.label, required this.children});
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label != null) FieldLabel(label!),
      for (final (i, c) in children.indexed) ...[
        if (i > 0) const Divider(height: 1),
        c,
      ],
    ],
  );
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(color: s.ink2, size: 20),
                  child: leading!,
                ),
                const SizedBox(width: Gap.s6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: s.body(weight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: Gap.s1),
                      Text(
                        subtitle!,
                        style: subtitleMono ? s.mono(13) : s.caption(),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Gap.s6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The value and caret at the end of a row that opens something.
class RowValue extends StatelessWidget {
  const RowValue(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: s.caption(color: s.ink2, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: Gap.s2),
        Icon(Ph.caretRight, size: 16, color: s.ink3),
      ],
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
    this.leading,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool subtitleMono;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GroupRow(
      title: title,
      subtitle: subtitle,
      subtitleMono: subtitleMono,
      leading: leading,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// Segmented control (Dawn / Night / Match phone): a 2px outlined track,
/// the chosen segment raised with an ink outline.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.dotOf,
    this.inset = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  /// An optional colour dot before a label (Personal, Work).
  final Color? Function(T)? dotOf;

  /// Kept for older callers; the look is the same on a sheet.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Container(
      padding: const EdgeInsets.all(Gap.s2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: s.line2, width: 2),
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
                  color: v == selected ? s.raised : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md - 2),
                    side: v == selected
                        ? BorderSide(color: s.ink, width: 2)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.md - 2),
                    onTap: () => onSelected(v),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dotOf?.call(v) case final dot?) ...[
                                WsDot(dot),
                                const SizedBox(width: Gap.s3),
                              ],
                              Flexible(
                                child: Text(
                                  labelOf(v),
                                  textAlign: TextAlign.center,
                                  style: s.button(
                                    13,
                                    v == selected ? s.ink : s.ink2,
                                  ),
                                ),
                              ),
                            ],
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

/// Personal / Work, two up: the chosen one outlined in its colour.
class WorkspaceOption extends StatelessWidget {
  const WorkspaceOption({
    super.key,
    required this.work,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// The Work side (else Personal), for its colour.
  final bool work;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final color = s.workspaceColor(work);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: selected ? color : s.line2, width: 2),
    );
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? s.raised : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WsDot(color, size: 9),
                  const SizedBox(width: Gap.s4),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected ? s.ink : s.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An 8px square workspace or project dot.
class WsDot extends StatelessWidget {
  const WsDot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(Radii.xs),
    ),
  );
}

/// An option pill: a 2px outline when off, filled with star when on.
/// [solid] fills with ink instead (filter tabs).
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
    this.dot,
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

  /// A colour dot before the label (workspace or project).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final bg = !selected
        ? Colors.transparent
        : solid
        ? s.ink
        : s.star;
    final fg = !selected
        ? s.ink
        : solid
        ? s.bg
        : s.onStar;
    final style = TextStyle(
      fontFamily: Fonts.ui,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
      color: fg,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: selected ? bg : s.line2, width: 2),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (dot != null) ...[
                    WsDot(dot!),
                    const SizedBox(width: Gap.s3),
                  ] else if (icon != null) ...[
                    if (iconColor != null)
                      WsDot(iconColor!)
                    else
                      Icon(icon, size: 17, color: fg),
                    const SizedBox(width: Gap.s3),
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
    this.dotOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final bool mono;
  final Color? Function(T)? dotOf;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Gap.s3,
    runSpacing: Gap.s3,
    children: [
      for (final v in values)
        Pill(
          label: labelOf(v),
          selected: v == selected,
          mono: mono,
          dot: dotOf?.call(v),
          onTap: () => onSelected(v),
        ),
    ],
  );
}

/// A sheet's title (h2) with an optional line under it.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: s.display(26)),
        if (subtitle != null) ...[
          const SizedBox(height: Gap.s1),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 14, color: s.ink2, height: 1.35),
          ),
        ],
      ],
    );
  }
}

/// A label over a group of options in a sheet: "How much time do you
/// have?", with an optional quiet note ("optional").
class OptionLabel extends StatelessWidget {
  const OptionLabel(this.text, {super.key, this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s5),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (note != null)
              TextSpan(
                text: ' $note',
                style: TextStyle(fontWeight: FontWeight.w500, color: s.ink3),
              ),
          ],
        ),
        style: s.label(),
      ),
    );
  }
}

/// One option in a row of equal options (Staying in / Can go out): fills
/// its cell, star when chosen, a 2px outline when not.
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dot,
    this.height = 46,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dot;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final fg = selected ? s.onStar : s.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: selected ? s.star : s.line2, width: 2),
    );
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? s.star : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: Gap.s4),
                  ] else if (dot != null) ...[
                    WsDot(dot!),
                    const SizedBox(width: Gap.s3),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Fonts.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width [OptionButton]s in a row, with 8px between.
class OptionRow extends StatelessWidget {
  const OptionRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(width: Gap.s4),
          Expanded(child: c),
        ],
      ],
    ),
  );
}

/// A tappable row in a sheet: an icon, a title and subtitle, a caret.
/// Outlined, radius 14 (Pick one of these three; ideas in Smaller).
class SheetChoice extends StatelessWidget {
  const SheetChoice({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.caret = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Panel(
      color: Colors.transparent,
      borderColor: s.line2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: s.accentText),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: s.body(
                    weight: subtitle == null
                        ? FontWeight.w600
                        : FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Gap.s1),
                  Text(subtitle!, style: s.caption(color: s.ink2)),
                ],
              ],
            ),
          ),
          if (caret) ...[
            const SizedBox(width: 8),
            Icon(Ph.caretRight, size: 16, color: s.ink3),
          ],
        ],
      ),
    );
  }
}

/// A confirmation: title, a line, Cancel and the action. Pops true when
/// confirmed. [danger] makes the action red (Delete only).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirm,
    this.cancel = 'Cancel',
    this.danger = false,
  });

  final String title;
  final String body;
  final String confirm;
  final String cancel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: s.display(24)),
              const SizedBox(height: Gap.s3),
              Text(
                body,
                style: TextStyle(fontSize: 15, height: 1.45, color: s.ink2),
              ),
              const SizedBox(height: Gap.s7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OutlineButton(
                      label: cancel,
                      fontSize: 16,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: Gap.s4),
                  Expanded(
                    child: danger
                        ? FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: s.danger,
                              foregroundColor: s.isDark
                                  ? s.onStar
                                  : Colors.white,
                              textStyle: s.button(16),
                            ),
                            child: Text(confirm),
                          )
                        : PrimaryButton(
                            label: confirm,
                            fontSize: 16,
                            onPressed: () => Navigator.pop(context, true),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar on a pushed page: back (or close), an optional title, and an
/// optional gold overline on the right ("WEEKLY RESET").
AppBar topBar(
  BuildContext context, {
  String? title,
  String? overline,
  bool close = false,
  VoidCallback? onBack,
  List<Widget> actions = const [],
}) {
  final s = context.spec;
  return AppBar(
    leading: IconButton(
      tooltip: close ? 'Close' : 'Back',
      icon: Icon(close ? Ph.x : Ph.caretLeft, color: close ? s.ink2 : s.ink),
      onPressed:
          onBack ??
          () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              Router.of(context).routerDelegate.popRoute();
            }
          },
    ),
    titleSpacing: 0,
    title: title == null ? null : Text(title, style: s.display(20)),
    actions: [
      ...actions,
      if (overline != null)
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 20),
          child: Center(
            child: Text(overline, style: s.overline(color: s.accentText)),
          ),
        ),
    ],
  );
}

/// Padding for a sheet's content: 24 at the sides, room at the bottom.
const sheetPadding = EdgeInsets.fromLTRB(24, 0, 24, 24);

/// The primary button: star fill, dark ink, and a pressed edge under it
/// that drops from 4px to 1px while pressed.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.fontSize = 17,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double fontSize;

  /// Fill the available width.
  final bool expand;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final enabled = widget.onPressed != null;
    final edge = !enabled ? 0.0 : (_down ? 1.0 : 4.0);
    final fg = enabled ? s.onStar : s.ink3;
    final button = Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: widget.height + 4,
          // Disabled: no edge, but the same top as an outline button.
          padding: EdgeInsets.only(top: enabled ? 4 - edge : 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: enabled ? s.star : s.line,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: [
                if (edge > 0)
                  BoxShadow(color: s.starDeep, offset: Offset(0, edge)),
              ],
            ),
            child: SizedBox(
              height: widget.height,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.height < 48 ? 12 : 20,
                ),
                child: Row(
                  mainAxisSize: widget.expand
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: widget.fontSize + 2, color: fg),
                      const SizedBox(width: Gap.s4),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: s.button(widget.fontSize, fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: button,
    );
  }
}

/// The secondary button: a 2px ink outline. [quiet] uses a line2 outline
/// for lesser actions.
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.fontSize = 17,
    this.quiet = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double fontSize;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final color = onPressed == null ? s.ink3 : s.ink;
    return Padding(
      // Lines up with a PrimaryButton's pressed edge next to it.
      padding: const EdgeInsets.only(bottom: 4),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(height, height),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(
            color: quiet || onPressed == null ? s.line2 : s.ink,
            width: 2,
          ),
          textStyle: s.button(fontSize),
          foregroundColor: color,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 2),
              const SizedBox(width: Gap.s4),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet action: an icon and an ink2 label, no box.
class QuietAction extends StatelessWidget {
  const QuietAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: s.ink2),
              const SizedBox(width: Gap.s3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: s.label(color: s.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 44px square icon button with a 2px outline (Tasks' filter, the
/// Settings gear).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(color: selected ? s.ink : s.line2, width: 2),
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: selected ? s.raised : Colors.transparent,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, size: 20, color: s.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 26px check box inside a 44px tap target. Done fills it with star and
/// shows a four-point star.
class StarCheck extends StatelessWidget {
  const StarCheck({
    super.key,
    required this.done,
    required this.onTap,
    this.label,
    this.size = 26,
  });

  final bool done;
  final VoidCallback? onTap;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return Semantics(
      checked: done,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: done ? s.star : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: done ? s.star : s.ink3, width: 2),
              ),
              child: done
                  ? Icon(Ph.starFourFill, size: size * 0.62, color: s.onStar)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The page behind everything: a soft gradient from the top and, at
/// night, a sparse field of faint stars. Painted once, behind the scroll.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child, this.spec});
  final Widget child;

  /// Force a look (Your sky is always Night).
  final ThemeSpec? spec;

  @override
  Widget build(BuildContext context) {
    final s = spec ?? context.spec;
    return DecoratedBox(
      decoration: BoxDecoration(color: s.bg, gradient: s.bgGradient),
      child: CustomPaint(painter: _DustPainter(s.dust, s.isDark), child: child),
    );
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.color, this.dark);
  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // The same field every time; only the top 60% of the page.
    final r = math.Random(5);
    final p = Paint();
    for (var i = 0; i < 46; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * math.min(size.height, 844) * 0.6;
      final big = r.nextDouble() > 0.8;
      final a = dark
          ? 0.25 + r.nextDouble() * 0.5
          : 0.12 + r.nextDouble() * 0.2;
      p.color = color.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), big ? 1 : 0.6, p);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) =>
      old.color != color || old.dark != dark;
}

/// The Gumption star: four points with curved sides.
class StarMark extends StatelessWidget {
  const StarMark({super.key, this.size = 22, this.color, this.glow = false});
  final double size;
  final Color? color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final s = context.spec;
    return CustomPaint(
      size: Size.square(size),
      painter: _StarPainter(color ?? s.star, glow ? s.glow : null),
    );
  }
}

/// The four-point star as a path in a [size]-wide square.
Path starPath(double size) {
  final c = size / 2;
  final r = size / 2;
  // From the app icon's SVG: tips at r, control points at (0.083, 0.278).
  const a = 0.0827;
  const b = 0.278;
  Offset p(double x, double y) => Offset(c + x * r, c + y * r);
  final o1 = p(a, -b), o2 = p(b, -a);
  return Path()
    ..moveTo(c, c - r)
    ..cubicTo(o1.dx, o1.dy, o2.dx, o2.dy, c + r, c)
    ..cubicTo(p(b, a).dx, p(b, a).dy, p(a, b).dx, p(a, b).dy, c, c + r)
    ..cubicTo(p(-a, b).dx, p(-a, b).dy, p(-b, a).dx, p(-b, a).dy, c - r, c)
    ..cubicTo(p(-b, -a).dx, p(-b, -a).dy, p(-a, -b).dx, p(-a, -b).dy, c, c - r)
    ..close();
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color, this.glow);
  final Color color;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = starPath(size.width);
    if (glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glow!
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.18),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.glow != glow;
}

/// The old name for the mark, kept for callers.
class GumptionMark extends StatelessWidget {
  const GumptionMark({super.key, this.size = 22, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      StarMark(size: size, color: color ?? context.spec.star);
}

/// Logo mark plus the word "Gumption".
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const StarMark(size: 18),
      const SizedBox(width: Gap.s4),
      Flexible(
        child: Text(
          'Gumption',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.spec.display(18),
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
          : bg(s.accent, s.onAccent, Ph.checkBold, 'Done', true),
      secondaryBackground: bg(
        s.danger,
        Colors.white,
        Ph.trash,
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

/// A bottom sheet on a phone (thumb reach, above the keyboard); a centered
/// window on a computer, where a sheet rising from the bottom of a wide
/// window feels like a phone app. Builders lay out as for a sheet: no
/// title bar, side padding of their own, `Navigator.pop` to close.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
}) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= wideBreakpoint && size.height >= 640) {
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: size.height - 96,
          ),
          child: Padding(
            // Stands in for the sheet's drag handle.
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: builder(ctx),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: builder,
  );
}
