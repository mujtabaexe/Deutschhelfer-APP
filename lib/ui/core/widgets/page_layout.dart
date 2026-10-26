import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Scrollable, keyboard-safe page body with responsive margins.
///
/// Content is centered and capped at [AppSpacing.maxContentWidth] so forms
/// and reading text stay comfortable on tablets and in landscape. The scroll
/// view keeps focused fields reachable when the keyboard is open.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.topPadding = AppSpacing.lg,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final margin = constraints.maxWidth < AppSpacing.compactBreakpoint
              ? AppSpacing.pageMarginCompact
              : AppSpacing.pageMargin;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              margin,
              topPadding,
              margin,
              AppSpacing.lg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Actions pinned to the bottom of a screen, above the system navigation bar.
///
/// Use as `Scaffold.bottomNavigationBar` so the primary action stays visible
/// while the page content scrolls.
class PageActions extends StatelessWidget {
  const PageActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final margin = constraints.maxWidth < AppSpacing.compactBreakpoint
              ? AppSpacing.pageMarginCompact
              : AppSpacing.pageMargin;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              margin,
              AppSpacing.sm,
              margin,
              AppSpacing.md,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Title and supporting text at the top of a page.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
