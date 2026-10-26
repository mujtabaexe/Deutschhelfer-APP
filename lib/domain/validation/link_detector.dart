/// Detects text that looks like a web link.
///
/// This MUST stay equivalent to `hasLink()` in `firebase/firestore.rules`.
/// The server rejects a group message whose status does not match its own
/// link check, so a mismatch makes sending fail. Detection is best effort:
/// "example dot com" style obfuscation is not caught, which is why reports
/// and moderators remain necessary.
///
/// Any dotted word with a two-letter-plus ending counts, including Unicode
/// look-alike dots, so "file.pdf" or "Mr.Khan" also go to moderation. That
/// trade-off is deliberate: a false positive costs a short delay, a missed
/// phishing link costs much more.
final RegExp linkPattern = RegExp(
  r'(https?://|www[.．。｡]|[a-z0-9-]+[.．。｡][a-z][a-z]+([^a-z0-9]|$))',
  caseSensitive: false,
);

bool containsLink(String text) => linkPattern.hasMatch(text);

/// Finds absolute http(s) links for display. Only used on content a
/// moderator has already approved.
final RegExp _absoluteLink = RegExp(
  r'https?://[^\s<>"]+',
  caseSensitive: false,
);

Iterable<Uri> extractHttpLinks(String text) sync* {
  for (final match in _absoluteLink.allMatches(text)) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      yield uri;
    }
  }
}
