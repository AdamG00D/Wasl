import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// لون التطبيق الأساسي (المستخدم بيختاره من الإعدادات).
class AccentTheme {
  const AccentTheme(this.id, this.label, this.light, this.lightSecond, this.dark, this.darkSecond);

  final String id;
  final String label;
  final Color light;
  final Color lightSecond;
  final Color dark;
  final Color darkSecond;

  Color accent(Brightness b) => b == Brightness.dark ? dark : light;
  Color second(Brightness b) => b == Brightness.dark ? darkSecond : lightSecond;

  static const all = <AccentTheme>[
    AccentTheme('indigo', 'نيلي', Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF818CF8), Color(0xFFA78BFA)),
    AccentTheme('teal', 'فيروزي', Color(0xFF0D9488), Color(0xFF0891B2), Color(0xFF2DD4BF), Color(0xFF22D3EE)),
    AccentTheme('emerald', 'أخضر', Color(0xFF059669), Color(0xFF65A30D), Color(0xFF34D399), Color(0xFFA3E635)),
    AccentTheme('coral', 'مرجاني', Color(0xFFE11D48), Color(0xFFEA580C), Color(0xFFFB7185), Color(0xFFFB923C)),
    AccentTheme('amber', 'كهرماني', Color(0xFFD97706), Color(0xFFDC2626), Color(0xFFFBBF24), Color(0xFFF87171)),
    AccentTheme('sky', 'سماوي', Color(0xFF0284C7), Color(0xFF4F46E5), Color(0xFF38BDF8), Color(0xFF818CF8)),
    AccentTheme('pink', 'وردي', Color(0xFFDB2777), Color(0xFF9333EA), Color(0xFFF472B6), Color(0xFFC084FC)),
    AccentTheme('graphite', 'رمادي', Color(0xFF334155), Color(0xFF0F172A), Color(0xFFCBD5E1), Color(0xFF94A3B8)),
  ];

  static AccentTheme byId(String? id) => all.firstWhere((a) => a.id == id, orElse: () => all.first);
}

/// ألوان الأفاتار (كل شخص بيختار لون لبروفايله).
const avatarColors = <Color>[
  Color(0xFF6366F1),
  Color(0xFF0EA5E9),
  Color(0xFF14B8A6),
  Color(0xFF22C55E),
  Color(0xFFEAB308),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFFA855F7),
  Color(0xFF64748B),
];

Color avatarColor(int index) => avatarColors[index.abs() % avatarColors.length];

/// ألوان التصميم (Design tokens) — تتغير حسب الوضع الفاتح/الداكن واللون الأساسي.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.isDark,
    required this.accent,
    required this.onAccent,
    required this.second,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final bool isDark;
  final Color accent;
  final Color onAccent;
  final Color second;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;

  Color get accentSoft => accent.withValues(alpha: isDark ? 0.18 : 0.10);

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, second],
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      );

  /// لون نص مناسب فوق أي خلفية.
  static Color onColor(Color c) => c.computeLuminance() > 0.5 ? const Color(0xFF0B0B0F) : Colors.white;

  factory Palette.of(AccentTheme accent, Brightness b) {
    final dark = b == Brightness.dark;
    final a = accent.accent(b);
    return Palette(
      isDark: dark,
      accent: a,
      onAccent: onColor(a),
      second: accent.second(b),
      bg: dark ? const Color(0xFF0B0B0F) : const Color(0xFFF6F6F8),
      surface: dark ? const Color(0xFF15151B) : Colors.white,
      surfaceAlt: dark ? const Color(0xFF1F1F28) : const Color(0xFFEDEDF2),
      border: dark ? const Color(0x14FFFFFF) : const Color(0xFFE4E4EA),
      text: dark ? const Color(0xFFF2F2F5) : const Color(0xFF111118),
      textMuted: dark ? const Color(0xFF9A9AA8) : const Color(0xFF6B6B7B),
      success: dark ? const Color(0xFF34D399) : const Color(0xFF059669),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      danger: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    );
  }

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      isDark: t < 0.5 ? isDark : other.isDark,
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      second: l(second, other.second),
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Plex';

  static ThemeData build(AccentTheme accent, Brightness brightness) {
    final p = Palette.of(accent, brightness);
    final scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.second,
      onSecondary: Palette.onColor(p.second),
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerHighest: p.surfaceAlt,
      outline: p.border,
      outlineVariant: p.border,
      error: p.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.bg,
      splashFactory: InkRipple.splashFactory,
    );

    final radius = BorderRadius.circular(18);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      extensions: [p],
      textTheme: base.textTheme.apply(
        bodyColor: p.text,
        displayColor: p.text,
        fontFamily: fontFamily,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.text,
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(color: p.textMuted, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: p.textMuted),
        floatingLabelStyle: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        disabledBorder: border(Colors.transparent),
        focusedBorder: border(p.accent, 1.6),
        errorBorder: border(p.danger),
        focusedErrorBorder: border(p.danger, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(64, 50),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.textMuted,
          selectedBackgroundColor: p.accentSoft,
          selectedForegroundColor: p.accent,
          side: BorderSide(color: p.border),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.border,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          height: 1.6,
          color: p.textMuted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      tooltipTheme: TooltipThemeData(
        textStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.28),
        selectionHandleColor: p.accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
