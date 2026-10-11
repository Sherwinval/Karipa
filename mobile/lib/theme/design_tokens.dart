import 'package:flutter/material.dart';

/// Approved Karipa identity. Do not generate extra seed-color tones.
abstract final class KaripaPalette {
  static const coral = Color(0xFFFF5A49);
  static const midnight = Color(0xFF0C0B10);
  static const stone = Color(0xFFCFCDBE);
  static const ivory = Color(0xFFE3E0D3);
  static const charcoal = Color(0xFF2B2B2B);

  static const values = [coral, midnight, stone, ivory, charcoal];

  /// Keeps legacy optional color arguments source-compatible without carrying
  /// their old decorative palette into shared components.
  static Color approvedOr(Color? requested, Color fallback) =>
      values.contains(requested) ? requested! : fallback;

  static Color onFill(Color fill) =>
      fill == midnight || fill == charcoal ? ivory : midnight;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  static double pageMargin(double width) => width < 360 ? lg : xl;
}

abstract final class AppRadii {
  static const control = 12.0;
  static const panel = 16.0;
  static const card = 24.0;
}

abstract final class AppSizes {
  static const touchTarget = 48.0;
  static const buttonHeight = 56.0;
  static const navigationHeight = 80.0;
  static const icon = 24.0;
  static const compactIcon = 20.0;
  static const contentMaxWidth = 640.0;
}
