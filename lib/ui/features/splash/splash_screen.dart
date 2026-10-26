import 'package:flutter/material.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand_mark.dart';

/// Shown while the saved session and account status load.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: context.l10n.stateLoading,
          liveRegion: true,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 72),
              SizedBox(height: AppSpacing.lg),
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
