import 'dart:convert';

import 'package:deutschhelfer/data/repositories/guide_repository.dart';
import 'package:deutschhelfer/domain/models/guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled guide parses and every article is well formed', () async {
    final library = await BundledGuideRepository().loadLibrary();
    expect(library.articles, isNotEmpty);
    final categoryIds = {for (final c in library.categories) c.id};
    final ids = <String>{};
    for (final article in library.articles) {
      expect(ids.add(article.id), isTrue, reason: 'duplicate ${article.id}');
      expect(categoryIds, contains(article.categoryId));
      if (article.isPremium) {
        // Premium bodies must never ship inside the app.
        expect(article.blocks, isEmpty, reason: article.id);
      } else {
        expect(article.blocks, isNotEmpty, reason: article.id);
      }
      for (final source in article.sources) {
        expect(source.url.scheme, 'https');
      }
    }
  });

  test('only https sources survive parsing', () {
    final sources = parseSources([
      {'label': 'ok', 'url': 'https://www.daad.de/en/'},
      {'label': 'http', 'url': 'http://example.com'},
      {'label': 'js', 'url': 'javascript:alert(1)'},
      {'label': 'intent', 'url': 'intent://scan/#Intent;end'},
      {'label': 'relative', 'url': '/path'},
      {'label': 'missing'},
    ]);
    expect(sources.map((s) => s.label), ['ok']);
  });

  test('unknown block types are ignored', () {
    final blocks = parseBlocks([
      {'type': 'paragraph', 'text': 'a'},
      {'type': 'html', 'text': '<b>no</b>'},
      {
        'type': 'bullets',
        'items': ['x', 3, 'y'],
      },
    ]);
    expect(blocks, hasLength(2));
    expect((blocks[1] as GuideBullets).items, ['x', 'y']);
  });

  test('search needs every term and respects the category', () {
    final library = parseGuideLibrary(
      jsonEncode({
        'categories': [
          {'id': 'a', 'title': 'A'},
          {'id': 'b', 'title': 'B'},
        ],
        'articles': [
          {
            'id': '1',
            'categoryId': 'a',
            'title': 'Visa basics',
            'summary': 'Embassy appointment',
            'updated': '2026-01-01',
          },
          {
            'id': '2',
            'categoryId': 'b',
            'title': 'Visa costs',
            'summary': 'Blocked account',
            'updated': '2026-01-01',
          },
        ],
      }),
    );
    expect(library.search(query: 'visa').map((a) => a.id), ['1', '2']);
    expect(library.search(query: 'VISA blocked').map((a) => a.id), ['2']);
    expect(library.search(query: 'visa', categoryId: 'a').map((a) => a.id), [
      '1',
    ]);
    expect(library.search(query: '   ').length, 2);
  });
}
