import 'package:deutschhelfer/domain/validation/link_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // These cases mirror firebase/test/rules.test.mjs. If the server's hasLink()
  // and this detector disagree, sending fails, so keep both lists in sync.
  const links = [
    'https://evil.example',
    'see www.daad.de',
    'go to WWW.EVIL.COM now',
    'cheap-visas.pk/offer',
    'line1\nhttp://x.y',
    'visit uni-assist.de.',
    'apply at portal.site',
    'join discord.gg/abc',
    'visit evil.ru today',
    'shorturl.at/xyz',
    'example\uFF0Ecom',
  ];
  const plain = [
    'Hello all',
    'Dr. Ali',
    'The deadline is 15.07.2026',
    'Meet at 3.30pm',
    'e.g. the APS',
    'version 2.0 of the form',
  ];

  test('detects links the server treats as links', () {
    for (final text in links) {
      expect(containsLink(text), isTrue, reason: text);
    }
  });

  test('leaves ordinary text alone', () {
    for (final text in plain) {
      expect(containsLink(text), isFalse, reason: text);
    }
  });

  test('extracts only absolute http(s) links for opening', () {
    final found = extractHttpLinks(
      'a https://www.daad.de/en/ b javascript:alert(1) c http://x.org d www.y.com',
    ).map((u) => u.toString());
    expect(found, ['https://www.daad.de/en/', 'http://x.org']);
  });
}
