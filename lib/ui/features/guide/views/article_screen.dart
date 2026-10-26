import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/repositories/guide_repository.dart';
import '../../../../domain/models/guide.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/guide_view_models.dart';
import 'guide_screen.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({
    super.key,
    required this.articleId,
    required this.repository,
    required this.isPremiumUser,
  });

  final String articleId;
  final GuideRepository repository;
  final bool isPremiumUser;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final ArticleViewModel _viewModel = ArticleViewModel(
    repository: widget.repository,
    articleId: widget.articleId,
    isPremiumUser: widget.isPremiumUser,
  );

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final article = _viewModel.article;
          return switch (_viewModel.state) {
            ArticleState.loading => const LoadingView(),
            ArticleState.missing => EmptyView(
              icon: Icons.article_outlined,
              title: l10n.guideArticleMissing,
            ),
            ArticleState.failed => ErrorView(
              message:
                  _viewModel.premiumFailure == PremiumContentFailure.notFound
                  ? l10n.premiumNotFound
                  : l10n.premiumUnavailable,
              onRetry: _viewModel.load,
            ),
            ArticleState.locked => _LockedArticle(article: article!),
            ArticleState.ready => _ArticleBody(
              article: article!,
              categoryTitle: _viewModel.categoryTitle,
            ),
          };
        },
      ),
    );
  }
}

class _LockedArticle extends StatelessWidget {
  const _LockedArticle({required this.article});

  final GuideArticle article;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PageBody(
      topPadding: AppSpacing.xs,
      children: [
        const Align(alignment: Alignment.centerLeft, child: PremiumBadge()),
        const SizedBox(height: AppSpacing.sm),
        PageHeader(title: article.title, subtitle: article.summary),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.premiumLockedTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.premiumLockedBody,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({required this.article, required this.categoryTitle});

  final GuideArticle article;
  final String categoryTitle;

  Future<void> _open(BuildContext context, GuideSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.guideOpenFailed;
    var ok = false;
    try {
      ok = await launchUrl(source.url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return PageBody(
      topPadding: AppSpacing.xs,
      children: [
        Text(categoryTitle.toUpperCase(), style: muted),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(article.title, style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.guideUpdated(article.updated), style: muted),
        const SizedBox(height: AppSpacing.lg),
        for (final block in article.blocks) ...[
          switch (block) {
            GuideHeading(:final text) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Semantics(
                header: true,
                child: Text(text, style: theme.textTheme.titleLarge),
              ),
            ),
            GuideParagraph(:final text) => Text(
              text,
              style: theme.textTheme.bodyLarge,
            ),
            GuideBullets(:final items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text('•  ', style: theme.textTheme.bodyLarge),
                        ),
                        Expanded(
                          child: Text(item, style: theme.textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          },
          const SizedBox(height: AppSpacing.md),
        ],
        if (article.sources.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            header: true,
            child: Text(l10n.guideSources, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final source in article.sources)
            Semantics(
              link: true,
              label: l10n.guideOpenSource(source.label),
              excludeSemantics: true,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.open_in_new, color: scheme.primary),
                title: Text(
                  source.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary,
                  ),
                ),
                subtitle: Text(source.url.host, style: muted),
                onTap: () => _open(context, source),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.guideDisclaimer, style: muted),
      ],
    );
  }
}
