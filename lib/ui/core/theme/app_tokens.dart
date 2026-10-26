import 'package:flutter/material.dart';

/// Raw colour values for the Deutschhelfer palette.
///
/// Widgets must not use these directly. Read colours from
/// `Theme.of(context).colorScheme` so light and dark themes stay consistent.
/// Contrast ratios for each pairing are recorded in `docs/ui-design-system.md`
/// and enforced by `test/ui/core/theme/app_theme_test.dart`.
abstract final class AppPalette {
  // Light theme.
  static const forest = Color(0xFF173F35);
  static const forestDeep = Color(0xFF0B2A22);
  static const paleGreen = Color(0xFFDCECE5);
  static const amber = Color(0xFFD9A441);
  static const amberPale = Color(0xFFF6E7C4);
  static const amberDeep = Color(0xFF3D2C05);
  static const offWhite = Color(0xFFF7F8F5);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF17211D);
  static const inkMuted = Color(0xFF596760);
  static const outline = Color(0xFF74817A);
  static const outlineSoft = Color(0xFFD5DCD7);
  static const containerLow = Color(0xFFF2F4F0);
  static const container = Color(0xFFEEF2EE);
  static const containerHigh = Color(0xFFE7ECE8);
  static const containerHighest = Color(0xFFE0E6E2);
  static const error = Color(0xFFB3261E);
  static const errorPale = Color(0xFFF9DEDC);
  static const errorDeep = Color(0xFF410E0B);

  // Dark theme.
  static const darkBackground = Color(0xFF101713);
  static const darkSurface = Color(0xFF19221D);
  static const darkSurfaceLowest = Color(0xFF0B110E);
  static const darkSurfaceLow = Color(0xFF151D18);
  static const darkSurfaceHigh = Color(0xFF222C26);
  static const darkSurfaceHighest = Color(0xFF2C3731);
  static const darkPrimary = Color(0xFFA8D5BF);
  static const darkPrimaryContainer = Color(0xFF24503F);
  static const darkAmber = Color(0xFFE8C27A);
  static const darkAmberDeep = Color(0xFF2E2100);
  static const darkAmberContainer = Color(0xFF5A4410);
  static const darkInk = Color(0xFFE3E9E5);
  static const darkInkMuted = Color(0xFFB5C2BA);
  static const darkOutline = Color(0xFF8B988F);
  static const darkOutlineSoft = Color(0xFF3A4640);
  static const darkError = Color(0xFFF2B8B5);
  static const darkErrorDeep = Color(0xFF601410);
  static const darkErrorContainer = Color(0xFF8C1D18);
}

/// Spacing scale on an 8-point rhythm, with 4 and 12 for fine adjustment.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page margin on phones narrower than [compactBreakpoint].
  static const double pageMarginCompact = 16;

  /// Horizontal page margin on regular phones and larger.
  static const double pageMargin = 24;

  /// Screens narrower than this use [pageMarginCompact].
  static const double compactBreakpoint = 360;

  /// Maximum width for reading and form content on tablets and landscape.
  static const double maxContentWidth = 560;
}

/// Corner-radius scale.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
}

/// Size rules for interactive elements.
abstract final class AppSizes {
  /// Minimum touch target in logical pixels.
  static const double minTouchTarget = 48;

  /// Height of full-width primary and secondary buttons.
  static const double buttonHeight = 52;
}
