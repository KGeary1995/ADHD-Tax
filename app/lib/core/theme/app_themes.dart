import 'package:flutter/material.dart';

/// Gumption has one look in a dark version (Night) and a light one (Dawn).
/// [Appearance] picks which; "Match phone" follows the system setting.
enum Appearance {
  light('Dawn'),
  dark('Night'),
  system('Match phone');

  const Appearance(this.label);
  final String label;

  ThemeMode get mode => switch (this) {
    Appearance.light => ThemeMode.light,
    Appearance.dark => ThemeMode.dark,
    Appearance.system => ThemeMode.system,
  };
}

/// Font families bundled in assets/fonts (both SIL Open Font License).
abstract final class Fonts {
  /// Sora: headlines, buttons, big numbers.
  static const display = 'Sora';

  /// Manrope: everything else.
  static const ui = 'Manrope';

  /// Numbers that line up use Manrope with tabular figures (see
  /// [ThemeSpec.mono]); there's no separate monospace face.
  static const mono = ui;
}

/// Spacing scale from the 1.1 handoff.
abstract final class Gap {
  static const s1 = 2.0;
  static const s2 = 4.0;
  static const s3 = 6.0;
  static const s4 = 8.0;
  static const s5 = 10.0;
  static const s6 = 14.0;
  static const s7 = 20.0;
  static const s8 = 24.0;
  static const s9 = 32.0;

  /// Side margin on Tasks and Notes.
  static const listSide = 22.0;
}

/// Corner radii from the 1.1 handoff.
abstract final class Radii {
  static const xs = 2.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 24.0;
  static const sheet = 28.0;
}

const _tabular = [FontFeature.tabularFigures()];

/// The design tokens for one brightness. Widgets read it through
/// `context.spec`.
class ThemeSpec {
  const ThemeSpec({
    required this.brightness,
    required this.bg,
    required this.bgTop,
    required this.raised,
    required this.sheet,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.star,
    required this.starDeep,
    required this.accentText,
    required this.starSoft,
    required this.glow,
    required this.dust,
    required this.personal,
    required this.work,
    required this.danger,
    required this.scrim,
    required this.toastBg,
    required this.toastInk,
    required this.toastAccent,
  });

  final Brightness brightness;

  /// The page, under the gradient.
  final Color bg;

  /// Top of the page gradient.
  final Color bgTop;

  /// The selected tab, inputs, cards that need a fill.
  final Color raised;

  /// Sheets and dialogs.
  final Color sheet;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color ink2;

  /// Muted text and hints.
  final Color ink3;

  /// 1px hairline dividers.
  final Color line;

  /// 2px outlines.
  final Color line2;

  /// The accent fill: Start, selected pills, the + button.
  final Color star;

  /// The pressed edge under primary buttons.
  final Color starDeep;

  /// Gold as text (due dates, links). In Dawn it's darker than [star] so
  /// it reads on cream.
  final Color accentText;

  /// Tint for a selected option.
  final Color starSoft;

  /// The glow around stars.
  final Color glow;

  /// The faint background stars.
  final Color dust;

  /// Workspace colours.
  final Color personal;
  final Color work;

  /// Delete only. Overdue is never red.
  final Color danger;

  /// Behind sheets and dialogs.
  final Color scrim;

  /// Toasts use inverse colours.
  final Color toastBg;
  final Color toastInk;
  final Color toastAccent;

  /// Text on [star]. The same dark ink in both themes.
  Color get onStar => const Color(0xFF1A1406);

  bool get isDark => brightness == Brightness.dark;

  // Older names, kept so every screen reads the same tokens.
  Color get background => bg;
  Color get surface => raised;
  Color get border => line2;
  Color get hairline => line;
  Color get outline => line2;
  Color get selected => raised;
  Color get track => line2;
  Color get onSurface => ink;
  Color get text2 => ink2;
  Color get muted => ink2;
  Color get faint => ink3;
  Color get primary => accentText;
  Color get onInk => bg;
  Color get warning => accentText;
  Color get accent => star;
  Color get onAccent => onStar;
  Color get onAccentMuted => onStar.withValues(alpha: 0.72);

  /// A workspace's colour.
  Color workspaceColor(bool work) => work ? this.work : personal;

  /// A project's dot. The same in both themes.
  Color projectColor(int i) => const [
    Color(0xFFE879A6),
    Color(0xFF5CC9A7),
    Color(0xFF8DB4FF),
    Color(0xFFF4A35C),
    Color(0xFFB59BF0),
    Color(0xFF6CC3E8),
    Color(0xFFD8C35A),
    Color(0xFFE8956C),
  ][i % 8];

  List<Color> get confettiColors => [
    star,
    const Color(0xFFFFE2A0),
    const Color(0xFFF4C76A),
    const Color(0xFFEEF0F8),
    const Color(0xFFC9D2F0),
  ];

  /// The page background: a soft gradient from the top.
  Gradient get bgGradient => RadialGradient(
    center: Alignment.topCenter,
    radius: 1.3,
    colors: [bgTop, bg],
    stops: const [0, 0.62],
  );

  /// Sora for headings. Tightened a little at larger sizes.
  TextStyle display(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) => TextStyle(
    fontFamily: Fonts.display,
    fontSize: size,
    fontWeight: weight,
    height: height ?? (size >= 30 ? 1.09 : 1.17),
    letterSpacing: size >= 30
        ? -size * 0.03
        : size >= 20
        ? -size * 0.02
        : 0,
    color: color ?? ink,
  );

  /// Numbers that should line up (times, counts) and quiet metadata.
  TextStyle mono(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => TextStyle(
    fontFamily: Fonts.ui,
    fontSize: size,
    fontWeight: weight,
    fontFeatures: _tabular,
    color: color ?? ink2,
  );

  /// The timer: Sora Light, tabular.
  TextStyle timer(double size, {Color? color}) => TextStyle(
    fontFamily: Fonts.display,
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1,
    letterSpacing: -size * 0.04,
    fontFeatures: _tabular,
    color: color ?? ink,
  );

  /// A stat number on Progress.
  TextStyle stat([double size = 26, Color? color]) => TextStyle(
    fontFamily: Fonts.display,
    fontSize: size,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: -size * 0.03,
    fontFeatures: _tabular,
    color: color ?? ink,
  );

  /// "STEP 2 OF 4": Sora, caps, spaced.
  TextStyle overline({Color? color}) => TextStyle(
    fontFamily: Fonts.display,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 12 * 0.08,
    color: color ?? ink3,
  );

  /// Button labels.
  TextStyle button([double size = 17, Color? color]) => TextStyle(
    fontFamily: Fonts.display,
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -size * 0.01,
    color: color,
  );

  /// The next step on Today and Focus.
  TextStyle step([double size = 19]) => TextStyle(
    fontFamily: Fonts.ui,
    fontSize: size,
    fontWeight: FontWeight.w500,
    height: 26 / 19,
    color: ink,
  );

  /// Row titles and body text.
  TextStyle body({Color? color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: Fonts.ui,
        fontSize: 16,
        fontWeight: weight,
        height: 22 / 16,
        color: color ?? ink,
      );

  /// Group labels.
  TextStyle label({Color? color}) => TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 18 / 14,
    color: color ?? ink2,
  );

  /// Metadata under a title.
  TextStyle caption({Color? color, FontWeight weight = FontWeight.w500}) =>
      TextStyle(
        fontFamily: Fonts.ui,
        fontSize: 13,
        fontWeight: weight,
        height: 18 / 13,
        color: color ?? ink3,
      );
}

const darkSpec = ThemeSpec(
  brightness: Brightness.dark,
  bg: Color(0xFF0A0F1F),
  bgTop: Color(0xFF17203F),
  raised: Color(0xFF151C33),
  sheet: Color(0xFF121930),
  ink: Color(0xFFEEF0F8),
  ink2: Color(0xFFA3AAC2),
  ink3: Color(0xFF717894),
  line: Color(0xFF20283F),
  line2: Color(0xFF323B58),
  star: Color(0xFFF4C76A),
  starDeep: Color(0xFFA8782A),
  accentText: Color(0xFFF4C76A),
  starSoft: Color(0x29F4C76A),
  glow: Color(0x8CF4C76A),
  dust: Color(0xFFC9D2F0),
  personal: Color(0xFFF29E7A),
  work: Color(0xFF8DB4FF),
  danger: Color(0xFFFF8A7A),
  scrim: Color(0x9E03050C),
  toastBg: Color(0xFFEEF0F8),
  toastInk: Color(0xFF0A0F1F),
  toastAccent: Color(0xFF94600F),
);

const lightSpec = ThemeSpec(
  brightness: Brightness.light,
  bg: Color(0xFFF7F1E8),
  bgTop: Color(0xFFFBE2C6),
  raised: Color(0xFFFFFFFF),
  sheet: Color(0xFFFFFFFF),
  ink: Color(0xFF19203A),
  ink2: Color(0xFF555C77),
  ink3: Color(0xFF878B9E),
  line: Color(0xFFE8DFD1),
  line2: Color(0xFFD6CCBC),
  star: Color(0xFFE8A73C),
  starDeep: Color(0xFF9A6413),
  accentText: Color(0xFF8F5D0E),
  starSoft: Color(0x2EE8A73C),
  glow: Color(0x73E8A73C),
  dust: Color(0xFF9A8F7C),
  personal: Color(0xFFD9704A),
  work: Color(0xFF3D6FD1),
  danger: Color(0xFFB8402F),
  scrim: Color(0x6119203A),
  toastBg: Color(0xFF19203A),
  toastInk: Color(0xFFF7F1E8),
  toastAccent: Color(0xFFF4C76A),
);

/// The Night tokens, for the few things that are always dark (Your sky).
const nightSpec = darkSpec;

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
    primary: s.star,
    onPrimary: s.onStar,
    secondary: s.accentText,
    onSecondary: s.onStar,
    secondaryContainer: s.starSoft,
    onSecondaryContainer: s.ink,
    error: s.danger,
    onError: s.isDark ? s.onStar : Colors.white,
    surface: s.bg,
    onSurface: s.ink,
    onSurfaceVariant: s.ink2,
    surfaceContainerLowest: s.bg,
    surfaceContainerLow: s.raised,
    surfaceContainer: s.raised,
    surfaceContainerHigh: s.sheet,
    surfaceContainerHighest: s.raised,
    outline: s.line2,
    outlineVariant: s.line,
    inverseSurface: s.toastBg,
    onInverseSurface: s.toastInk,
    inversePrimary: s.toastAccent,
    scrim: s.scrim,
  );
  final r14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.lg),
  );
  const ui = TextStyle(fontFamily: Fonts.ui);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: s.brightness,
    fontFamily: Fonts.ui,
    // Every page sits on SkyBackground (see app.dart), so scaffolds let
    // the gradient and stars show through.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: s.bg,
    splashFactory: InkRipple.splashFactory,
  );
  OutlineInputBorder field(Color c, [double w = 2]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.lg),
    borderSide: BorderSide(color: c, width: w),
  );
  return base.copyWith(
    extensions: [AppThemeExt(s)],
    textTheme: base.textTheme
        .apply(bodyColor: s.ink, displayColor: s.ink)
        .copyWith(
          bodyLarge: ui.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
          bodyMedium: ui.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        )
        .apply(bodyColor: s.ink, displayColor: s.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: s.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s.display(17, weight: FontWeight.w600),
      iconTheme: IconThemeData(color: s.ink, size: 22),
      actionsIconTheme: IconThemeData(color: s.ink, size: 22),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.sheet,
      surfaceTintColor: Colors.transparent,
      barrierColor: s.scrim,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      titleTextStyle: s.display(24),
      contentTextStyle: ui.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: s.ink2,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.sheet,
      modalBackgroundColor: s.sheet,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: s.scrim,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: s.line2,
      dragHandleSize: const Size(38, 5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: s.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: s.line2, width: 2),
      ),
      textStyle: ui.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: s.ink,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.toastBg,
      elevation: 0,
      contentTextStyle: ui.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: s.toastInk,
      ),
      actionTextColor: s.toastAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: s.toastBg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      textStyle: ui.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: s.toastInk,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.star,
        foregroundColor: s.onStar,
        disabledBackgroundColor: s.line,
        disabledForegroundColor: s.ink3,
        shape: r14,
        elevation: 0,
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: s.button(17),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled) ? s.ink3 : s.ink,
        ),
        side: WidgetStateProperty.resolveWith(
          (st) => BorderSide(
            color: st.contains(WidgetState.disabled) ? s.line2 : s.ink,
            width: 2,
          ),
        ),
        shape: WidgetStatePropertyAll(r14),
        minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
        textStyle: WidgetStatePropertyAll(s.button(17)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: s.accentText,
        shape: r14,
        minimumSize: const Size(44, 44),
        textStyle: ui.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: s.ink2),
    ),
    iconTheme: IconThemeData(color: s.ink2, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.raised,
      hintStyle: ui.copyWith(color: s.ink3, fontWeight: FontWeight.w500),
      labelStyle: ui.copyWith(color: s.ink2, fontWeight: FontWeight.w600),
      floatingLabelStyle: ui.copyWith(
        color: s.accentText,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: field(s.line2),
      enabledBorder: field(s.line2),
      focusedBorder: field(s.star),
      errorBorder: field(s.danger),
      focusedErrorBorder: field(s.danger),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: s.star,
      selectionColor: s.starSoft,
      selectionHandleColor: s.star,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected)
            ? s.onStar
            : (s.isDark ? s.ink2 : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.star : s.line2,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm - 2),
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.star : null,
      ),
      checkColor: WidgetStatePropertyAll(s.onStar),
      side: BorderSide(color: s.ink3, width: 2),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.star : s.ink3,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.star,
      linearTrackColor: s.line2,
      circularTrackColor: s.line2,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: s.star,
      inactiveTrackColor: s.line2,
      thumbColor: s.star,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: s.ink2,
      textColor: s.ink,
      titleTextStyle: ui.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: s.ink,
      ),
      subtitleTextStyle: ui.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: s.ink3,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: s.sheet,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: s.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: s.sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
    ),
    dividerTheme: DividerThemeData(color: s.line, space: 1, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
