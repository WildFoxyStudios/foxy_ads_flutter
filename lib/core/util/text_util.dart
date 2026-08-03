/// Small text helpers shared across screens. Pure Dart — no Flutter imports.
library;

/// Returns the upper-cased first character of [source] (trimmed), or
/// [fallback] when [source] is null or empty/whitespace-only.
///
/// Guards the common "avatar initial" pattern `(name ?? 'U')[0]`, which
/// crashes with a RangeError when `name` is a non-null empty string — the
/// `??` operator only catches `null`, not `''`.
String initialLetter(String? source, {String fallback = '?'}) {
  final trimmed = source?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed[0].toUpperCase();
}
