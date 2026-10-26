import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../data/repositories/guide_repository.dart';
import '../../../../domain/models/guide.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/guide_view_models.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.repository});

  final GuideRepository repository;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  late final GuideViewModel _viewModel = GuideViewModel(
    repository: widget.repository,
  );
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.guideTitle)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final library = _viewModel.library;
          if (library == null) {
            if (_viewModel.failed) {
              return ErrorView(
                message: l10n.guideLoadFailed,
                onRetry: _viewModel.load,
              );
            }
            return const LoadingView();
          }
          final results = _viewModel.results;
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _searchField(context)),
              SliverToBoxAdapter(child: _categoryChips(context, library)),
              if (results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.search_off_outlined,
                    title: l10n.guideNoResultsTitle,
                    message: l10n.guideNoResultsBody,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => ArticleCard(
                      article: results[index],
                      categoryTitle: library.categoryTitle(
                        results[index].categoryId,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _search,
        onChanged: _viewModel.setQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: l10n.guideSearchLabel,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _viewModel.query.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.guideSearchClear,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    _viewModel.setQuery('');
                  },
                ),
        ),
      ),
    );
  }

  Widget _categoryChips(BuildContext context, GuideLibrary library) {
    final l10n = context.l10n;
    final selected = _viewModel.categoryId;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final (id, label) in [
            (null, l10n.guideAllCategories),
            for (final c in library.categories) (c.id, c.title),
          ])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == id,
                onSelected: (_) => _viewModel.setCategory(id),
              ),
            ),
        ],
      ),
    );
  }
}

class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    required this.categoryTitle,
  });

  final GuideArticle article;
  final String categoryTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('${AppRoutes.guide}/${article.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    categoryTitle.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (article.isPremium) const PremiumBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(article.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                article.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lock icon plus text, so premium status never relies on colour alone.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              context.l10n.guidePremiumBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
