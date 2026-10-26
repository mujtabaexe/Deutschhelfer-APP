import 'package:flutter/material.dart';

import '../l10n_extensions.dart';
import '../theme/app_tokens.dart';

/// Provisional logo: a monogram tile with an amber underline.
///
/// Replace with the final logo asset once one exists. Size scales with
/// [size]; colours come from the theme.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: context.l10n.brandMarkLabel,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DH',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  height: 1,
                ),
              ),
              SizedBox(height: size * 0.06),
              Container(
                width: size * 0.34,
                height: size * 0.05,
                decoration: BoxDecoration(
                  color: scheme.secondary,
                  borderRadius: BorderRadius.circular(size),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
