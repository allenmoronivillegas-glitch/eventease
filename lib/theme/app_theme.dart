import 'package:flutter/material.dart';

class AppAccentColor {
  const AppAccentColor(this.id, this.label, this.color);

  final String id;
  final String label;
  final Color color;
}

class AppTheme {
  static const List<AppAccentColor> accents = [
    AppAccentColor('indigo', 'Indigo', Color(0xFF4F46E5)),
    AppAccentColor('blue', 'Blue', Color(0xFF2563EB)),
    AppAccentColor('teal', 'Teal', Color(0xFF0F766E)),
    AppAccentColor('green', 'Green', Color(0xFF15803D)),
    AppAccentColor('pink', 'Pink', Color(0xFFDB2777)),
    AppAccentColor('orange', 'Orange', Color(0xFFEA580C)),
  ];

  static Color _primary = accents.first.color;
  static Brightness _brightness = Brightness.light;

  static void configure({
    required String accentId,
    required Brightness brightness,
  }) {
    _primary = accentFor(accentId);
    _brightness = brightness;
  }

  static Color accentFor(String accentId) {
    return accents
        .firstWhere(
          (accent) => accent.id == accentId,
          orElse: () => accents.first,
        )
        .color;
  }

  static bool get _isDark => _brightness == Brightness.dark;

  static Color get primary => _primary;
  static Color get onPrimary => onAccentFor(_primary);
  static Color onAccentFor(Color color) =>
      color.computeLuminance() > 0.18
      ? const Color(0xFF0F172A)
      : Colors.white;
  static Color get primaryDark =>
      Color.lerp(_primary, Colors.black, _isDark ? 0.08 : 0.24)!;
  static Color get primaryLight => _isDark
      ? Color.lerp(_primary, Colors.white, 0.24)!
      : Color.lerp(_primary, Colors.white, 0.91)!;
  static Color get accent => _primary;
  static Color get accentLight => _isDark
      ? Color.lerp(_primary, Colors.white, 0.16)!
      : Color.lerp(_primary, Colors.white, 0.93)!;

  static Color get success =>
      _isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get successLight =>
      _isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  static Color get warning =>
      _isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get warningLight =>
      _isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
  static Color get danger =>
      _isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get dangerLight =>
      _isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);

  static Color get background =>
      _isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  static Color get surface => _isDark ? const Color(0xFF111827) : Colors.white;
  static Color get cardBorder =>
      _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  static Color get textPrimary =>
      _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
  static Color get textMuted =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);

  static ThemeData get lightTheme => buildTheme(Brightness.light);
  static ThemeData get darkTheme => buildTheme(Brightness.dark);

  static ThemeData buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: brightness,
        ).copyWith(
          primary: _primary,
          onPrimary: onPrimary,
          secondary: _primary,
          onSecondary: onPrimary,
          surface: dark ? const Color(0xFF111827) : Colors.white,
          onSurface: dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          outline: dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          outlineVariant: dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0B1120)
          : const Color(0xFFF8FAFC),
      primaryColor: _primary,
      colorScheme: colors,
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        hintStyle: TextStyle(
          color: dark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Color.alphaBlend(
          _primary.withValues(alpha: dark ? 0.34 : 0.14),
          colors.surface,
        ),
      ),
    );
  }
}
