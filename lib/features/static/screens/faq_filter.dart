/// Pure helper for the `/ayuda` FAQ search + category filter. Extracted from
/// `help_screen.dart` so it can be unit-tested without pumping a widget
/// tree (see `test/help_search_test.dart`).
library;

/// A single FAQ entry, built from the flat `helpFaq{n}Category/Question/
/// Answer` ARB keys (ARB can't hold an array of objects cleanly).
class Faq {
  final String category;
  final String question;
  final String answer;

  const Faq(this.category, this.question, this.answer);
}

/// Returns the subset of [faqs] matching [category] (exact match; `null`
/// means "all categories") AND [query] (case-insensitive, accent-insensitive
/// substring match against question OR answer; empty query matches all).
List<Faq> filterFaqs(List<Faq> faqs, String query, String? category) {
  final q = normalizeForSearch(query);
  return faqs.where((f) {
    if (category != null && f.category != category) return false;
    if (q.isEmpty) return true;
    return normalizeForSearch(f.question).contains(q) ||
        normalizeForSearch(f.answer).contains(q);
  }).toList();
}

/// Lowercases and strips common Spanish/French/Italian accents so search is
/// forgiving of missing diacritics (e.g. "contrasena" matches "contraseña").
String normalizeForSearch(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');
}
