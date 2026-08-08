// Static location mini-map for the listing-detail screen (Task A4 of the
// P9 sprint). Reuses the `flutter_map` + raw OSM raster tile setup from
// `re_map_view.dart` (see that file's header comment for why flutter_map was
// chosen over google_maps_flutter), but as a single-marker, non-interactive
// preview rather than a full search-results map: `InteractiveFlag.none`
// disables pan/zoom/rotate so the map doesn't fight the detail screen's
// outer scroll (a `FlutterMap` inside a `CustomScrollView` would otherwise
// swallow vertical drag gestures meant to scroll the page).
//
// Renders `SizedBox.shrink()` when the listing has no coordinates (see
// `Listing.hasCoordinates`) — safe to mount unconditionally on every
// listing.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class ListingLocationMap extends StatelessWidget {
  const ListingLocationMap({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    if (!listing.hasCoordinates) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final point = LatLng(listing.latitude!, listing.longitude!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listingDetailLocationHeading,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14,
                // Non-interactive: this is a static preview, not the
                // full search-results map (see `ReMapView`).
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
        ),
      ],
    );
  }
}
