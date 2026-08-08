// Real-estate canonical attribute lists, mirrored from
// `foxy_ads_web/src/lib/real-estate/attributes.ts`.
//
// Keep these in lock-step with the web. The parity test
// `test/re_attributes_parity_test.dart` guards against drift.
//
// This file is PURE DATA: no service imports, no I/O, no Flutter
// framework imports beyond `dart:core`. It is imported by widgets,
// services, and tests.

const List<String> RE_OPERATIONS = [
  'venta',
  'alquiler',
  'alquiler_temporal',
];

const List<String> RE_PROPERTY_TYPES = [
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

const List<String> RE_CONDITIONS = [
  'obra_nueva',
  'buen_estado',
  'a_reformar',
];

const List<String> RE_ORIENTATIONS = [
  'norte',
  'sur',
  'este',
  'oeste',
];

const List<String> RE_ENERGY_CERTS = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
];

const List<String> RE_FEATURE_KEYS = [
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

const List<String> RE_SORTS = [
  'relevance',
  'recent',
  'price_asc',
  'price_desc',
  'size_desc',
  'price_m2',
];

const List<String> RE_FLOOR_BUCKETS = [
  'bajos',
  'intermedias',
  'ultima',
];

// --- Create-form RAW option lists (canonical `attributes` schema) ---------
//
// The lists above (`RE_FLOOR_BUCKETS`, `RE_ENERGY_CERTS`) double as SEARCH
// filter values — do not change them. `RE_FLOOR_RAW` is the separate list of
// raw per-listing floor values the create form writes to `attributes.floor`
// (a single string), mirrored from the web's floor `<select>` options. Not
// used by search (the search RPC buckets floors via `RE_FLOOR_BUCKETS`).
const List<String> RE_FLOOR_RAW = [
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
