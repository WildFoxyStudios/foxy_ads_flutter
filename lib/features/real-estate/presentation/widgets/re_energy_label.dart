// Localized label helper for the real-estate energy certificate dropdowns
// (Task 8 of the RE parity sprint). Maps a single UI-selected energy letter
// ('A'..'G') to the user-facing "{letter} ({band})" label rendered in the
// attribute form and the filter panel, where the band label is the existing
// `realEstateEnergyBand{High|Mid|Low}` ARB string (which already carries the
// letter range hint, e.g. "High (A-C)" / "Alta (A-C)"). Keeping the letter
// + band in a single user-visible string means the dropdown no longer shows
// raw `A`/`B`/`C` labels that look like UI affordances rather than copy.

import '../../../../l10n/app_localizations.dart';
import '../../data/re_pricing.dart' show energyBandForLetter;

/// User-facing label for an energy certificate letter option in a dropdown.
/// Returns `null` for letters outside A..G so callers can fall back to the
/// raw letter (e.g. for safety / future expansion) without emitting a label
/// that references an unknown band.
String? reEnergyLabel(String? letter, AppLocalizations l10n) {
  if (letter == null) return null;
  final band = energyBandForLetter(letter);
  if (band == null) return null;
  final bandLabel = switch (band) {
    'alta' => l10n.realEstateEnergyBandHigh,
    'media' => l10n.realEstateEnergyBandMid,
    'baja' => l10n.realEstateEnergyBandLow,
    _ => band,
  };
  return l10n.realEstateEnergyLetterOption(letter, bandLabel);
}
