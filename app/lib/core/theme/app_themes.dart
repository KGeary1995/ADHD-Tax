import 'package:flutter/material.dart';

/// Visual personality on top of a ColorScheme: glow, glass, background
/// treatment, celebration palette, motion.
enum BackdropStyle { plain, gradient, grid, scanlines }

class ThemeSpec {
  const ThemeSpec({
    required this.id,
    required this.name,
    required this.tagline,
    required this.group,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.onSurface,
    required this.muted,
    this.onPrimary,
    this.backgroundEnd,
    this.backdrop = BackdropStyle.plain,
    this.glow = false,
    this.glass = false,
    this.reduceMotion = false,
    this.radius = 14,
    this.fontFamily,
    this.fontFamilyFallback,
    this.success = const Color(0xFF22C55E),
    this.warning = const Color(0xFFF59E0B),
    this.danger = const Color(0xFFEF4444),
  });

  final String id;
  final String name;
  final String tagline;
  final String group;
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color? backgroundEnd;
  final Color surface;
  final Color surfaceAlt;
  final Color onSurface;
  final Color muted;
  final Color? onPrimary;
  final BackdropStyle backdrop;
  final bool glow;
  final bool glass;
  final bool reduceMotion;
  final double radius;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final Color success;
  final Color warning;
  final Color danger;

  List<Color> get confettiColors => [
    primary,
    secondary,
    success,
    warning,
    onSurface,
  ];
}

const _mono = ['Cascadia Mono', 'Consolas', 'Menlo', 'Roboto Mono'];

const themeSpecs = <ThemeSpec>[
  ThemeSpec(
    id: 'slate',
    name: 'Slate',
    tagline: 'Clean, bright, boardroom-ready.',
    group: 'Professional',
    brightness: Brightness.light,
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF0EA5E9),
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9EDF4),
    onSurface: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
  ),
  ThemeSpec(
    id: 'graphite',
    name: 'Graphite',
    tagline: 'Focused dark mode for long days.',
    group: 'Professional',
    brightness: Brightness.dark,
    primary: Color(0xFF7C9CFF),
    secondary: Color(0xFF34D399),
    background: Color(0xFF0F1115),
    surface: Color(0xFF171A21),
    surfaceAlt: Color(0xFF222630),
    onSurface: Color(0xFFE6E8EE),
    muted: Color(0xFF9097A6),
    onPrimary: Color(0xFF0B1020),
  ),
  ThemeSpec(
    id: 'clinic_calm',
    name: 'Clinic Calm',
    tagline: 'Soft teal. Low glare under fluorescent lights.',
    group: 'Professional',
    brightness: Brightness.light,
    primary: Color(0xFF0F766E),
    secondary: Color(0xFF3B82F6),
    background: Color(0xFFEFF6F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFDDEDEB),
    onSurface: Color(0xFF12302D),
    muted: Color(0xFF5B7471),
  ),
  ThemeSpec(
    id: 'neon_grid',
    name: 'Neon Grid',
    tagline: 'Cyberpunk magenta and cyan on a synthwave grid.',
    group: 'Futuristic',
    brightness: Brightness.dark,
    primary: Color(0xFFFF2BD6),
    secondary: Color(0xFF00F0FF),
    background: Color(0xFF0B0221),
    backgroundEnd: Color(0xFF240B4D),
    surface: Color(0xCC140A2E),
    surfaceAlt: Color(0xFF231048),
    onSurface: Color(0xFFF5E9FF),
    muted: Color(0xFFB59BD6),
    onPrimary: Color(0xFF12001A),
    backdrop: BackdropStyle.grid,
    glow: true,
    success: Color(0xFF39FF14),
    warning: Color(0xFFFFE600),
  ),
  ThemeSpec(
    id: 'holo_glass',
    name: 'Holo Glass',
    tagline: 'Frosted glass panels over a deep-ocean gradient.',
    group: 'Futuristic',
    brightness: Brightness.dark,
    primary: Color(0xFF7DF9FF),
    secondary: Color(0xFFB388FF),
    background: Color(0xFF0F2027),
    backgroundEnd: Color(0xFF2C5364),
    surface: Color(0x33FFFFFF),
    surfaceAlt: Color(0x22FFFFFF),
    onSurface: Color(0xFFF0FBFF),
    muted: Color(0xFFB3D4DE),
    onPrimary: Color(0xFF00222A),
    backdrop: BackdropStyle.gradient,
    glass: true,
    radius: 20,
  ),
  ThemeSpec(
    id: 'mission_control',
    name: 'Mission Control',
    tagline: 'HUD amber on deep space. Houston, we have focus.',
    group: 'Futuristic',
    brightness: Brightness.dark,
    primary: Color(0xFFFFB547),
    secondary: Color(0xFF4FD1C5),
    background: Color(0xFF070B12),
    backgroundEnd: Color(0xFF0E1726),
    surface: Color(0xFF0F1824),
    surfaceAlt: Color(0xFF162234),
    onSurface: Color(0xFFE8EEF6),
    muted: Color(0xFF8DA2BC),
    onPrimary: Color(0xFF1A1000),
    backdrop: BackdropStyle.gradient,
    glow: true,
    radius: 6,
  ),
  ThemeSpec(
    id: 'terminal',
    name: 'Terminal',
    tagline: 'Green phosphor. For people who think in commands.',
    group: 'Futuristic',
    brightness: Brightness.dark,
    primary: Color(0xFF33FF66),
    secondary: Color(0xFFFFB000),
    background: Color(0xFF040804),
    surface: Color(0xFF0A120A),
    surfaceAlt: Color(0xFF102010),
    onSurface: Color(0xFFC8FFC8),
    muted: Color(0xFF6FA86F),
    onPrimary: Color(0xFF001A06),
    backdrop: BackdropStyle.scanlines,
    glow: true,
    radius: 2,
    fontFamily: 'monospace',
    fontFamilyFallback: _mono,
  ),
  ThemeSpec(
    id: 'low_stim',
    name: 'Low-Stim',
    tagline: 'Muted and still, for overstimulated days.',
    group: 'Accessibility',
    brightness: Brightness.light,
    primary: Color(0xFF5E7F64),
    secondary: Color(0xFF7D8F9C),
    background: Color(0xFFF2F0EB),
    surface: Color(0xFFFAF9F6),
    surfaceAlt: Color(0xFFE8E5DE),
    onSurface: Color(0xFF2E2C28),
    muted: Color(0xFF77736B),
    reduceMotion: true,
    success: Color(0xFF6E9A72),
    warning: Color(0xFFC09A5B),
    danger: Color(0xFFB0645A),
  ),
  ThemeSpec(
    id: 'high_contrast',
    name: 'High Contrast',
    tagline: 'Maximum legibility.',
    group: 'Accessibility',
    brightness: Brightness.dark,
    primary: Color(0xFFFFE600),
    secondary: Color(0xFF00E5FF),
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceAlt: Color(0xFF1A1A1A),
    onSurface: Color(0xFFFFFFFF),
    muted: Color(0xFFDDDDDD),
    onPrimary: Color(0xFF000000),
    radius: 8,
  ),
];

ThemeSpec themeSpecById(String id) =>
    themeSpecs.firstWhere((t) => t.id == id, orElse: () => themeSpecs.first);

/// Exposes [ThemeSpec] extras to widgets via `Theme.of(context)`.
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
}

ThemeData buildTheme(ThemeSpec s) {
  final onPrimary =
      s.onPrimary ??
      (s.brightness == Brightness.dark ? Colors.black : Colors.white);
  final scheme = ColorScheme(
    brightness: s.brightness,
    primary: s.primary,
    onPrimary: onPrimary,
    secondary: s.secondary,
    onSecondary: onPrimary,
    // Selected chips and segments: a tint of the brand color, not M3's
    // auto-derived container color.
    secondaryContainer: s.primary.withValues(alpha: 0.22),
    onSecondaryContainer: s.onSurface,
    error: s.danger,
    onError: Colors.white,
    surface: s.surface,
    onSurface: s.onSurface,
    onSurfaceVariant: s.muted,
    surfaceContainerHighest: s.surfaceAlt,
    surfaceContainerHigh: s.surfaceAlt,
    surfaceContainer: s.surfaceAlt,
    surfaceContainerLow: s.surface,
    outline: s.muted.withValues(alpha: 0.5),
    outlineVariant: s.muted.withValues(alpha: 0.25),
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(s.radius),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: s.brightness,
    fontFamily: s.fontFamily,
    fontFamilyFallback: s.fontFamilyFallback,
    scaffoldBackgroundColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    extensions: [AppThemeExt(s)],
    canvasColor: s.background,
    dialogTheme: DialogThemeData(
      backgroundColor: s.glass ? s.background : s.surface,
      shape: shape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.glass ? s.background : s.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(s.radius)),
      ),
    ),
    cardTheme: CardThemeData(color: s.surface, shape: shape, elevation: 0),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s.radius / 1.5),
      ),
      side: BorderSide(color: s.muted.withValues(alpha: 0.3)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceAlt.withValues(alpha: s.glass ? 0.4 : 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(s.radius),
        borderSide: BorderSide.none,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: s.primary.withValues(alpha: 0.18),
      selectedIconTheme: IconThemeData(color: s.primary),
      selectedLabelTextStyle: TextStyle(
        color: s.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.glass ? s.background : s.surface,
      indicatorColor: s.primary.withValues(alpha: 0.18),
    ),
    dividerTheme: DividerThemeData(color: s.muted.withValues(alpha: 0.2)),
    pageTransitionsTheme: s.reduceMotion
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
            },
          )
        : null,
  );
}
