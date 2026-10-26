import 'dart:math' as math;

import 'package:deutschhelfer/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // Text needs 4.5:1. Non-text UI such as field borders and icons needs 3:1.
  const text = 4.5;
  const nonText = 3.0;

  for (final (name, scheme) in [
    ('light', AppTheme.lightScheme),
    ('dark', AppTheme.darkScheme),
  ]) {
    group('$name scheme contrast', () {
      final raised = AppTheme.raisedSurface(scheme);
      final pairs = <String, (Color, Color, double)>{
        'body text on page': (scheme.onSurface, scheme.surface, text),
        'body text on card': (scheme.onSurface, raised, text),
        'secondary text on page': (
          scheme.onSurfaceVariant,
          scheme.surface,
          text,
        ),
        'secondary text on card': (scheme.onSurfaceVariant, raised, text),
        'label on primary button': (scheme.onPrimary, scheme.primary, text),
        'primary text link on page': (scheme.primary, scheme.surface, text),
        'text on primary container': (
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
          text,
        ),
        'text on secondary': (scheme.onSecondary, scheme.secondary, text),
        'text on secondary container': (
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
          text,
        ),
        'error text on card': (scheme.error, raised, text),
        'text on error container': (
          scheme.onErrorContainer,
          scheme.errorContainer,
          text,
        ),
        'text on inverse surface': (
          scheme.onInverseSurface,
          scheme.inverseSurface,
          text,
        ),
        'field border on page': (scheme.outline, scheme.surface, nonText),
        'field border on card': (scheme.outline, raised, nonText),
      };

      pairs.forEach((label, pair) {
        final (foreground, background, minimum) = pair;
        test(label, () {
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(minimum),
          );
        });
      });
    });
  }

  test('amber accent is not usable as text or icons on light surfaces', () {
    // Documents a known limit: amber is a fill colour only in light mode.
    const scheme = AppTheme.lightScheme;
    expect(
      contrast(scheme.secondary, scheme.surfaceContainerLowest),
      lessThan(nonText),
    );
  });

  test('body text is at least 16 logical pixels', () {
    expect(AppTheme.light.textTheme.bodyMedium?.fontSize, 16);
    expect(AppTheme.dark.textTheme.bodyMedium?.fontSize, 16);
  });
}
