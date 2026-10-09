import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PathCraftColors extends ThemeExtension<PathCraftColors> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color lime;
  final Color pageBackground;
  final Color surface;
  final Color border;
  final Color borderDark;
  final Color mutedText;
  final Color mutedLight;
  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color danger;
  final Color dangerLight;

  const PathCraftColors({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.lime,
    required this.pageBackground,
    required this.surface,
    required this.border,
    required this.borderDark,
    required this.mutedText,
    required this.mutedLight,
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.danger,
    required this.dangerLight,
  });

  static const PathCraftColors defaultPalette = PathCraftColors(
    primary: Color(0xFF18352B),
    primaryDark: Color(0xFF10271F),
    primaryLight: Color(0xFF365B48),
    accent: Color(0xFF176B45),
    accentLight: Color(0xFFEAF3E9),
    accentDark: Color(0xFF105435),
    lime: Color(0xFFD9F279),
    pageBackground: Color(0xFFEDF1E8),
    surface: Color(0xFFF8FAF4),
    border: Color(0xFFE0E6DA),
    borderDark: Color(0xFFC7D2C3),
    mutedText: Color(0xFF596B61),
    mutedLight: Color(0xFFEDF1E8),
    success: Color(0xFF176B45),
    successLight: Color(0xFFEAF3E9),
    warning: Color(0xFF9A4E15),
    warningLight: Color(0xFFFFF0DE),
    danger: Color(0xFFB53E35),
    dangerLight: Color(0xFFFFF0EC),
  );

  @override
  ThemeExtension<PathCraftColors> copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accent,
    Color? accentLight,
    Color? accentDark,
    Color? lime,
    Color? pageBackground,
    Color? surface,
    Color? border,
    Color? borderDark,
    Color? mutedText,
    Color? mutedLight,
    Color? success,
    Color? successLight,
    Color? warning,
    Color? warningLight,
    Color? danger,
    Color? dangerLight,
  }) {
    return PathCraftColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentDark: accentDark ?? this.accentDark,
      lime: lime ?? this.lime,
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      borderDark: borderDark ?? this.borderDark,
      mutedText: mutedText ?? this.mutedText,
      mutedLight: mutedLight ?? this.mutedLight,
      success: success ?? this.success,
      successLight: successLight ?? this.successLight,
      warning: warning ?? this.warning,
      warningLight: warningLight ?? this.warningLight,
      danger: danger ?? this.danger,
      dangerLight: dangerLight ?? this.dangerLight,
    );
  }

  @override
  ThemeExtension<PathCraftColors> lerp(ThemeExtension<PathCraftColors>? other, double t) {
    if (other is! PathCraftColors) {
      return this;
    }

    return PathCraftColors(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t) ?? primaryLight,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentLight: Color.lerp(accentLight, other.accentLight, t) ?? accentLight,
      accentDark: Color.lerp(accentDark, other.accentDark, t) ?? accentDark,
      lime: Color.lerp(lime, other.lime, t) ?? lime,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t) ?? pageBackground,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      border: Color.lerp(border, other.border, t) ?? border,
      borderDark: Color.lerp(borderDark, other.borderDark, t) ?? borderDark,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      mutedLight: Color.lerp(mutedLight, other.mutedLight, t) ?? mutedLight,
      success: Color.lerp(success, other.success, t) ?? success,
      successLight: Color.lerp(successLight, other.successLight, t) ?? successLight,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningLight: Color.lerp(warningLight, other.warningLight, t) ?? warningLight,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerLight: Color.lerp(dangerLight, other.dangerLight, t) ?? dangerLight,
    );
  }
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: PathCraftColors.defaultPalette.pageBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PathCraftColors.defaultPalette.primary,
      primary: PathCraftColors.defaultPalette.primary,
      secondary: PathCraftColors.defaultPalette.accent,
      surface: PathCraftColors.defaultPalette.surface,
      error: PathCraftColors.defaultPalette.danger,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      headlineLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: PathCraftColors.defaultPalette.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: PathCraftColors.defaultPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: PathCraftColors.defaultPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: PathCraftColors.defaultPalette.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: PathCraftColors.defaultPalette.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      PathCraftColors.defaultPalette,
    ],
  );

  static final ThemeData darkTheme = lightTheme.copyWith(
    scaffoldBackgroundColor: const Color(0xFF10271F),
    colorScheme: ColorScheme.fromSeed(
      seedColor: PathCraftColors.defaultPalette.primary,
      brightness: Brightness.dark,
      primary: PathCraftColors.defaultPalette.primary,
      secondary: PathCraftColors.defaultPalette.accent,
      surface: const Color(0xFF18352B),
    ),
  );
}
