import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Builds the light and dark Material 3 themes from the design tokens.
///
/// Surface mapping: `surface` is the page background, and
/// `surfaceContainerLowest` is the raised card and field fill.
abstract final class AppTheme {
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.forest,
    onPrimary: AppPalette.white,
    primaryContainer: AppPalette.paleGreen,
    onPrimaryContainer: AppPalette.forestDeep,
    secondary: AppPalette.amber,
    onSecondary: AppPalette.ink,
    secondaryContainer: AppPalette.amberPale,
    onSecondaryContainer: AppPalette.amberDeep,
    error: AppPalette.error,
    onError: AppPalette.white,
    errorContainer: AppPalette.errorPale,
    onErrorContainer: AppPalette.errorDeep,
    surface: AppPalette.offWhite,
    onSurface: AppPalette.ink,
    onSurfaceVariant: AppPalette.inkMuted,
    surfaceContainerLowest: AppPalette.white,
    surfaceContainerLow: AppPalette.containerLow,
    surfaceContainer: AppPalette.container,
    surfaceContainerHigh: AppPalette.containerHigh,
    surfaceContainerHighest: AppPalette.containerHighest,
    outline: AppPalette.outline,
    outlineVariant: AppPalette.outlineSoft,
    inverseSurface: AppPalette.ink,
    onInverseSurface: AppPalette.offWhite,
    inversePrimary: AppPalette.darkPrimary,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.darkPrimary,
    onPrimary: AppPalette.forestDeep,
    primaryContainer: AppPalette.darkPrimaryContainer,
    onPrimaryContainer: AppPalette.paleGreen,
    secondary: AppPalette.darkAmber,
    onSecondary: AppPalette.darkAmberDeep,
    secondaryContainer: AppPalette.darkAmberContainer,
    onSecondaryContainer: AppPalette.amberPale,
    error: AppPalette.darkError,
    onError: AppPalette.darkErrorDeep,
    errorContainer: AppPalette.darkErrorContainer,
    onErrorContainer: AppPalette.errorPale,
    surface: AppPalette.darkBackground,
    onSurface: AppPalette.darkInk,
    onSurfaceVariant: AppPalette.darkInkMuted,
    surfaceContainerLowest: AppPalette.darkSurfaceLowest,
    surfaceContainerLow: AppPalette.darkSurfaceLow,
    surfaceContainer: AppPalette.darkSurface,
    surfaceContainerHigh: AppPalette.darkSurfaceHigh,
    surfaceContainerHighest: AppPalette.darkSurfaceHighest,
    outline: AppPalette.darkOutline,
    outlineVariant: AppPalette.darkOutlineSoft,
    inverseSurface: AppPalette.darkInk,
    onInverseSurface: AppPalette.darkBackground,
    inversePrimary: AppPalette.forest,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData get light => _build(lightScheme);
  static ThemeData get dark => _build(darkScheme);

  /// Card and field fill. Pure white in light mode, a raised tone in dark mode.
  static Color raisedSurface(ColorScheme scheme) =>
      scheme.brightness == Brightness.light
      ? scheme.surfaceContainerLowest
      : scheme.surfaceContainer;

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021(platform: TargetPlatform.android)
        .englishLike
        .merge(
          scheme.brightness == Brightness.light
              ? Typography.material2021().black
              : Typography.material2021().white,
        );
    return base
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 32,
            height: 40 / 32,
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 28,
            height: 36 / 28,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 17, height: 26 / 17),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 16, height: 24 / 16),
          bodySmall: base.bodySmall?.copyWith(fontSize: 14, height: 20 / 14),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static ThemeData _build(ColorScheme scheme) {
    final text = _textTheme(scheme);
    final fieldRadius = BorderRadius.circular(AppRadii.md);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );
    const buttonSize = Size(64, AppSizes.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: raisedSurface(scheme),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raisedSurface(scheme),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge?.copyWith(fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
