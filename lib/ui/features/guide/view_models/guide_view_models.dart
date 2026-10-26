import 'package:flutter/foundation.dart';

import '../../../../data/repositories/guide_repository.dart';
import '../../../../domain/models/guide.dart';

/// Library list state: loading, search query and category filter.
class GuideViewModel extends ChangeNotifier {
  GuideViewModel({required this._repository});

  final GuideRepository _repository;

  GuideLibrary? _library;
  bool _isLoading = false;
  bool _failed = false;
  String _query = '';
  String? _categoryId;

  GuideLibrary? get library => _library;
  bool get isLoading => _isLoading;
  bool get failed => _failed;
  String get query => _query;
  String? get categoryId => _categoryId;

  List<GuideArticle> get results =>
      _library?.search(query: _query, categoryId: _categoryId) ?? const [];

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _failed = false;
    notifyListeners();
    try {
      _library = await _repository.loadLibrary();
    } catch (_) {
      _failed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setCategory(String? id) {
    if (id == _categoryId) return;
    _categoryId = id;
    notifyListeners();
  }
}

enum ArticleState { loading, ready, locked, missing, failed }

/// Single article. Premium bodies load from the server only when the
/// session says the user is premium; the server re-checks the claim.
class ArticleViewModel extends ChangeNotifier {
  ArticleViewModel({
    required this._repository,
    required this.articleId,
    required this.isPremiumUser,
  });

  final GuideRepository _repository;
  final String articleId;
  final bool isPremiumUser;

  ArticleState _state = ArticleState.loading;
  GuideArticle? _article;
  String _categoryTitle = '';
  PremiumContentFailure? _premiumFailure;
  bool _disposed = false;

  ArticleState get state => _state;
  GuideArticle? get article => _article;
  String get categoryTitle => _categoryTitle;
  PremiumContentFailure? get premiumFailure => _premiumFailure;

  Future<void> load() async {
    _set(ArticleState.loading);
    try {
      final library = await _repository.loadLibrary();
      final article = library.article(articleId);
      if (article == null) return _set(ArticleState.missing);
      _article = article;
      _categoryTitle = library.categoryTitle(article.categoryId);
      if (!article.isPremium) return _set(ArticleState.ready);
      if (!isPremiumUser) return _set(ArticleState.locked);
      _article = await _repository.loadPremiumBody(article);
      _set(ArticleState.ready);
    } on PremiumContentException catch (error) {
      _premiumFailure = error.failure;
      _set(
        error.failure == PremiumContentFailure.notEntitled
            ? ArticleState.locked
            : ArticleState.failed,
      );
    } catch (_) {
      _set(ArticleState.failed);
    }
  }

  void _set(ArticleState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
