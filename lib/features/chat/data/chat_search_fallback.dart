// Client-side search-resolution fallback for the Foxy chat (parity port of
// the logic in the web's `src/components/chat/AIChatBubble.tsx`
// `handleSend`/`searchListings`, ~lines 148-307).
//
// On web, every send goes through client-side logic that decides what to
// search for even when the LLM's reply doesn't carry a clean
// `[BUSCAR: term | category]` tag — most commonly when the model *refuses*
// a borderline (age-gated "contacts") query, or simply omits the tag. Before
// this file, Flutter only acted on an explicit tag: a refusal or a missing
// tag left the user with nothing. This module ports the web's three pieces
// needed to close that gap:
//
//   * `kSearchSynonyms`   — web's `SEARCH_SYNONYMS` typo/synonym map.
//   * `isRefusal`         — web's inline refusal regex from `handleSend`.
//   * `resolveSearchIntent` — decides what to search for from either the
//     assistant's tag or (when there isn't one) the user's own message,
//     mirroring web's `SEARCH_INTENT_RE` + contacts-topic detection.
//
// `chat_sheet.dart` calls `resolveSearchIntent` instead of `parseSearchTag`
// directly so a refusal/no-tag reply still surfaces listings.

import 'chat_models.dart';

/// Synonym / typo expansion map, ported verbatim from the web's
/// `SEARCH_SYNONYMS` (`AIChatBubble.tsx`, ~lines 148-162). Keys are the
/// words a user might type; values are the extra tokens folded into the
/// search so a typo ("scort") or a euphemism ("erotico") still surfaces the
/// listings the canonical term would.
const Map<String, List<String>> kSearchSynonyms = {
  'scort': ['escort', 'escorts', 'contactos', 'citas'],
  'escort': ['escort', 'escorts', 'contactos', 'citas'],
  'escorts': ['escort', 'escorts', 'contactos', 'citas'],
  'sexo': [
    'contactos',
    'citas',
    'relaciones',
    'encuentros',
    'erotico',
    'escort',
    'chico',
    'chica',
  ],
  'erotico': ['erotico', 'erotica', 'contactos', 'relax', 'masajes'],
  'erotica': ['erotico', 'erotica', 'contactos', 'relax', 'masajes'],
  'masaje': ['masaje', 'masajes', 'relax', 'erotico'],
  'masajes': ['masaje', 'masajes', 'relax', 'erotico'],
  'citas': ['citas', 'contactos', 'relaciones', 'encuentros'],
  'pareja': ['pareja', 'parejas', 'relaciones', 'citas'],
  'parejas': ['pareja', 'parejas', 'relaciones', 'citas'],
  'perro': ['perro', 'perros', 'mascotas', 'cadena', 'correa', 'paseo'],
  'pasear': ['paseo', 'paseador', 'correa', 'cadena', 'perro'],
};

/// Detects an LLM refusal, ported verbatim from web's inline `isRefusal`
/// check in `handleSend` (`AIChatBubble.tsx` ~line 277) — the Groq safety
/// guardrail occasionally refuses a plain retrieval request for the
/// platform's own age-gated "contacts" category.
final RegExp _refusalPattern = RegExp(
  r'lo siento|no puedo cumplir|politicas|seguridad|cumplir con esta solicitud',
  caseSensitive: false,
);

/// True when [reply] reads like the model declined to help, per the web's
/// refusal heuristic.
bool isRefusal(String reply) => _refusalPattern.hasMatch(reply);

/// Contacts-topic detection, ported verbatim from web's inline
/// `isContactsTopic` check in `handleSend` (`AIChatBubble.tsx` ~line 289).
/// Used to attach the `contacts` category hint when neither the model's
/// tag nor an explicit category was given.
final RegExp _contactsTopicPattern = RegExp(
  r'contactos|sexo|erotic|pareja|citas|masaje|escort|scort|chico|chica|amor|masculino|femenino|trans',
  caseSensitive: false,
);

/// True when [text] plainly reads as a "contacts" (adult/personals) query.
bool isContactsTopic(String text) => _contactsTopicPattern.hasMatch(text);

/// User-intent verb prefix, ported verbatim from web's `SEARCH_INTENT_RE`
/// (`AIChatBubble.tsx` ~line 256) — used to pull a search term straight out
/// of the user's own message when the assistant's reply doesn't carry one.
final RegExp _searchIntentPattern = RegExp(
  r'^(?:busco|busca|buscar|necesito|quiero|encuentra|encontrar|mu[eé]strame|hay)\s+(.+)',
  caseSensitive: false,
);

/// Expands [term]'s words via [kSearchSynonyms], mirroring the token
/// expansion web performs inside `searchListings` (`AIChatBubble.tsx`
/// ~lines 176-185) before querying. Words with no synonym entry pass
/// through unchanged; words with an entry contribute their synonyms too.
/// Returns a space-joined string (order-preserving, de-duplicated) — the
/// single free-text query Flutter's `search_listings` RPC expects.
String expandSearchTerm(String term) {
  final words = term
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1);

  final expanded = <String>{};
  for (final w in words) {
    expanded.add(w);
    final synonyms = kSearchSynonyms[w];
    if (synonyms != null) expanded.addAll(synonyms);
  }
  return expanded.join(' ');
}

/// Resolves what Foxy should search for, given the user's message and the
/// assistant's reply. Mirrors web's `handleSend` decision chain
/// (`AIChatBubble.tsx` ~lines 279-307):
///
///  1. A clean `[BUSCAR: term]` / `[BUSCAR: term | category]` tag in
///     [assistantReply] wins outright — used verbatim, no synonym
///     expansion (existing `chat_sheet.dart` behavior).
///  2. Otherwise (no tag — including when the model refused, per
///     [isRefusal]) a search is derived from [userMessage] itself: the
///     `busco/necesito/...` intent-verb prefix is stripped, or, failing
///     that, the whole message is used if it plainly reads as a
///     "contacts" query. The derived term is run through
///     [expandSearchTerm] so typos/synonyms still surface listings.
///  3. Returns `null` when nothing searchable can be derived (e.g. plain
///     small talk with no intent verb and no contacts topic).
({String term, String? category})? resolveSearchIntent(
  String userMessage,
  String assistantReply,
) {
  final tag = parseSearchTag(assistantReply);
  if (tag != null && tag.term != null && tag.term!.trim().isNotEmpty) {
    return (term: tag.term!.trim(), category: tag.categoryId);
  }

  // No clean tag — including the refusal case, since a refusal never
  // carries a [BUSCAR:] tag. Derive a search from what the user actually
  // asked for so they aren't left empty-handed.
  final trimmedUser = userMessage.trim();
  if (trimmedUser.isEmpty) return null;

  final intentMatch = _searchIntentPattern.firstMatch(trimmedUser);
  final rawTerm = intentMatch != null
      ? intentMatch.group(1)!.trim()
      : (isContactsTopic(trimmedUser) ? trimmedUser : null);

  if (rawTerm == null || rawTerm.isEmpty) return null;

  final category = isContactsTopic(rawTerm) ? 'contacts' : null;
  final expanded = expandSearchTerm(rawTerm);
  return (term: expanded.isEmpty ? rawTerm : expanded, category: category);
}
