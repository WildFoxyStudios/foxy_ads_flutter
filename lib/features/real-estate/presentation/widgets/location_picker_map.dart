// Interactive "pick location on map" widget for the create/edit listing flow
// (P9 B2). Real-estate listings created via the app previously never wrote
// `latitude`/`longitude`, so they never appeared on the search-results map
// (`ReMapView`) or the detail mini-map (`ListingLocationMap`) — both of
// which only plot listings with coordinates. This widget lets the seller
// tap a spot on an OSM map to set them.
//
// Reuses the flutter_map + raw OSM raster tile setup from `re_map_view.dart`
// / `listing_location_map.dart` (see those files' header comments for why
// flutter_map was chosen over google_maps_flutter), adding a `MapOptions`
// `onTap` handler that reports the picked point back to the parent.
//
// The pick is ALWAYS OPTIONAL: the parent starts with no marker, and
// `onChanged` may never fire before submit — a listing must be publishable
// with null lat/lng.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Approximate country centroids for the app's supported countries (see
/// `Country.defaultCountries` in `core/models/country_model.dart`). Used to
/// center the map picker before the user has made a pick of their own, so
/// the initial view is roughly in the seller's country instead of the
/// middle of the ocean. Not surveyed/precise — just a sane starting zoom
/// center; the user pans/zooms/taps to the exact spot.
const Map<String, LatLng> countryCentroids = {
  'ES': LatLng(40.4168, -3.7038), // Madrid
  'MX': LatLng(19.4326, -99.1332), // Ciudad de México
  'AR': LatLng(-34.6037, -58.3816), // Buenos Aires
  'CO': LatLng(4.7110, -74.0721), // Bogotá
  'CL': LatLng(-33.4489, -70.6693), // Santiago
  'PE': LatLng(-12.0464, -77.0428), // Lima
  'VE': LatLng(10.4806, -66.9036), // Caracas
  'EC': LatLng(-0.1807, -78.4678), // Quito
  'GT': LatLng(14.6349, -90.5069), // Ciudad de Guatemala
  'CU': LatLng(23.1136, -82.3666), // La Habana
  'BO': LatLng(-16.5000, -68.1500), // La Paz
  'DO': LatLng(18.4861, -69.9312), // Santo Domingo
  'HN': LatLng(14.0723, -87.1921), // Tegucigalpa
  'PY': LatLng(-25.2637, -57.5759), // Asunción
  'SV': LatLng(13.6929, -89.2182), // San Salvador
  'NI': LatLng(12.1364, -86.2514), // Managua
  'CR': LatLng(9.9281, -84.0907), // San José
  'PA': LatLng(8.9824, -79.5199), // Ciudad de Panamá
  'UY': LatLng(-34.9011, -56.1645), // Montevideo
  'US': LatLng(39.8283, -98.5795), // Continental US center
};

/// Default map center (Madrid) used when no country code is recognized.
const LatLng defaultMapCenter = LatLng(40.4168, -3.7038);

/// Looks up the approximate centroid for [countryCode], falling back to
/// Madrid when the code is null/unrecognized.
LatLng centroidForCountry(String? countryCode) {
  if (countryCode == null) return defaultMapCenter;
  return countryCentroids[countryCode] ?? defaultMapCenter;
}

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    required this.onChanged,
    this.initialCenter,
    this.initialValue,
  });

  /// Center of the map before any pick is made — typically the seller's
  /// country centroid (see [centroidForCountry]). Defaults to Madrid when
  /// omitted.
  final LatLng? initialCenter;

  /// Pre-existing pick (edit mode). When set, a marker is shown at this
  /// point from the first frame and the map centers on it instead of
  /// [initialCenter].
  final LatLng? initialValue;

  /// Fired on every pick and on clear. `null` means the user cleared the
  /// pick — the parent should null out its stored lat/lng in that case.
  /// Never firing is a valid state: the pick is optional, and a listing
  /// must remain submittable without one.
  final ValueChanged<LatLng?> onChanged;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late LatLng? _picked = widget.initialValue;

  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    setState(() => _picked = latlng);
    widget.onChanged(latlng);
  }

  void _clear() {
    setState(() => _picked = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final center = _picked ?? widget.initialCenter ?? defaultMapCenter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.locationPickerHeading,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _picked == null
              ? l10n.locationPickerHint
              : l10n.locationPickerPicked,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 250,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                onTap: _handleTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wildfoxy.foxy_ads',
                ),
                if (_picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _picked!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                // OSM attribution is required by the tile usage policy.
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_picked != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.close, size: 16),
              label: Text(l10n.locationPickerClear),
            ),
          ),
      ],
    );
  }
}
