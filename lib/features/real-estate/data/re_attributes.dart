// Real-estate canonical attribute lists, mirrored from
// `foxy_ads_web/src/lib/real-estate/attributes.ts`.
//
// Keep these in lock-step with the web. The parity test
// `test/re_attributes_parity_test.dart` guards against drift.
//
// This file is PURE DATA: no service imports, no I/O, no Flutter
// framework imports beyond `dart:core`. It is imported by widgets,
// services, and tests.

const List<String> reOperations = [
  'venta',
  'alquiler',
  'alquiler_temporal',
];

const List<String> rePropertyTypes = [
  'piso',
  'casa',
  'atico',
  'estudio',
  'duplex',
  'chalet',
  'loft',
  'local',
  'oficina',
  'terreno',
  'garaje',
];

const List<String> reConditions = [
  'obra_nueva',
  'buen_estado',
  'a_reformar',
];

const List<String> reOrientations = [
  'norte',
  'sur',
  'este',
  'oeste',
];

const List<String> reEnergyCerts = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
];

const List<String> reFeatureKeys = [
  'elevator',
  'parking',
  'terrace',
  'balcony',
  'garden',
  'pool',
  'storage_room',
  'air_conditioning',
  'heating',
  'built_in_wardrobes',
  'furnished',
  'exterior',
  'accessible',
  'luxury',
];

const List<String> reSorts = [
  'relevance',
  'recent',
  'price_asc',
  'price_desc',
  'size_desc',
  'price_m2',
];

const List<String> reFloorBuckets = [
  'bajos',
  'intermedias',
  'ultima',
];

// --- Create-form RAW option lists (canonical `attributes` schema) ---------
//
// The lists above (`reFloorBuckets`, `reEnergyCerts`) double as SEARCH
// filter values — do not change them. `reFloorRaw` is the separate list of
// raw per-listing floor values the create form writes to `attributes.floor`
// (a single string), mirrored from the web's floor `<select>` options. Not
// used by search (the search RPC buckets floors via `reFloorBuckets`).
const List<String> reFloorRaw = [
  'bajo',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  'atico',
];
