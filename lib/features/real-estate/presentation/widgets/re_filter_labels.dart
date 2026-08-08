// Localized label lookups for the RE search filter wire values (Task 9 of
// the RE parity sprint). Extracted from `inmuebles_en_screen.dart` so the
// active-filter chip strip (`re_active_filters.dart`) can resolve the same
// human-readable copy the filter panel uses instead of duplicating (and
// risking drift on) five separate maps. Built per-call (cheap: small map
// literals) so a locale switch re-renders correctly.

import '../../../../l10n/app_localizations.dart';

Map<String, String> propertyTypeLabels(AppLocalizations l10n) => {
      'piso': l10n.realEstatePropertyTypeFlat,
      'casa': l10n.realEstatePropertyTypeHouse,
      'atico': l10n.realEstatePropertyTypePenthouse,
      'estudio': l10n.realEstatePropertyTypeStudio,
      'duplex': l10n.realEstatePropertyTypeDuplex,
      'chalet': l10n.realEstatePropertyTypeChalet,
      'loft': l10n.realEstatePropertyTypeLoft,
      'local': l10n.realEstatePropertyTypeCommercial,
      'oficina': l10n.realEstatePropertyTypeOffice,
      'terreno': l10n.realEstatePropertyTypeLand,
      'garaje': l10n.realEstatePropertyTypeGarage,
    };

Map<String, String> conditionLabels(AppLocalizations l10n) => {
      'obra_nueva': l10n.realEstateConditionNew,
      'buen_estado': l10n.realEstateConditionGood,
      'a_reformar': l10n.realEstateConditionToRenovate,
    };

Map<String, String> orientationLabels(AppLocalizations l10n) => {
      'norte': l10n.realEstateOrientationNorth,
      'sur': l10n.realEstateOrientationSouth,
      'este': l10n.realEstateOrientationEast,
      'oeste': l10n.realEstateOrientationWest,
    };

Map<String, String> floorBucketLabels(AppLocalizations l10n) => {
      'bajos': l10n.realEstateFloorBucketLow,
      'intermedias': l10n.realEstateFloorBucketMid,
      'ultima': l10n.realEstateFloorBucketTop,
    };

Map<String, String> featureLabels(AppLocalizations l10n) => {
      'elevator': l10n.realEstateFeatureElevator,
      'parking': l10n.realEstateFeatureParking,
      'terrace': l10n.realEstateFeatureTerrace,
      'balcony': l10n.realEstateFeatureBalcony,
      'garden': l10n.realEstateFeatureGarden,
      'pool': l10n.realEstateFeaturePool,
      'storage_room': l10n.realEstateFeatureStorageRoom,
      'air_conditioning': l10n.realEstateFeatureAirConditioning,
      'heating': l10n.realEstateFeatureHeating,
      'built_in_wardrobes': l10n.realEstateFeatureBuiltInWardrobes,
      'furnished': l10n.realEstateFeatureFurnished,
      'exterior': l10n.realEstateFeatureExterior,
      'accessible': l10n.realEstateFeatureAccessible,
      'luxury': l10n.realEstateFeatureLuxury,
    };

/// Energy band labels ('alta'/'media'/'baja'), used both by the filter
/// panel's energy-band chip row and the active-filter chip strip.
Map<String, String> energyBandLabels(AppLocalizations l10n) => {
      'alta': l10n.realEstateEnergyBandHigh,
      'media': l10n.realEstateEnergyBandMid,
      'baja': l10n.realEstateEnergyBandLow,
    };

/// User-facing label for an RE search operation wire value ('venta',
/// 'alquiler', 'alquiler_temporal'). Returns `null` for unknown values so
/// callers can fall back to the raw string.
String? operationLabel(String value, AppLocalizations l10n) {
  switch (value) {
    case 'venta':
      return l10n.realEstateOperationSale;
    case 'alquiler':
      return l10n.realEstateOperationRent;
    case 'alquiler_temporal':
      return l10n.realEstateOperationTemp;
    default:
      return null;
  }
}
