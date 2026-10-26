/// Guidance content models.
library;

class GuideCategory {
  const GuideCategory({required this.id, required this.title});

  final String id;
  final String title;
}

sealed class GuideBlock {
  const GuideBlock();
}

class GuideHeading extends GuideBlock {
  const GuideHeading(this.text);
  final String text;
}

class GuideParagraph extends GuideBlock {
  const GuideParagraph(this.text);
  final String text;
}

class GuideBullets extends GuideBlock {
  const GuideBullets(this.items);
  final List<String> items;
}

class GuideSource {
  const GuideSource({required this.label, required this.url});

  final String label;
  final Uri url;
}

class GuideArticle {
  const GuideArticle({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.updated,
    this.isPremium = false,
    this.blocks = const [],
    this.sources = const [],
  });

  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final DateTime updated;
  final bool isPremium;

  /// Empty for premium articles until loaded from the server.
  final List<GuideBlock> blocks;
  final List<GuideSource> sources;

  GuideArticle withBody({
    required List<GuideBlock> blocks,
    required List<GuideSource> sources,
  }) => GuideArticle(
    id: id,
    categoryId: categoryId,
    title: title,
    summary: summary,
    updated: updated,
    isPremium: isPremium,
    blocks: blocks,
    sources: sources,
  );

  /// Lower-case text used for search.
  String get searchText => [
    title,
    summary,
    for (final block in blocks)
      switch (block) {
        GuideHeading(:final text) || GuideParagraph(:final text) => text,
        GuideBullets(:final items) => items.join(' '),
      },
  ].join(' ').toLowerCase();
}

class GuideLibrary {
  const GuideLibrary({required this.categories, required this.articles});

  final List<GuideCategory> categories;
  final List<GuideArticle> articles;

  GuideArticle? article(String id) {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  String categoryTitle(String id) {
    for (final category in categories) {
      if (category.id == id) return category.title;
    }
    return '';
  }

  /// Every whitespace-separated term must appear somewhere in the article.
  List<GuideArticle> search({String query = '', String? categoryId}) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    return [
      for (final article in articles)
        if ((categoryId == null || article.categoryId == categoryId) &&
            terms.every(article.searchText.contains))
          article,
    ];
  }
}
