import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

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
    primary: KaripaPalette.coral,
    primaryDark: KaripaPalette.midnight,
    primaryLight: KaripaPalette.ivory,
    accent: KaripaPalette.coral,
    accentLight: KaripaPalette.stone,
    accentDark: KaripaPalette.charcoal,
    // Legacy identifier retained for compatibility; no lime color remains.
    lime: KaripaPalette.coral,
    pageBackground: KaripaPalette.contentBackground,
    surface: KaripaPalette.contentBackground,
    border: KaripaPalette.charcoal,
    borderDark: KaripaPalette.midnight,
    mutedText: KaripaPalette.charcoal,
    mutedLight: KaripaPalette.stone,
    // Feedback meaning is conveyed by text/icons, not additional hues.
    success: KaripaPalette.charcoal,
    successLight: KaripaPalette.stone,
    warning: KaripaPalette.charcoal,
    warningLight: KaripaPalette.stone,
    danger: KaripaPalette.charcoal,
    dangerLight: KaripaPalette.stone,
  );

  Color get routeHighlight => accent;
  Color get routeCasing => primaryDark;
  Color get recordedTrack => primaryDark;
  Color get recordedTrackCasing => primaryLight;
  Color get metricPanel => primaryDark;
  Color get onMetricPanel => primaryLight;
  Color get disabledSurface => mutedLight;
  Color get onDisabledSurface => mutedText;

  static PathCraftColors of(BuildContext context) =>
      Theme.of(context).extension<PathCraftColors>() ?? defaultPalette;

  @override
  PathCraftColors copyWith({
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
  PathCraftColors lerp(ThemeExtension<PathCraftColors>? other, double t) {
    if (other is! PathCraftColors) {
      return this;
    }

    return PathCraftColors(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      primaryLight:
          Color.lerp(primaryLight, other.primaryLight, t) ?? primaryLight,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentLight: Color.lerp(accentLight, other.accentLight, t) ?? accentLight,
      accentDark: Color.lerp(accentDark, other.accentDark, t) ?? accentDark,
      lime: Color.lerp(lime, other.lime, t) ?? lime,
      pageBackground:
          Color.lerp(pageBackground, other.pageBackground, t) ?? pageBackground,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      border: Color.lerp(border, other.border, t) ?? border,
      borderDark: Color.lerp(borderDark, other.borderDark, t) ?? borderDark,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      mutedLight: Color.lerp(mutedLight, other.mutedLight, t) ?? mutedLight,
      success: Color.lerp(success, other.success, t) ?? success,
      successLight:
          Color.lerp(successLight, other.successLight, t) ?? successLight,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningLight:
          Color.lerp(warningLight, other.warningLight, t) ?? warningLight,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerLight: Color.lerp(dangerLight, other.dangerLight, t) ?? dangerLight,
    );
  }
}

class AppTheme {
  static final ThemeData lightTheme = buildTheme();
  static final ThemeData darkTheme = buildTheme(brightness: Brightness.dark);

  /// Disabling network fonts is a test seam, not an app setting change.
  static ThemeData buildTheme({
    Brightness brightness = Brightness.light,
    bool useGoogleFonts = true,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = _colorScheme(brightness);
    final tokens = PathCraftColors.defaultPalette.copyWith(
      pageBackground: scheme.surface,
      surface: scheme.surfaceContainerLow,
      border: scheme.outline,
      mutedText: dark ? KaripaPalette.stone : KaripaPalette.charcoal,
      mutedLight:
          dark ? KaripaPalette.charcoal : KaripaPalette.supportingSurface,
      success: scheme.onSurface,
      successLight: scheme.surfaceContainerLow,
      warning: scheme.onSurface,
      warningLight: scheme.surfaceContainerLow,
      danger: scheme.error,
      dangerLight: scheme.errorContainer,
    );
    final text = _textTheme(scheme.onSurface, useGoogleFonts);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    final primaryStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
          Size(AppSizes.touchTarget, AppSizes.buttonHeight)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.lg)),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? tokens.disabledSurface
              : scheme.primary),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? tokens.onDisabledSurface
              : scheme.onPrimary),
      // Coral alone has insufficient boundary contrast on light surfaces.
      side: WidgetStateProperty.resolveWith((states) => BorderSide(
          color: scheme.outline,
          width: states.contains(WidgetState.focused) ? 3 : 1.5)),
    );
    final secondaryStyle = primaryStyle.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? tokens.disabledSurface
              : scheme.surface),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? tokens.onDisabledSurface
              : scheme.onSurface),
    );
    OutlineInputBorder inputBorder(double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.outline, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      disabledColor: tokens.onDisabledSurface,
      textTheme: text,
      iconTheme: IconThemeData(color: scheme.onSurface, size: AppSizes.icon),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(style: primaryStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryStyle),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: tokens.onDisabledSurface,
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        textStyle: text.labelLarge,
      )),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size.square(AppSizes.touchTarget),
      )),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
        centerTitle: false,
      ),
      drawerTheme: DrawerThemeData(
          backgroundColor: scheme.surfaceContainer,
          surfaceTintColor: scheme.surfaceContainer),
      navigationRailTheme: NavigationRailThemeData(
          backgroundColor: scheme.surfaceContainer,
          indicatorColor: scheme.primary),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surfaceContainer,
          modalBackgroundColor: scheme.surfaceContainer,
          surfaceTintColor: scheme.surfaceContainer),
      dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface, surfaceTintColor: scheme.surface),
      popupMenuTheme: PopupMenuThemeData(
          color: scheme.surface, surfaceTintColor: scheme.surface),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: scheme.outlineVariant)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        labelStyle: text.bodyMedium,
        hintStyle: text.bodyMedium,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        errorMaxLines: 4,
        border: inputBorder(1),
        enabledBorder: inputBorder(1),
        disabledBorder: inputBorder(1),
        focusedBorder: inputBorder(3),
        errorBorder: inputBorder(2),
        focusedErrorBorder: inputBorder(3),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navigationHeight,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary,
        indicatorShape:
            StadiumBorder(side: BorderSide(color: scheme.outline, width: 1.5)),
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimary
                  : scheme.onSurface,
            )),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedItemColor: dark ? scheme.primary : scheme.onSurface,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle:
            text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: text.labelMedium,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KaripaPalette.supportingSurface,
        selectedColor: scheme.primary,
        disabledColor: KaripaPalette.supportingSurface,
        labelStyle: text.labelMedium?.copyWith(color: KaripaPalette.midnight),
        checkmarkColor: scheme.onPrimary,
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurface,
        linearTrackColor: scheme.surfaceContainerLow,
        circularTrackColor: scheme.surfaceContainerLow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        smallSizeConstraints: const BoxConstraints.tightFor(
            width: AppSizes.touchTarget, height: AppSizes.touchTarget),
        shape:
            shape.copyWith(side: BorderSide(color: scheme.outline, width: 1.5)),
        elevation: 0,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surface),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(KaripaPalette.midnight),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : KaripaPalette.stone),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant, space: AppSpacing.xl),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.onInverseSurface,
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionColor: scheme.surfaceContainerLow,
        selectionHandleColor: scheme.onSurface,
      ),
      extensions: [tokens],
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface =
        dark ? KaripaPalette.midnight : KaripaPalette.contentBackground;
    final container =
        dark ? KaripaPalette.charcoal : KaripaPalette.supportingSurface;
    final ink = dark ? KaripaPalette.ivory : KaripaPalette.midnight;
    return ColorScheme(
      brightness: brightness,
      primary: KaripaPalette.coral,
      onPrimary: KaripaPalette.midnight,
      primaryContainer: KaripaPalette.coral,
      onPrimaryContainer: KaripaPalette.midnight,
      primaryFixed: KaripaPalette.coral,
      primaryFixedDim: KaripaPalette.coral,
      onPrimaryFixed: KaripaPalette.midnight,
      onPrimaryFixedVariant: KaripaPalette.charcoal,
      secondary: dark ? KaripaPalette.stone : KaripaPalette.charcoal,
      onSecondary: dark ? KaripaPalette.midnight : KaripaPalette.ivory,
      secondaryContainer: container,
      onSecondaryContainer: ink,
      secondaryFixed: KaripaPalette.stone,
      secondaryFixedDim: KaripaPalette.stone,
      onSecondaryFixed: KaripaPalette.midnight,
      onSecondaryFixedVariant: KaripaPalette.charcoal,
      tertiary: KaripaPalette.stone,
      onTertiary: KaripaPalette.midnight,
      tertiaryContainer: container,
      onTertiaryContainer: ink,
      tertiaryFixed: KaripaPalette.stone,
      tertiaryFixedDim: KaripaPalette.stone,
      onTertiaryFixed: KaripaPalette.midnight,
      onTertiaryFixedVariant: KaripaPalette.charcoal,
      error: dark ? KaripaPalette.coral : KaripaPalette.charcoal,
      onError: dark ? KaripaPalette.midnight : KaripaPalette.ivory,
      errorContainer: container,
      onErrorContainer: ink,
      surface: surface,
      onSurface: ink,
      surfaceDim: container,
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: container,
      surfaceContainerHigh: container,
      surfaceContainerHighest: container,
      onSurfaceVariant: dark ? KaripaPalette.stone : KaripaPalette.charcoal,
      outline: dark ? KaripaPalette.stone : KaripaPalette.charcoal,
      outlineVariant: dark ? KaripaPalette.stone : KaripaPalette.charcoal,
      inverseSurface: dark ? KaripaPalette.ivory : KaripaPalette.midnight,
      onInverseSurface: dark ? KaripaPalette.midnight : KaripaPalette.ivory,
      inversePrimary: dark ? KaripaPalette.midnight : KaripaPalette.coral,
      shadow: KaripaPalette.midnight,
      scrim: KaripaPalette.midnight,
      surfaceTint: surface,
    );
  }

  static TextTheme _textTheme(Color ink, bool useGoogleFonts) {
    TextStyle display(double size) {
      final style = TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.6,
          color: ink);
      return useGoogleFonts
          ? GoogleFonts.manrope(textStyle: style)
          : style.copyWith(fontFamily: 'Manrope');
    }

    TextStyle body(double size, FontWeight weight) {
      final style = TextStyle(
          fontSize: size, fontWeight: weight, height: 1.4, color: ink);
      return useGoogleFonts
          ? GoogleFonts.inter(textStyle: style)
          : style.copyWith(fontFamily: 'Inter');
    }

    return TextTheme(
      displayLarge: display(48),
      displayMedium: display(40),
      displaySmall: display(36),
      headlineLarge: display(32),
      headlineMedium: display(28),
      headlineSmall: display(24),
      titleLarge: body(22, FontWeight.w700),
      titleMedium: body(18, FontWeight.w700),
      titleSmall: body(16, FontWeight.w700),
      bodyLarge: body(18, FontWeight.w400),
      bodyMedium: body(16, FontWeight.w400),
      bodySmall: body(14, FontWeight.w400),
      labelLarge: body(16, FontWeight.w700),
      labelMedium: body(14, FontWeight.w600),
      labelSmall: body(14, FontWeight.w600),
    );
  }
}
