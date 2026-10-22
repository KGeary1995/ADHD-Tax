import 'package:flutter/material.dart';

/// Gumption has one look in a light and a dark version. [Appearance] picks
/// which; "Match phone" follows the system setting.
enum Appearance {
  light('Light'),
  dark('Dark'),
  system('Match phone');

  const Appearance(this.label);
  final String label;

  ThemeMode get mode => switch (this) {
    Appearance.light => ThemeMode.light,
    Appearance.dark => ThemeMode.dark,
    Appearance.system => ThemeMode.system,
  };
}

/// Font families bundled in assets/fonts (all SIL Open Font License).
abstract final class Fonts {
  /// Headlines and big numbers.
  static const display = 'Bricolage';

  /// Everything else.
  static const ui = 'Geist';

  /// Times, counts and other numbers that line up.
  static const mono = 'GeistMono';
}

/// The design tokens for one brightness. Widgets read it through
/// `context.spec`.
class ThemeSpec {
  const ThemeSpec({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.border,
    required this.hairline,
    required this.outline,
    required this.selected,
    required this.track,
    required this.onSurface,
    required this.text2,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.ink,
    required this.onInk,
    required this.nav,
    required this.navBorder,
    required this.navIcon,
    required this.navIconActive,
    required this.warning,
    required this.danger,
  });

  final Brightness brightness;

  /// The page.
  final Color background;

  /// Cards, grouped settings, tiles, sheets.
  final Color surface;

  /// Card edge. Transparent in light mode, where fills do the separating.
  final Color border;

  /// Dividers between rows.
  final Color hairline;

  /// Outline of unselected pills and secondary buttons.
  final Color outline;

  /// The selected segment of a segmented control.
  final Color selected;

  /// Empty part of progress bars and the focus ring; off switches.
  final Color track;

  final Color onSurface;

  /// Body text on tiles and pills.
  final Color text2;

  /// Labels and metadata.
  final Color muted;

  /// Placeholders, separators, counts next to headings.
  final Color faint;

  /// Brand teal as text or an icon on [background] (darker in light mode
  /// so it stays readable on white).
  final Color primary;

  /// The near-black of the Start button on the teal card, and of the nav
  /// pill in light mode.
  final Color ink;
  final Color onInk;

  final Color nav;
  final Color navBorder;
  final Color navIcon;
  final Color navIconActive;

  /// Due dates and gentle heads-ups. Never used for shame.
  final Color warning;
  final Color danger;

  /// Brand teal as a fill: the task card, selected pills, the Add button.
  Color get accent => const Color(0xFF5FD8BE);

  /// Text and icons on [accent].
  Color get onAccent => const Color(0xFF062520);

  /// Secondary text on [accent].
  Color get onAccentMuted => const Color(0xFF0B4038);

  bool get isDark => brightness == Brightness.dark;

  /// A project's dot. Mid-tone hues that read on light and dark.
  Color projectColor(int i) => const [
    Color(0xFF5FD8BE),
    Color(0xFFF2B45A),
    Color(0xFF8FA8F5),
    Color(0xFFE88AA8),
    Color(0xFFB5D86A),
    Color(0xFFC79BEA),
    Color(0xFF6CC3E8),
    Color(0xFFE8956C),
  ][i % 8];

  List<Color> get confettiColors => [
    accent,
    const Color(0xFFF2B45A),
    const Color(0xFFF2F5F4),
    const Color(0xFF8BE7D3),
    const Color(0xFF2E9C86),
  ];

  /// Bricolage Grotesque, tight, for headings.
  TextStyle display(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w800,
  }) => TextStyle(
    fontFamily: Fonts.display,
    fontSize: size,
    fontWeight: weight,
    height: 1.05,
    letterSpacing: -size * 0.03,
    color: color ?? onSurface,
  );

  /// Geist Mono for numbers that should line up.
  TextStyle mono(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: Fonts.mono,
    fontSize: size,
    fontWeight: weight,
    color: color ?? muted,
  );
}

const darkSpec = ThemeSpec(
  brightness: Brightness.dark,
  background: Color(0xFF0D1012),
  surface: Color(0xFF151A1D),
  border: Color(0xFF1F2629),
  hairline: Color(0xFF1F2629),
  outline: Color(0xFF2A3336),
  selected: Color(0xFF2A3336),
  track: Color(0xFF1F272A),
  onSurface: Color(0xFFF2F5F4),
  text2: Color(0xFFC9D2CF),
  muted: Color(0xFF94A19E),
  faint: Color(0xFF6E7A77),
  primary: Color(0xFF5FD8BE),
  ink: Color(0xFF0D1012),
  onInk: Color(0xFFF2F5F4),
  nav: Color(0xFF161C1F),
  navBorder: Color(0xFF252D30),
  navIcon: Color(0xFF6E7A77),
  navIconActive: Color(0xFFF2F5F4),
  warning: Color(0xFFF2B45A),
  danger: Color(0xFFF08A7A),
);

const lightSpec = ThemeSpec(
  brightness: Brightness.light,
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFF1F4F3),
  border: Color(0x00000000),
  hairline: Color(0xFFE3E7E4),
  outline: Color(0xFFDCE1DE),
  selected: Color(0xFFFFFFFF),
  track: Color(0xFFE3E7E4),
  onSurface: Color(0xFF111416),
  text2: Color(0xFF2E3533),
  muted: Color(0xFF5E6866),
  faint: Color(0xFF8C9693),
  primary: Color(0xFF0B7563),
  ink: Color(0xFF111416),
  onInk: Color(0xFFF3F4F1),
  nav: Color(0xFF111416),
  navBorder: Color(0xFF111416),
  navIcon: Color(0xFF8C9693),
  navIconActive: Color(0xFFFFFFFF),
  warning: Color(0xFF9A5B00),
  danger: Color(0xFFB4432F),
);

/// Exposes [ThemeSpec] to widgets via `Theme.of(context)`.
class AppThemeExt extends ThemeExtension<AppThemeExt> {
  const AppThemeExt(this.spec);
  final ThemeSpec spec;

  @override
  AppThemeExt copyWith({ThemeSpec? spec}) => AppThemeExt(spec ?? this.spec);

  @override
  AppThemeExt lerp(AppThemeExt? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppThemeContext on BuildContext {
  ThemeSpec get spec => Theme.of(this).extension<AppThemeExt>()!.spec;

  /// The system "reduce motion" setting.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

ThemeData buildTheme(ThemeSpec s) {
  final scheme = ColorScheme(
    brightness: s.brightness,
    primary: s.accent,
    onPrimary: s.onAccent,
    secondary: s.primary,
    onSecondary: s.onAccent,
    secondaryContainer: s.selected,
    onSecondaryContainer: s.onSurface,
    error: s.danger,
    onError: Colors.white,
    surface: s.background,
    onSurface: s.onSurface,
    onSurfaceVariant: s.muted,
    surfaceContainerLowest: s.background,
    surfaceContainerLow: s.surface,
    surfaceContainer: s.surface,
    surfaceContainerHigh: s.surface,
    surfaceContainerHighest: s.surface,
    outline: s.outline,
    outlineVariant: s.hairline,
    inverseSurface: s.onSurface,
    onInverseSurface: s.background,
    inversePrimary: s.primary,
  );
  const stadium = StadiumBorder();
  const ui = TextStyle(fontFamily: Fonts.ui);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: s.brightness,
    fontFamily: Fonts.ui,
    scaffoldBackgroundColor: s.background,
    canvasColor: s.background,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    extensions: [AppThemeExt(s)],
    textTheme: base.textTheme.apply(
      bodyColor: s.onSurface,
      displayColor: s.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: s.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s.display(22),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.isDark ? s.surface : s.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titleTextStyle: s.display(24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.isDark ? s.surface : s.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: s.isDark ? const Color(0xFF343E41) : s.outline,
      dragHandleSize: const Size(40, 5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: s.isDark ? s.surface : s.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: s.isDark ? s.outline : s.hairline),
      ),
      textStyle: ui.copyWith(fontSize: 15, color: s.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.isDark ? const Color(0xFFF2F5F4) : s.ink,
      contentTextStyle: ui.copyWith(
        fontSize: 15,
        color: s.isDark ? s.background : s.onInk,
      ),
      actionTextColor: s.isDark ? const Color(0xFF0B7563) : s.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: s.isDark ? const Color(0xFFF2F5F4) : s.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: ui.copyWith(
        fontSize: 13,
        color: s.isDark ? s.background : s.onInk,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.accent,
        foregroundColor: s.onAccent,
        shape: stadium,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: s.onSurface,
        side: BorderSide(color: s.outline),
        shape: stadium,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: s.primary,
        shape: stadium,
        minimumSize: const Size(48, 44),
        textStyle: ui.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: s.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.isDark ? s.background : s.surface,
      hintStyle: ui.copyWith(color: s.faint),
      labelStyle: ui.copyWith(color: s.muted),
      floatingLabelStyle: ui.copyWith(color: s.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.isDark ? s.outline : s.surface),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.isDark ? s.outline : s.surface),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.accent, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected)
            ? s.onAccent
            : (s.isDark ? s.muted : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected)
            ? s.accent
            : (s.isDark ? s.outline : const Color(0xFFCDD3D0)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      fillColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.accent : null,
      ),
      checkColor: WidgetStatePropertyAll(s.onAccent),
      side: BorderSide(color: s.faint, width: 2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.accent,
      linearTrackColor: s.track,
      circularTrackColor: s.track,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: s.accent,
      inactiveTrackColor: s.track,
      thumbColor: s.accent,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: s.muted,
      textColor: s.onSurface,
      titleTextStyle: ui.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: s.onSurface,
      ),
      subtitleTextStyle: ui.copyWith(fontSize: 13, color: s.muted),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: s.isDark ? s.surface : s.background,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: s.isDark ? s.surface : s.background,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: s.isDark ? s.surface : s.background,
    ),
    dividerTheme: DividerThemeData(color: s.hairline, space: 1, thickness: 1),
  );
}
