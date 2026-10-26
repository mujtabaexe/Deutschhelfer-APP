import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../domain/models/guide.dart';

/// Free guidance ships inside the app, so reading it costs no database reads
/// and works offline. Premium article bodies live only on the server, behind
/// a Firestore rule that checks the premium claim.
abstract interface class GuideRepository {
  Future<GuideLibrary> loadLibrary();

  /// Loads the body of a premium article. Throws [PremiumContentException].
  Future<GuideArticle> loadPremiumBody(GuideArticle teaser);
}

enum PremiumContentFailure { notEntitled, notFound, unavailable }

class PremiumContentException implements Exception {
  const PremiumContentException(this.failure);
  final PremiumContentFailure failure;

  @override
  String toString() => 'PremiumContentException(${failure.name})';
}

class BundledGuideRepository implements GuideRepository {
  BundledGuideRepository({
    AssetBundle? bundle,
    FirebaseFirestore? firestore,
    this.assetPath = 'assets/content/guide.json',
  }) : _bundle = bundle ?? rootBundle,
       _db = firestore;

  final AssetBundle _bundle;
  final FirebaseFirestore? _db;
  final String assetPath;
  GuideLibrary? _cache;

  @override
  Future<GuideLibrary> loadLibrary() async {
    return _cache ??= parseGuideLibrary(await _bundle.loadString(assetPath));
  }

  @override
  Future<GuideArticle> loadPremiumBody(GuideArticle teaser) async {
    final db = _db;
    if (db == null) {
      throw const PremiumContentException(PremiumContentFailure.unavailable);
    }
    try {
      final snap = await db.collection('premiumContent').doc(teaser.id).get();
      final data = snap.data();
      if (data == null) {
        throw const PremiumContentException(PremiumContentFailure.notFound);
      }
      return teaser.withBody(
        blocks: parseBlocks(data['blocks']),
        sources: parseSources(data['sources']),
      );
    } on FirebaseException catch (error) {
      throw PremiumContentException(
        error.code == 'permission-denied'
            ? PremiumContentFailure.notEntitled
            : PremiumContentFailure.unavailable,
      );
    }
  }
}

GuideLibrary parseGuideLibrary(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  final categories = [
    for (final raw in root['categories'] as List<dynamic>)
      if (raw case {'id': final String id, 'title': final String title})
        GuideCategory(id: id, title: title),
  ];
  final articles = [
    for (final raw in root['articles'] as List<dynamic>)
      if (raw case {
        'id': final String id,
        'categoryId': final String categoryId,
        'title': final String title,
        'summary': final String summary,
        'updated': final String updated,
      })
        GuideArticle(
          id: id,
          categoryId: categoryId,
          title: title,
          summary: summary,
          updated: DateTime.parse(updated),
          isPremium: (raw as Map<String, dynamic>)['premium'] == true,
          blocks: parseBlocks(raw['blocks']),
          sources: parseSources(raw['sources']),
        ),
  ];
  return GuideLibrary(categories: categories, articles: articles);
}

List<GuideBlock> parseBlocks(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final block in raw)
      if (block case {'type': 'heading', 'text': final String text})
        GuideHeading(text)
      else if (block case {'type': 'paragraph', 'text': final String text})
        GuideParagraph(text)
      else if (block case {
        'type': 'bullets',
        'items': final List<dynamic> items,
      })
        GuideBullets([...items.whereType<String>()]),
  ];
}

/// Keeps only absolute https links. Content is curated, but a bad entry must
/// never produce an `intent:` or `javascript:` link.
List<GuideSource> parseSources(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final source in raw)
      if (source case {'label': final String label, 'url': final String url})
        if (Uri.tryParse(url) case final uri?
            when uri.scheme == 'https' && uri.host.isNotEmpty)
          GuideSource(label: label, url: uri),
  ];
}
