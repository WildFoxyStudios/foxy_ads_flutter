// Pure-Dart helpers for the real-estate vertical's pricing UI:
//
//   * `pricePerM2` — €/m² (or local-currency equivalent) from a listing's
//     raw price + surface. Returns null on degenerate inputs (zero / null
//     surface, non-finite price) so the UI can decide to hide the badge.
//   * `energyBandForLetter` — maps a single UI-selected energy certificate
//     letter (A..G) to the band bucket used by the search RPC's
//     `p_energy_bands` filter (`alta`/`media`/`baja`). Returns null for
//     unknown / missing letters so callers can pass-through `null` instead
//     of emitting an invalid bucket.
//   * `estimateFromComparables` — given a list of per-m² prices (typically
//     3-30 area listings), compute the avg estimate and a ±12% range that
//     the listing-detail "zone price" widget renders. Returns null on empty
//     input; the sample size is exposed so the caller can decide if it's
//     big enough to be meaningful (the ListingService wraps this with a
//     caller-supplied minSample guard).
//
// All helpers are pure — no I/O, no Flutter, no Supabase — so they're
// trivially unit-testable and shareable between widgets / providers.

/// Spanish-language band bucket names that match the `p_energy_bands` RPC
/// argument's `text[]` values exactly (see `real_estate_search.sql` and the
/// web's `RE_ENERGY_BANDS` constant).
typedef EnergyBand = String;

/// Maps a single UI-selected energy certificate letter (A..G) to the band
/// bucket used by the search RPC. A/B/C → alta (efficient), D/E → media,
/// F/G → baja. Returns null for any other input (including null) so the
/// caller can pass-through a missing selection instead of emitting an
/// invalid bucket the RPC would silently ignore.
String? energyBandForLetter(String? letter) {
  switch (letter) {
    case 'A':
    case 'B':
    case 'C':
      return 'alta';
    case 'D':
    case 'E':
      return 'media';
    case 'F':
    case 'G':
      return 'baja';
    default:
      return null;
  }
}

/// €/m² (or local-currency equivalent) from a listing's raw price + surface.
/// Mirrors the web's `pricePerM2(price, m2)` (`Math.round(price / m2)`):
/// returns null on missing/zero/negative m² or non-finite price so the UI
/// can hide the badge instead of showing `Infinity` or `0`.
int? pricePerM2(num price, num? m2) {
  if (m2 == null || m2 <= 0) return null;
  if (price is double && !price.isFinite) return null;
  return (price / m2).round();
}

/// Estimate the per-m² price + ±12% range for a single listing, given an
/// iterable of per-m² prices from comparable listings in the same area /
/// operation. Mirrors the web's `estimateFromComparables` (`avg` →
/// `estimate`, `low = round(0.88 * estimate)`, `high = round(1.12 *
/// estimate)`). Returns null on empty input — callers that want a stricter
/// "is this many samples enough to be meaningful?" gate should wrap this
/// in a `minSample` check (see `ListingService.estimateFromCityStats`).
({int estimate, int low, int high, int sampleSize})? estimateFromComparables(
  Iterable<num> pricePerM2Values,
) {
  final samples = pricePerM2Values.toList(growable: false);
  if (samples.isEmpty) return null;
  final sum = samples.fold<num>(0, (s, v) => s + v);
  final estimate = (sum / samples.length).round();
  final low = (estimate * 0.88).round();
  final high = (estimate * 1.12).round();
  return (
    estimate: estimate,
    low: low,
    high: high,
    sampleSize: samples.length,
  );
}
