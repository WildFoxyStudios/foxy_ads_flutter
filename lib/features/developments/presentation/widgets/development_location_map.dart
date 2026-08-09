// Static location mini-map for the promotion/development-detail screen
// (Plan 11, F4). Mirrors `ListingLocationMap`
// (`lib/features/listings/presentation/widgets/listing_location_map.dart`)
// and reuses the same `flutter_map` + raw OSM raster tile setup as
// `re_map_view.dart`, but is parameterized on raw `latitude`/`longitude`
// instead of a `Listing` model, since a `Development` isn't a `Listing`.
//
// Non-interactive (`InteractiveFlag.none`) so it doesn't fight the detail
// screen's outer scroll. Renders `SizedBox.shrink()` when coordinates are
// missing/invalid — safe to mount unconditionally.
//
// Unlike `ListingLocationMap`, this widget does NOT render its own
// "Ubicación" heading: `PromocionDetailScreen._buildLocation` already shows
// a heading + address line + coordinate text above the map.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';

class DevelopmentLocationMap extends StatelessWidget {
  const DevelopmentLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double? latitude;
  final double? longitude;

  bool get _hasValidCoords {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidCoords) {
      return const SizedBox.shrink();
    }

    final point = LatLng(latitude!, longitude!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 14,
            // Non-interactive: this is a static preview, not the full
            // search-results map (see `ReMapView`).
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wildfoxy.foxy_ads',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
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
    );
  }
}
